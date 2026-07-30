enum ItemSyncStatus { pending, sending, completed, failed }

class ItemSyncState {
  const ItemSyncState({
    required this.itemId,
    required this.peerDeviceId,
    required this.status,
    required this.retryCount,
    this.lastAttemptAt,
    this.syncedAt,
    this.errorMessage,
  });

  final String itemId;
  final String peerDeviceId;
  final ItemSyncStatus status;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final int retryCount;
  final String? errorMessage;
}
