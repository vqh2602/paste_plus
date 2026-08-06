import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/search_query.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SqliteClipboardRepository repository;
  const settings = AppSettings();

  setUp(() async {
    database = await AppDatabase.open(inMemory: true);
    repository = SqliteClipboardRepository(database);
  });

  tearDown(() => database.close());

  Future<String> store(String text, {String? app}) async {
    final item = await repository.store(
      ClipboardPayload(text: text, sourceAppName: app ?? 'Test App'),
      settings,
    );
    return item!.id;
  }

  group('structured clipboard search', () {
    test('containsUrl matches real URLs and ignores the word "link"', () async {
      final githubId = await store('https://github.com/flutter/flutter');
      final textUrlId = await store('See the docs at https://example.com/guide');
      final codeId = await store(
        'final response = await http.get(Uri.parse("https://api.example.com/v1"));',
      );
      final wordOnlyId = await store('remember to send him the link tomorrow');

      final page = await repository.search(
        const ClipboardSearchQuery(containsUrl: true),
      );
      final ids = page.items.map((item) => item.id).toSet();

      expect(ids, containsAll([githubId, textUrlId, codeId]));
      expect(ids, isNot(contains(wordOnlyId)));
      expect(page.total, 3);
    });

    test('urlHosts filters by parsed host, including subdomains', () async {
      final githubId = await store('https://github.com/flutter/flutter/issues/1');
      await store('https://example.com/blog');

      final page = await repository.search(
        const ClipboardSearchQuery(containsUrl: true, urlHosts: {'github.com'}),
      );
      expect(page.items.map((item) => item.id), [githubId]);
    });

    test('content type filter returns only that type', () async {
      await store('https://example.com');
      final codeId = await store('void main() { runApp(const MyApp()); }');

      final page = await repository.search(
        const ClipboardSearchQuery(
          contentTypes: {ClipboardContentType.code},
        ),
      );
      expect(page.items.map((item) => item.id), [codeId]);
    });

    test('sensitive items are excluded unless explicitly requested', () async {
      final id = await store('https://example.com/secret');
      await database.database.update(
        'clipboard_items',
        {'is_sensitive': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      final defaultPage = await repository.search(
        const ClipboardSearchQuery(containsUrl: true),
      );
      expect(defaultPage.items, isEmpty);

      final explicit = await repository.search(
        const ClipboardSearchQuery(containsUrl: true, includeSensitive: true),
      );
      expect(explicit.items.single.id, id);
    });

    test('text query searches the stored searchable text', () async {
      final wanted = await store('firebase_core: ^3.0.0 in pubspec');
      await store('unrelated meeting note');

      final page = await repository.search(
        const ClipboardSearchQuery(textQuery: 'firebase'),
      );
      expect(page.items.map((item) => item.id), [wanted]);
    });

    test('pagination reports total and hasMore without loading everything',
        () async {
      for (var index = 0; index < 5; index++) {
        await store('https://example.com/page-$index');
      }

      final page = await repository.search(
        const ClipboardSearchQuery(containsUrl: true, limit: 2),
      );
      expect(page.items.length, 2);
      expect(page.total, 5);
      expect(page.hasMore, isTrue);
    });
  });

  group('batch mutations are real database writes', () {
    test('setPinnedMany, addItemsToCollection and deleteItems persist',
        () async {
      final first = await store('https://example.com/a');
      final second = await store('https://example.com/b');

      await repository.setPinnedMany([first, second], true);
      final pinned = await repository.getItemsByIds([first, second]);
      expect(pinned.every((item) => item.isPinned), isTrue);

      final collection = await repository.createCollection('Work');
      await repository.addItemsToCollection([first, second], collection.id);
      expect(await repository.collectionIdsForItem(first),
          contains(collection.id));

      await repository.deleteItems([first]);
      expect(await repository.getItemsByIds([first]), isEmpty);
      expect((await repository.getItemsByIds([second])).single.id, second);
    });

    test('findCollectionByName is case-insensitive', () async {
      final created = await repository.createCollection('Work');
      final found = await repository.findCollectionByName('work');
      expect(found?.id, created.id);
      expect(await repository.findCollectionByName('missing'), isNull);
    });

    test('getItemsByIds preserves the requested order', () async {
      final first = await store('one');
      final second = await store('two');
      final items = await repository.getItemsByIds([second, first]);
      expect(items.map((item) => item.id), [second, first]);
    });
  });

  test('feature columns are populated at store time', () async {
    final id = await store('Docs: https://github.com/flutter/flutter');
    final item = (await repository.getItemsByIds([id])).single;
    expect(item.containsUrl, isTrue);
    expect(item.urlHost, 'github.com');
    expect(item.urlKind, ClipboardUrlKind.repository.name);
    expect(item.searchableText, contains('github'));
  });
}
