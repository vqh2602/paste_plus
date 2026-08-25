import 'dart:typed_data';

import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/features/device_sync/data/item_sync_state_repository.dart';
import 'package:clipflow/features/device_sync/domain/item_sync_state.dart';
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
        'item_sync_states',
      ]),
    );

    final indexes = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    final indexNames = indexes.map((row) => row['name']).toSet();
    expect(indexNames, contains('idx_clipboard_items_hash'));
    expect(indexNames, contains('idx_clipboard_items_created'));
    expect(indexNames, contains('idx_sync_states_peer_status'));
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

  test('a native file list takes priority over an image thumbnail', () async {
    const filePath = '/Users/demo/Documents/report.xlsx';
    final stored = await repository.store(
      ClipboardPayload(
        text: filePath,
        filePaths: const [filePath],
        imageBytes: Uint8List.fromList(const [1, 2, 3]),
      ),
      const AppSettings(ignoreSensitive: false),
    );

    expect(stored, isNotNull);
    expect(stored!.content, filePath);
    expect(stored.contentType.name, 'file');
    expect(stored.imagePath, isNull);
  });

  test('editing content keeps the item id and refreshes its type', () async {
    final stored = await repository.store(
      const ClipboardPayload(text: 'plain text'),
      const AppSettings(ignoreSensitive: false),
    );

    final updated = await repository.updateItemContent(
      stored!,
      content: 'https://flutter.dev',
    );
    final persisted = (await repository.getItems()).single;

    expect(updated.id, stored.id);
    expect(persisted.id, stored.id);
    expect(persisted.content, 'https://flutter.dev');
    expect(persisted.contentType.name, 'url');
    expect(persisted.urlHost, 'flutter.dev');
  });

  test('repository persists emoji-only clipboard as emoji', () async {
    final stored = await repository.store(
      const ClipboardPayload(text: '👩🏽‍💻✨'),
      const AppSettings(ignoreSensitive: false),
    );

    expect(stored, isNotNull);
    expect(stored!.contentType.name, 'emoji');
    expect((await repository.getItems()).single.contentType.name, 'emoji');
  });

  test('repository skips financial and identity data when enabled', () async {
    final card = await repository.store(
      const ClipboardPayload(text: '4111 1111 1111 1111'),
      const AppSettings(),
    );
    final citizenId = await repository.store(
      const ClipboardPayload(text: '079203001234'),
      const AppSettings(),
    );
    final chineseCitizenId = await repository.store(
      const ClipboardPayload(text: '11010519491231002X'),
      const AppSettings(),
    );
    final indianAadhaar = await repository.store(
      const ClipboardPayload(text: '2345 6789 0124'),
      const AppSettings(),
    );
    final labeledPassport = await repository.store(
      const ClipboardPayload(text: 'Passport No: E12345678'),
      const AppSettings(),
    );
    final allowed = await repository.store(
      const ClipboardPayload(text: '4111 1111 1111 1111'),
      const AppSettings(ignoreFinancialAndIdentity: false),
    );

    expect(card, isNull);
    expect(citizenId, isNull);
    expect(chineseCitizenId, isNull);
    expect(indianAadhaar, isNull);
    expect(labeledPassport, isNull);
    expect(allowed, isNotNull);
  });

  test('repository skips clipboard captured from a sensitive window', () async {
    final protected = await repository.store(
      const ClipboardPayload(text: 'ordinary text', sensitiveContext: true),
      const AppSettings(ignoreSensitive: false),
    );
    final allowed = await repository.store(
      const ClipboardPayload(text: 'ordinary text', sensitiveContext: true),
      const AppSettings(ignoreSensitive: false, protectSensitiveWindows: false),
    );

    expect(protected, isNull);
    expect(allowed, isNotNull);
  });

  test(
    'collections are seeded and deleting one preserves clipboard items',
    () async {
      final stored = await repository.store(
        const ClipboardPayload(text: 'Keep me'),
        const AppSettings(ignoreSensitive: false),
      );
      final collections = await repository.getCollections();
      expect(collections, hasLength(6));
      final vault = collections.singleWhere((item) => item.isVault);
      await repository.renameCollection(vault.id, 'Cannot rename');
      await repository.deleteCollection(vault.id);
      expect(
        (await repository.getCollections()).singleWhere((item) => item.isVault),
        isNotNull,
      );
      final regular = collections.firstWhere((item) => !item.isSystem);
      await repository.addToCollection(stored!.id, regular.id);
      await repository.deleteCollection(regular.id);
      expect(await repository.getItems(), hasLength(1));
    },
  );

  test('sync state is tracked independently for every peer', () async {
    final stored = await repository.store(
      const ClipboardPayload(text: 'Share independently'),
      const AppSettings(ignoreSensitive: false),
    );
    final syncStates = ItemSyncStateRepository(database);
    await syncStates.enqueue(stored!.id, const ['peer-a', 'peer-b']);

    await syncStates.markSending(stored.id, 'peer-a');
    await syncStates.markCompleted(stored.id, 'peer-a');
    await syncStates.markSending(stored.id, 'peer-b');
    await syncStates.markFailed(stored.id, 'peer-b', errorMessage: 'offline');

    expect(await syncStates.pendingForPeer('peer-a'), isEmpty);
    final peerB = await syncStates.pendingForPeer('peer-b');
    expect(peerB, hasLength(1));
    expect(peerB.single.status, ItemSyncStatus.failed);
    expect(peerB.single.retryCount, 1);
    expect(peerB.single.errorMessage, 'offline');
  });
}
