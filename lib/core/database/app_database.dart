import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this.database, this.databasePath);

  static const version = 2;
  final Database database;
  final String databasePath;

  static Future<AppDatabase> open({bool inMemory = false}) async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final supportDirectory = inMemory
        ? null
        : await getApplicationSupportDirectory();
    final legacySupportPath = supportDirectory == null
        ? null
        : await _legacyMacOSSupportPath(supportDirectory);
    final dbPath = inMemory
        ? inMemoryDatabasePath
        : p.join(supportDirectory!.path, 'clipflow.sqlite');
    final db = await openDatabase(
      dbPath,
      version: version,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createV1,
      onUpgrade: _migrate,
    );
    if (legacySupportPath != null) {
      await _mergeLegacyMacOSData(
        db,
        legacySupportPath: legacySupportPath,
        supportDirectory: supportDirectory!,
      );
    }
    return AppDatabase._(db, dbPath);
  }

  static Future<String?> _legacyMacOSSupportPath(
    Directory supportDirectory,
  ) async {
    if (!Platform.isMacOS) return null;
    final marker = File(p.join(supportDirectory.path, '.sandbox_migration_v1'));
    if (await marker.exists()) return null;
    final userHome = Platform.environment['HOME'];
    if (userHome == null || userHome.isEmpty) return null;

    final legacySupport = Directory(
      p.join(
        userHome,
        'Library',
        'Containers',
        'com.clipflow.clipflow',
        'Data',
        'Library',
        'Application Support',
        'com.clipflow.clipflow',
      ),
    );
    final legacyDatabase = File(p.join(legacySupport.path, 'clipflow.sqlite'));
    if (!await legacyDatabase.exists()) return null;
    return legacySupport.path;
  }

  static Future<void> _mergeLegacyMacOSData(
    Database db, {
    required String legacySupportPath,
    required Directory supportDirectory,
  }) async {
    await supportDirectory.create(recursive: true);
    final legacyDatabasePath = p.join(legacySupportPath, 'clipflow.sqlite');
    var attached = false;
    try {
      await db.execute('ATTACH DATABASE ? AS legacy_clipflow', [
        legacyDatabasePath,
      ]);
      attached = true;
      await db.transaction((transaction) async {
        await transaction.execute(
          'INSERT OR IGNORE INTO collections SELECT * FROM legacy_clipflow.collections',
        );
        await transaction.execute(
          'INSERT OR IGNORE INTO clipboard_items SELECT * FROM legacy_clipflow.clipboard_items',
        );
        await transaction.execute('''
          INSERT OR IGNORE INTO clipboard_item_collections
          SELECT * FROM legacy_clipflow.clipboard_item_collections
          ''');
      });

      final legacyImages = Directory(
        p.join(legacySupportPath, 'clipboard_images'),
      );
      if (await legacyImages.exists()) {
        final currentImages = Directory(
          p.join(supportDirectory.path, 'clipboard_images'),
        );
        await currentImages.create(recursive: true);
        await for (final entry in legacyImages.list()) {
          if (entry is File) {
            final destination = File(
              p.join(currentImages.path, p.basename(entry.path)),
            );
            if (!await destination.exists()) {
              await entry.copy(destination.path);
            }
          }
        }
      }

      await db.rawUpdate(
        '''
        UPDATE clipboard_items
        SET image_path = REPLACE(image_path, ?, ?)
        WHERE image_path LIKE ?
        ''',
        [legacySupportPath, supportDirectory.path, '$legacySupportPath%'],
      );
      await File(
        p.join(supportDirectory.path, '.sandbox_migration_v1'),
      ).writeAsString('complete', flush: true);
    } on Object {
      // Keep the current database usable and retry on the next launch.
    } finally {
      if (attached) {
        await db.execute('DETACH DATABASE legacy_clipflow');
      }
    }
  }

  static Future<void> _createV1(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clipboard_items (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        normalized_content TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        content_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_copied_at INTEGER NOT NULL,
        source_app_name TEXT,
        source_app_identifier TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_sensitive INTEGER NOT NULL DEFAULT 0,
        image_path TEXT,
        metadata_json TEXT,
        copy_count INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE clipboard_item_collections (
        clipboard_item_id TEXT NOT NULL,
        collection_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (clipboard_item_id, collection_id),
        FOREIGN KEY (clipboard_item_id) REFERENCES clipboard_items(id)
          ON DELETE CASCADE,
        FOREIGN KEY (collection_id) REFERENCES collections(id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_clipboard_items_hash ON clipboard_items(content_hash)',
    );
    await db.execute(
      'CREATE INDEX idx_clipboard_items_created ON clipboard_items(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_clipboard_items_last_copied ON clipboard_items(last_copied_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_clipboard_items_search ON clipboard_items(normalized_content)',
    );
    await db.execute(
      'CREATE INDEX idx_item_collections_collection ON clipboard_item_collections(collection_id)',
    );
    await _createSyncStateTable(db);
    await _seedCollections(db);
  }

  static Future<void> _createSyncStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_sync_states (
        item_id TEXT NOT NULL,
        peer_device_id TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        last_attempt_at INTEGER,
        synced_at INTEGER,
        retry_count INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        PRIMARY KEY (item_id, peer_device_id),
        FOREIGN KEY (item_id) REFERENCES clipboard_items(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_states_peer_status
      ON item_sync_states(peer_device_id, sync_status)
    ''');
  }

  static Future<void> _seedCollections(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const defaults = [
      ('work', 'Công việc', 'work'),
      ('personal', 'Cá nhân', 'person'),
      ('code', 'Code', 'code'),
      ('links', 'Link', 'link'),
      ('replies', 'Mẫu trả lời', 'reply'),
    ];
    for (var index = 0; index < defaults.length; index++) {
      final item = defaults[index];
      await db.insert('collections', {
        'id': item.$1,
        'name': item.$2,
        'icon': item.$3,
        'created_at': now,
        'updated_at': now,
        'sort_order': index,
      });
    }
  }

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createSyncStateTable(db);
    }
  }

  Future<void> close() => database.close();
}
