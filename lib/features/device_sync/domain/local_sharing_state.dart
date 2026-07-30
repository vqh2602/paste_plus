import 'peer_connection_info.dart';

class PairingSession {
  const PairingSession({
    required this.peer,
    required this.confirmationCode,
    required this.expiresAt,
    this.isIncoming = false,
    this.isLocalConfirmed = false,
  });

  final PeerConnectionInfo peer;
  final String confirmationCode;
  final DateTime expiresAt;
  final bool isIncoming;
  final bool isLocalConfirmed;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
}

class LocalSharingState {
  const LocalSharingState({
    this.peers = const [],
    this.isDiscovering = false,
    this.pairingSession,
    this.errorKey,
  });

  final List<PeerConnectionInfo> peers;
  final bool isDiscovering;
  final PairingSession? pairingSession;
  final String? errorKey;

  List<PeerConnectionInfo> get availableDevices => peers
      .where((peer) => !peer.isTrusted && !peer.isBlocked)
      .toList(growable: false);

  List<PeerConnectionInfo> get pairedDevices =>
      peers.where((peer) => peer.isTrusted).toList(growable: false);

  List<PeerConnectionInfo> get blockedDevices =>
      peers.where((peer) => peer.isBlocked).toList(growable: false);

  int get connectedCount =>
      pairedDevices.where((peer) => peer.isConnected).length;

  LocalSharingState copyWith({
    List<PeerConnectionInfo>? peers,
    bool? isDiscovering,
    PairingSession? pairingSession,
    bool clearPairingSession = false,
    String? errorKey,
    bool clearError = false,
  }) {
    return LocalSharingState(
      peers: peers ?? this.peers,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      pairingSession: clearPairingSession
          ? null
          : pairingSession ?? this.pairingSession,
      errorKey: clearError ? null : errorKey ?? this.errorKey,
    );
  }
}
