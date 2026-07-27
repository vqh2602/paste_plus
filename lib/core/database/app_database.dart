import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this.database, this.databasePath);

  static const version = 1;
  final Database database;
  final String databasePath;

  static Future<AppDatabase> open({bool inMemory = false}) async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = inMemory
        ? inMemoryDatabasePath
        : p.join(
            (await getApplicationSupportDirectory()).path,
            'clipflow.sqlite',
          );
    final db = await openDatabase(
      dbPath,
      version: version,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createV1,
      onUpgrade: _migrate,
    );
    return AppDatabase._(db, dbPath);
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
    await _seedCollections(db);
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
    // Future schema versions are migrated incrementally here.
  }

  Future<void> close() => database.close();
}
