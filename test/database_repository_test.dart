import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SqliteClipboardRepository repository;

  setUp(() async {
    database = await AppDatabase.open(inMemory: true);
    repository = SqliteClipboardRepository(database);
  });

  tearDown(() => database.close());

  test('migration creates all MVP tables and indexes', () async {
    final tables = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll([
        'clipboard_items',
        'collections',
        'clipboard_item_collections',
      ]),
    );

    final indexes = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final indexNames = indexes.map((row) => row['name']).toSet();
    expect(indexNames, contains('idx_clipboard_items_hash'));
    expect(indexNames, contains('idx_clipboard_items_created'));
  });

  test('repository hashes, deduplicates, pins and deletes', () async {
    const payload = ClipboardPayload(text: 'https://flutter.dev');
    const settings = AppSettings(ignoreSensitive: false);
    final first = await repository.store(payload, settings);
    final duplicate = await repository.store(payload, settings);

    expect(first, isNotNull);
    expect(duplicate?.id, first?.id);
    var items = await repository.getItems();
    expect(items, hasLength(1));
    expect(items.single.copyCount, 2);

    await repository.setPinned(items.single.id, true);
    items = await repository.getItems(pinnedOnly: true);
    expect(items.single.isPinned, isTrue);

    await repository.deleteItem(items.single.id);
    expect(await repository.getItems(), isEmpty);
  });

  test(
    'collections are seeded and deleting one preserves clipboard items',
    () async {
      final stored = await repository.store(
        const ClipboardPayload(text: 'Keep me'),
        const AppSettings(ignoreSensitive: false),
      );
      final collections = await repository.getCollections();
      expect(collections, hasLength(5));
      await repository.addToCollection(stored!.id, collections.first.id);
      await repository.deleteCollection(collections.first.id);
      expect(await repository.getItems(), hasLength(1));
    },
  );
}
