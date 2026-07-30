import 'package:clipflow/features/device_sync/domain/local_sharing_state.dart';
import 'package:clipflow/features/device_sync/domain/peer_connection_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('separates available, trusted, blocked, and connected peers', () {
    PeerConnectionInfo peer(
      String id, {
      bool trusted = false,
      bool blocked = false,
      PeerConnectionStatus status = PeerConnectionStatus.discovered,
    }) {
      return PeerConnectionInfo(
        deviceId: id,
        deviceName: id,
        platform: 'macOS',
        ipAddress: '192.168.1.2',
        port: 5353,
        status: status,
        quality: ConnectionQuality.good,
        pendingItems: 0,
        isTrusted: trusted,
        isBlocked: blocked,
      );
    }

    final state = LocalSharingState(
      peers: [
        peer('available'),
        peer(
          'connected',
          trusted: true,
          status: PeerConnectionStatus.connected,
        ),
        peer(
          'offline',
          trusted: true,
          status: PeerConnectionStatus.disconnected,
        ),
        peer('blocked', blocked: true, status: PeerConnectionStatus.blocked),
      ],
    );

    expect(state.availableDevices.map((item) => item.deviceId), ['available']);
    expect(state.pairedDevices, hasLength(2));
    expect(state.blockedDevices.map((item) => item.deviceId), ['blocked']);
    expect(state.connectedCount, 1);
  });
}
