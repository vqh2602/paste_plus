import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/core/services/clipboard_watcher.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/presentation/history_controller.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _IdleClipboardWatcher implements ClipboardWatcher {
  @override
  Future<ClipboardPayload?> readCurrent() async => null;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Stream<ClipboardPayload> watch() => const Stream.empty();
  @override
  Future<void> write(ClipboardPayload payload) async {}
}

void main() {
  test('received pinned item is visible in its remote collection', () async {
    final database = await AppDatabase.open(inMemory: true);
    addTearDown(database.close);
    final repository = SqliteClipboardRepository(database);
    var collectionsReloaded = false;
    final controller = ClipboardHistoryController(
      repository,
      _IdleClipboardWatcher(),
      () => const AppSettings(monitoringEnabled: false, ignoreSensitive: false),
      onCollectionsChanged: () async => collectionsReloaded = true,
    );
    addTearDown(controller.dispose);
    final now = DateTime.now();
    final collection = ClipboardCollection(
      id: 'remote-collection',
      name: 'From device A',
      icon: 'folder',
      createdAt: now,
      updatedAt: now,
      sortOrder: 1,
    );

    await controller.receiveRemote(
      const ClipboardPayload(text: 'Pinned remotely'),
      isPinned: true,
      collections: [collection],
      writeToSystemClipboard: false,
    );

    final pinned = await repository.getItems(pinnedOnly: true);
    expect(pinned.map((item) => item.content), contains('Pinned remotely'));
    final remoteCollections = await repository.getCollections();
    expect(remoteCollections.map((value) => value.id), contains(collection.id));
    final collectionItems = await repository.getItems(
      collectionId: collection.id,
    );
    expect(
      collectionItems.map((item) => item.content),
      contains('Pinned remotely'),
    );
    expect(collectionsReloaded, isTrue);
  });
}
