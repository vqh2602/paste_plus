enum PeerConnectionStatus {
  discovered,
  pairing,
  connecting,
  authenticating,
  syncing,
  reconnecting,
  connected,
  disconnected,
  rejected,
  incompatible,
  blocked,
}

enum ConnectionQuality { excellent, good, fair, poor, offline }

class PeerConnectionInfo {
  const PeerConnectionInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.ipAddress,
    required this.port,
    required this.status,
    required this.quality,
    required this.pendingItems,
    required this.isTrusted,
    required this.isBlocked,
    this.latencyMs,
    this.packetLoss,
    this.transferSpeedMbps,
    this.lastSeenAt,
    this.lastSyncedAt,
    this.appVersion = '',
    this.protocolVersion = '',
    this.reconnectAttempts = 0,
    this.requiresManualReconnect = false,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String ipAddress;
  final int port;
  final PeerConnectionStatus status;
  final ConnectionQuality quality;
  final int? latencyMs;
  final double? packetLoss;
  final double? transferSpeedMbps;
  final DateTime? lastSeenAt;
  final DateTime? lastSyncedAt;
  final int pendingItems;
  final bool isTrusted;
  final bool isBlocked;
  final String appVersion;
  final String protocolVersion;
  final int reconnectAttempts;
  final bool requiresManualReconnect;

  bool get isConnected => switch (status) {
    PeerConnectionStatus.connecting ||
    PeerConnectionStatus.authenticating ||
    PeerConnectionStatus.syncing ||
    PeerConnectionStatus.connected => true,
    _ => false,
  };

  PeerConnectionInfo copyWith({
    String? deviceName,
    String? platform,
    String? ipAddress,
    int? port,
    PeerConnectionStatus? status,
    ConnectionQuality? quality,
    int? latencyMs,
    double? packetLoss,
    double? transferSpeedMbps,
    DateTime? lastSeenAt,
    DateTime? lastSyncedAt,
    int? pendingItems,
    bool? isTrusted,
    bool? isBlocked,
    String? appVersion,
    String? protocolVersion,
    int? reconnectAttempts,
    bool? requiresManualReconnect,
  }) {
    return PeerConnectionInfo(
      deviceId: deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      status: status ?? this.status,
      quality: quality ?? this.quality,
      latencyMs: latencyMs ?? this.latencyMs,
      packetLoss: packetLoss ?? this.packetLoss,
      transferSpeedMbps: transferSpeedMbps ?? this.transferSpeedMbps,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingItems: pendingItems ?? this.pendingItems,
      isTrusted: isTrusted ?? this.isTrusted,
      isBlocked: isBlocked ?? this.isBlocked,
      appVersion: appVersion ?? this.appVersion,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      requiresManualReconnect:
          requiresManualReconnect ?? this.requiresManualReconnect,
    );
  }
}
