import 'package:clipflow/features/device_sync/domain/shared_clipboard_payload.dart';
import 'package:clipflow/features/device_sync/domain/shared_collection_payload.dart';
import 'package:clipflow/features/device_sync/services/device_identity_store.dart';
import 'package:clipflow/features/device_sync/services/mdns_tls_local_sharing_service.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test(
    'pairs over real TLS loopback and transfers clipboard with ACK',
    () async {
      final alice = MdnsTlsLocalSharingService(
        identityStore: DeviceIdentityStore(_MemorySecretStore()),
        enableMdns: false,
        platformOverride: 'test',
        reconnectDelayOverride: const Duration(milliseconds: 10),
      );
      final bob = MdnsTlsLocalSharingService(
        identityStore: DeviceIdentityStore(_MemorySecretStore()),
        enableMdns: false,
        platformOverride: 'test',
        reconnectDelayOverride: const Duration(milliseconds: 10),
      );
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);

      await Future.wait([
        alice.start(
          const AppSettings(
            localSharingEnabled: true,
            deviceDisplayName: 'Alice',
          ),
        ),
        bob.start(
          const AppSettings(
            localSharingEnabled: true,
            deviceDisplayName: 'Bob',
          ),
        ),
      ]);

      final alicePairing = alice.states.firstWhere(
        (state) => state.pairingSession != null,
      );
      final bobPairing = bob.states.firstWhere(
        (state) => state.pairingSession != null,
      );
      final connecting = alice.connectDirect(
        address: '127.0.0.1',
        port: bob.listeningPort!,
        expectedDeviceId: bob.deviceId!,
        deviceName: 'Bob',
      );

      final pairings = await Future.wait([
        alicePairing.timeout(const Duration(seconds: 20)),
        bobPairing.timeout(const Duration(seconds: 20)),
      ]);
      expect(
        pairings[0].pairingSession!.confirmationCode,
        pairings[1].pairingSession!.confirmationCode,
      );
      expect(
        pairings[0].pairingSession!.confirmationCode,
        matches(RegExp(r'^\d{6}$')),
      );

      final aliceConnected = alice.states.firstWhere(
        (state) => state.connectedCount == 1,
      );
      final bobConnected = bob.states.firstWhere(
        (state) => state.connectedCount == 1,
      );
      final aliceWaiting = alice.states.firstWhere(
        (state) => state.pairingSession?.isLocalConfirmed == true,
      );
      await alice.confirmPairing(bob.deviceId!);
      expect(
        (await aliceWaiting.timeout(
          const Duration(seconds: 5),
        )).pairingSession!.isLocalConfirmed,
        isTrue,
      );
      await bob.confirmPairing(alice.deviceId!);
      await connecting.timeout(const Duration(seconds: 20));
      await Future.wait([
        aliceConnected.timeout(const Duration(seconds: 10)),
        bobConnected.timeout(const Duration(seconds: 10)),
      ]);

      final now = DateTime.now();
      final collection = SharedCollectionPayload(
        messageId: 'collection-message-1',
        sourceDeviceId: alice.deviceId!,
        collectionId: 'collection-1',
        name: 'Shared',
        icon: 'folder',
        createdAt: now,
        updatedAt: now,
        sortOrder: 10,
      );
      final receivedCollection = bob.receivedCollections.first;
      await alice.sendCollection(bob.deviceId!, collection);
      expect(
        (await receivedCollection.timeout(const Duration(seconds: 10))).name,
        'Shared',
      );

      final received = bob.receivedPayloads.first;
      await alice.sendClipboard(
        bob.deviceId!,
        SharedClipboardPayload(
          messageId: 'message-1',
          sourceDeviceId: alice.deviceId!,
          createdAt: DateTime.now(),
          text: 'TLS clipboard payload',
          isPinned: true,
          collections: [collection],
          writeToSystemClipboard: false,
        ),
      );
      final receivedPayload = await received.timeout(
        const Duration(seconds: 10),
      );
      expect(receivedPayload.text, 'TLS clipboard payload');
      expect(receivedPayload.isPinned, isTrue);
      expect(receivedPayload.collections.single.collectionId, 'collection-1');
      expect(receivedPayload.writeToSystemClipboard, isFalse);

      final bobDisconnected = bob.states.firstWhere(
        (state) => state.connectedCount == 0,
      );
      await alice.disconnect(bob.deviceId!);
      await bobDisconnected.timeout(const Duration(seconds: 10));
      final reconnected = Future.wait([
        alice.states.firstWhere((state) => state.connectedCount == 1),
        bob.states.firstWhere((state) => state.connectedCount == 1),
      ]);
      await alice.connectDirect(
        address: '127.0.0.1',
        port: bob.listeningPort!,
        expectedDeviceId: bob.deviceId!,
        deviceName: 'Bob',
      );
      await reconnected.timeout(const Duration(seconds: 10));

      final aliceIsInitiator = alice.deviceId!.compareTo(bob.deviceId!) < 0;
      final survivor = aliceIsInitiator ? bob : alice;
      final dropped = aliceIsInitiator ? alice : bob;
      final droppedId = dropped.deviceId!;
      final manualReconnectRequired = survivor.states.firstWhere(
        (state) => state.peers.any(
          (peer) => peer.deviceId == droppedId && peer.requiresManualReconnect,
        ),
      );
      await dropped.dispose();
      final retryState = await manualReconnectRequired.timeout(
        const Duration(seconds: 10),
      );
      final retryPeer = retryState.peers.firstWhere(
        (peer) => peer.deviceId == droppedId,
      );
      expect(retryPeer.reconnectAttempts, 5);
      expect(retryPeer.requiresManualReconnect, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
