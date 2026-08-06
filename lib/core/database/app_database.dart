import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this.database, this.databasePath);

  static const version = 7;
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
    if (!inMemory && supportDirectory != null) {
      await _repairImagePaths(db, supportDirectory.path);
    }
    return AppDatabase._(db, dbPath);
  }

  static Future<void> _repairImagePaths(
    Database db,
    String currentSupportPath,
  ) async {
    try {
      final rows = await db.query(
        'clipboard_items',
        columns: ['id', 'image_path'],
        where: "image_path IS NOT NULL AND image_path != ''",
      );
      if (rows.isEmpty) return;

      final currentImagesDir = p.join(currentSupportPath, 'clipboard_images');
      final batch = db.batch();
      var hasUpdates = false;

      for (final row in rows) {
        final id = row['id'] as String?;
        final rawPath = row['image_path'] as String?;
        if (id == null || rawPath == null || rawPath.isEmpty) continue;

        final file = File(rawPath);
        if (!await file.exists()) {
          final filename = p.basename(rawPath);
          final candidatePath = p.join(currentImagesDir, filename);
          if (await File(candidatePath).exists()) {
            batch.update(
              'clipboard_items',
              {'image_path': candidatePath},
              where: 'id = ?',
              whereArgs: [id],
            );
            hasUpdates = true;
          }
        }
      }

      if (hasUpdates) {
        await batch.commit(noResult: true);
      }
    } catch (_) {
      // Ignore non-critical startup repair errors
    }
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
        await transaction.execute('''
          INSERT OR IGNORE INTO clipboard_items (
            id, content, normalized_content, content_hash, content_type,
            created_at, updated_at, last_copied_at, source_app_name,
            source_app_identifier, is_pinned, is_sensitive, image_path,
            metadata_json, note, copy_count
          )
          SELECT id, content, normalized_content, content_hash, content_type,
            created_at, updated_at, last_copied_at, source_app_name,
            source_app_identifier, is_pinned, is_sensitive, image_path,
            metadata_json, note, copy_count
          FROM legacy_clipflow.clipboard_items
        ''');
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
        note TEXT,
        copy_count INTEGER NOT NULL DEFAULT 1,
        contains_url INTEGER NOT NULL DEFAULT 0,
        primary_url TEXT,
        url_host TEXT,
        url_kind TEXT,
        mime_type TEXT,
        file_extension TEXT,
        has_ocr_text INTEGER NOT NULL DEFAULT 0,
        searchable_text TEXT NOT NULL DEFAULT ''
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
    await _createDeepSearchIndexes(db);
    await db.execute(
      'CREATE INDEX idx_item_collections_collection ON clipboard_item_collections(collection_id)',
    );
    await _createSyncStateTable(db);
    await _createEmbeddingsTable(db);
    await _createFtsTable(db);
    await _seedCollections(db);
  }

  static Future<void> _createFtsTable(Database db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS clipboard_items_fts USING fts5(
          clipboard_id UNINDEXED,
          searchable_text,
          source_app_name,
          note,
          tokenize = 'unicode61'
        )
      ''');

      // Always DROP then re-CREATE every trigger so that stale triggers from
      // older schema versions (e.g. ones that reference `normalized_content`
      // instead of `searchable_text`) are replaced.  DROP TABLE on the FTS
      // virtual table does NOT remove triggers that are defined ON
      // clipboard_items, so CREATE TRIGGER IF NOT EXISTS would silently keep
      // a broken old trigger.
      await db.execute('DROP TRIGGER IF EXISTS clipboard_items_ai');
      await db.execute('''
        CREATE TRIGGER clipboard_items_ai AFTER INSERT ON clipboard_items BEGIN
          INSERT INTO clipboard_items_fts(clipboard_id, searchable_text, source_app_name, note)
          VALUES (new.id, new.searchable_text, COALESCE(new.source_app_name, ''), COALESCE(new.note, ''));
        END;
      ''');

      await db.execute('DROP TRIGGER IF EXISTS clipboard_items_ad');
      await db.execute('''
        CREATE TRIGGER clipboard_items_ad AFTER DELETE ON clipboard_items BEGIN
          DELETE FROM clipboard_items_fts WHERE clipboard_id = old.id;
        END;
      ''');

      await db.execute('DROP TRIGGER IF EXISTS clipboard_items_au');
      await db.execute('''
        CREATE TRIGGER clipboard_items_au AFTER UPDATE ON clipboard_items BEGIN
          DELETE FROM clipboard_items_fts WHERE clipboard_id = old.id;
          INSERT INTO clipboard_items_fts(clipboard_id, searchable_text, source_app_name, note)
          VALUES (new.id, new.searchable_text, COALESCE(new.source_app_name, ''), COALESCE(new.note, ''));
        END;
      ''');

      await db.execute('''
        INSERT OR IGNORE INTO clipboard_items_fts(clipboard_id, searchable_text, source_app_name, note)
        SELECT id, searchable_text, COALESCE(source_app_name, ''), COALESCE(note, '') FROM clipboard_items;
      ''');
    } catch (_) {
      // Ignore SQLite instances where FTS5 extension module is disabled
    }
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

  static Future<void> _createEmbeddingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clipboard_embeddings (
        clipboard_id TEXT NOT NULL,
        content_hash TEXT NOT NULL,
        model_id TEXT NOT NULL,
        vector BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (clipboard_id, model_id),
        FOREIGN KEY (clipboard_id) REFERENCES clipboard_items(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_embeddings_hash
      ON clipboard_embeddings(content_hash)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_embeddings_model
      ON clipboard_embeddings(model_id)
    ''');
  }

  static Future<void> _createDeepSearchIndexes(Database db) async {
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_clipboard_type_created
      ON clipboard_items(content_type, created_at DESC)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_clipboard_contains_url
      ON clipboard_items(contains_url, created_at DESC)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_clipboard_url_host
      ON clipboard_items(url_host, created_at DESC)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_clipboard_extension
      ON clipboard_items(file_extension, created_at DESC)''');
    await db.execute('''CREATE INDEX IF NOT EXISTS idx_clipboard_pinned_created
      ON clipboard_items(is_pinned, created_at DESC)''');
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

  /// Safely adds a column, ignoring the error if it already exists.
  /// SQLite does not support `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`,
  /// so we swallow the duplicate-column error that occurs when migrations
  /// are re-run against a database that already contains the column (e.g.
  /// after a legacy-data merge or a failed partial upgrade).
  static Future<void> _addColumnIfNotExists(
    DatabaseExecutor db,
    String sql,
  ) async {
    try {
      await db.execute(sql);
    } on DatabaseException catch (e) {
      // SQLite error 1 = SQLITE_ERROR; message contains "duplicate column name"
      if (!e.toString().contains('duplicate column name')) rethrow;
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
    if (oldVersion < 3) {
      await _createEmbeddingsTable(db);
    }
    if (oldVersion < 4) {
      await _createFtsTable(db);
    }
    if (oldVersion < 5) {
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN note TEXT',
      );
      await db.execute('DROP TABLE IF EXISTS clipboard_items_fts');
      await _createFtsTable(db);
    }
    if (oldVersion < 6) {
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN contains_url INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN primary_url TEXT',
      );
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN url_host TEXT',
      );
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN url_kind TEXT',
      );
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN mime_type TEXT',
      );
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN file_extension TEXT',
      );
      await _addColumnIfNotExists(
        db,
        'ALTER TABLE clipboard_items ADD COLUMN has_ocr_text INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfNotExists(
        db,
        "ALTER TABLE clipboard_items ADD COLUMN searchable_text TEXT NOT NULL DEFAULT ''",
      );

      // Drop FTS table (and its AFTER UPDATE trigger) BEFORE running the
      // bulk UPDATE so the trigger cannot fire with an outdated column list.
      await db.execute('DROP TABLE IF EXISTS clipboard_items_fts');

      // Backfill new columns.  Wrapped in try-catch: if the DB already had
      // these columns populated (partial migration), the UPDATE is a no-op
      // and any unexpected failure here must not block the app from opening.
      try {
        await db.execute('''
          UPDATE clipboard_items SET
            contains_url = CASE
              WHEN content_type = 'url' OR LOWER(content) LIKE '%http://%'
                OR LOWER(content) LIKE '%https://%' OR LOWER(content) LIKE '%www.%'
              THEN 1 ELSE 0 END,
            searchable_text = LOWER(
              content || ' ' || COALESCE(source_app_name, '') || ' ' || COALESCE(note, '')
            )
        ''');
      } on Object {
        // Non-fatal: columns keep their DEFAULT values; FTS rebuild below
        // will still populate searchable_text correctly via the new trigger.
      }

      await _createDeepSearchIndexes(db);
      await _createFtsTable(db);
    }
    if (oldVersion < 7) {
      // Force-rebuild FTS table and triggers. Older migration paths used
      // `CREATE TRIGGER IF NOT EXISTS` which silently preserved stale
      // triggers referencing `normalized_content` (old schema column).
      // Dropping the FTS virtual table does NOT drop triggers defined ON
      // clipboard_items, so we must drop each trigger explicitly here.
      await db.execute('DROP TABLE IF EXISTS clipboard_items_fts');
      await db.execute('DROP TRIGGER IF EXISTS clipboard_items_ai');
      await db.execute('DROP TRIGGER IF EXISTS clipboard_items_ad');
      await db.execute('DROP TRIGGER IF EXISTS clipboard_items_au');
      await _createFtsTable(db);
    }
  }

  Future<void> close() => database.close();
}
