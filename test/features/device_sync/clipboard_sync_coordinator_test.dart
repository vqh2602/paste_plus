import 'dart:async';

import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/device_sync/data/item_sync_state_repository.dart';
import 'package:clipflow/features/device_sync/domain/local_sharing_state.dart';
import 'package:clipflow/features/device_sync/domain/peer_connection_info.dart';
import 'package:clipflow/features/device_sync/domain/shared_clipboard_payload.dart';
import 'package:clipflow/features/device_sync/domain/shared_collection_payload.dart';
import 'package:clipflow/features/device_sync/services/clipboard_sync_coordinator.dart';
import 'package:clipflow/features/device_sync/services/local_sharing_service.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingTransport implements LocalSharingService {
  final sentItems = <SharedClipboardPayload>[];
  final sentCollections = <SharedCollectionPayload>[];
  bool failNextCollection = false;

  @override
  Stream<SharedCollectionPayload> get receivedCollections =>
      const Stream.empty();

  @override
  Stream<SharedClipboardPayload> get receivedPayloads => const Stream.empty();

  @override
  Stream<LocalSharingState> get states => const Stream.empty();

  @override
  Future<void> sendClipboard(
    String deviceId,
    SharedClipboardPayload payload,
  ) async => sentItems.add(payload);

  @override
  Future<void> sendCollection(
    String deviceId,
    SharedCollectionPayload payload,
  ) async {
    if (failNextCollection) {
      failNextCollection = false;
      throw StateError('temporary collection failure');
    }
    sentCollections.add(payload);
  }

  @override
  Future<void> block(String deviceId) async {}
  @override
  Future<void> cancelPairing(String deviceId) async {}
  @override
  Future<void> confirmPairing(String deviceId) async {}
  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> forget(String deviceId) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> requestPairing(String deviceId) async {}
  @override
  Future<void> start(AppSettings settings) async {}
  @override
  Future<void> unblock(String deviceId) async {}
  @override
  Future<void> updateConfiguration(AppSettings settings) async {}
}

void main() {
  test('new connection backfills pinned and collection metadata', () async {
    final database = await AppDatabase.open(inMemory: true);
    addTearDown(database.close);
    final repository = SqliteClipboardRepository(database);
    final item = await repository.store(
      const ClipboardPayload(text: 'Saved on device A'),
      const AppSettings(ignoreSensitive: false),
    );
    await repository.setPinned(item!.id, true);
    final collection = await repository.createCollection('Shared collection');
    await repository.addToCollection(item.id, collection.id);

    final transport = _RecordingTransport();
    final coordinator = ClipboardSyncCoordinator(
      transport: transport,
      syncStates: ItemSyncStateRepository(database),
      clipboardRepository: repository,
      readSettings: () =>
          const AppSettings(localSharingEnabled: true, autoSyncClipboard: true),
    );
    const peer = PeerConnectionInfo(
      deviceId: 'device-b',
      deviceName: 'Device B',
      platform: 'test',
      ipAddress: '127.0.0.1',
      port: 1234,
      status: PeerConnectionStatus.connected,
      quality: ConnectionQuality.excellent,
      pendingItems: 0,
      isTrusted: true,
      isBlocked: false,
    );

    await coordinator.drainConnectedPeers(
      const LocalSharingState(peers: [peer]),
    );

    expect(
      transport.sentCollections.map((value) => value.collectionId),
      contains(collection.id),
    );
    final sent = transport.sentItems.singleWhere(
      (payload) => payload.text == 'Saved on device A',
    );
    expect(sent.isPinned, isTrue);
    expect(sent.writeToSystemClipboard, isFalse);
    expect(
      sent.collections.map((value) => value.collectionId),
      contains(collection.id),
    );
    expect(
      DateTime.now().difference(sent.createdAt),
      lessThan(const Duration(minutes: 1)),
    );
  });

  test(
    'collection failure does not block pinned backfill and is retried',
    () async {
      final database = await AppDatabase.open(inMemory: true);
      addTearDown(database.close);
      final repository = SqliteClipboardRepository(database);
      final item = await repository.store(
        const ClipboardPayload(text: 'Pinned before connecting'),
        const AppSettings(ignoreSensitive: false),
      );
      await repository.setPinned(item!.id, true);
      await repository.createCollection('Retry collection');

      final transport = _RecordingTransport()..failNextCollection = true;
      final coordinator = ClipboardSyncCoordinator(
        transport: transport,
        syncStates: ItemSyncStateRepository(database),
        clipboardRepository: repository,
        readSettings: () => const AppSettings(
          localSharingEnabled: true,
          autoSyncClipboard: true,
        ),
      );
      const peer = PeerConnectionInfo(
        deviceId: 'device-b',
        deviceName: 'Device B',
        platform: 'test',
        ipAddress: '127.0.0.1',
        port: 1234,
        status: PeerConnectionStatus.connected,
        quality: ConnectionQuality.excellent,
        pendingItems: 0,
        isTrusted: true,
        isBlocked: false,
      );
      const state = LocalSharingState(peers: [peer]);

      await coordinator.drainConnectedPeers(state);
      expect(
        transport.sentItems.any(
          (payload) => payload.text == 'Pinned before connecting',
        ),
        isTrue,
      );
      expect(
        transport.sentCollections.any(
          (payload) => payload.collectionId == 'work',
        ),
        isFalse,
      );

      await coordinator.drainConnectedPeers(state);
      expect(
        transport.sentCollections.any(
          (payload) => payload.collectionId == 'work',
        ),
        isTrue,
      );
    },
  );
}
