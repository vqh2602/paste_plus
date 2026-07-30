import 'package:clipflow/features/device_sync/domain/shared_clipboard_payload.dart';
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
      );
      final bob = MdnsTlsLocalSharingService(
        identityStore: DeviceIdentityStore(_MemorySecretStore()),
        enableMdns: false,
        platformOverride: 'test',
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
      await Future.wait([
        alice.confirmPairing(bob.deviceId!),
        bob.confirmPairing(alice.deviceId!),
      ]);
      await connecting.timeout(const Duration(seconds: 20));
      await Future.wait([
        aliceConnected.timeout(const Duration(seconds: 10)),
        bobConnected.timeout(const Duration(seconds: 10)),
      ]);

      final received = bob.receivedPayloads.first;
      await alice.sendClipboard(
        bob.deviceId!,
        SharedClipboardPayload(
          messageId: 'message-1',
          sourceDeviceId: alice.deviceId!,
          createdAt: DateTime.now(),
          text: 'TLS clipboard payload',
        ),
      );
      expect(
        (await received.timeout(const Duration(seconds: 10))).text,
        'TLS clipboard payload',
      );

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
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
