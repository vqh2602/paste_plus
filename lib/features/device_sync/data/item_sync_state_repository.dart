import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/item_sync_state.dart';

class ItemSyncStateRepository {
  const ItemSyncStateRepository(this._database);

  final AppDatabase _database;

  Future<void> enqueue(String itemId, Iterable<String> peerDeviceIds) async {
    final batch = _database.database.batch();
    for (final peerDeviceId in peerDeviceIds) {
      batch.insert('item_sync_states', {
        'item_id': itemId,
        'peer_device_id': peerDeviceId,
        'sync_status': ItemSyncStatus.pending.name,
        'retry_count': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> enqueueForPeer(
    String peerDeviceId,
    Iterable<String> itemIds,
  ) async {
    final batch = _database.database.batch();
    for (final itemId in itemIds) {
      batch.insert('item_sync_states', {
        'item_id': itemId,
        'peer_device_id': peerDeviceId,
        'sync_status': ItemSyncStatus.pending.name,
        'retry_count': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<ItemSyncState>> pendingForPeer(String peerDeviceId) async {
    final rows = await _database.database.query(
      'item_sync_states',
      where: 'peer_device_id = ? AND sync_status IN (?, ?)',
      whereArgs: [
        peerDeviceId,
        ItemSyncStatus.pending.name,
        ItemSyncStatus.failed.name,
      ],
      orderBy: 'COALESCE(last_attempt_at, 0) ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> markSending(String itemId, String peerDeviceId) {
    return _update(
      itemId,
      peerDeviceId,
      status: ItemSyncStatus.sending,
      values: {'last_attempt_at': DateTime.now().millisecondsSinceEpoch},
    );
  }

  Future<void> markCompleted(String itemId, String peerDeviceId) {
    return _update(
      itemId,
      peerDeviceId,
      status: ItemSyncStatus.completed,
      values: {
        'synced_at': DateTime.now().millisecondsSinceEpoch,
        'error_message': null,
      },
    );
  }

  Future<void> markFailed(
    String itemId,
    String peerDeviceId, {
    String? errorMessage,
  }) async {
    await _database.database.rawUpdate(
      '''
      UPDATE item_sync_states
      SET sync_status = ?,
          last_attempt_at = ?,
          retry_count = retry_count + 1,
          error_message = ?
      WHERE item_id = ? AND peer_device_id = ?
      ''',
      [
        ItemSyncStatus.failed.name,
        DateTime.now().millisecondsSinceEpoch,
        errorMessage,
        itemId,
        peerDeviceId,
      ],
    );
  }

  Future<void> resetInterruptedTransfers(String peerDeviceId) async {
    await _database.database.update(
      'item_sync_states',
      {'sync_status': ItemSyncStatus.pending.name},
      where: 'peer_device_id = ? AND sync_status = ?',
      whereArgs: [peerDeviceId, ItemSyncStatus.sending.name],
    );
  }

  Future<void> removePeer(String peerDeviceId) async {
    await _database.database.delete(
      'item_sync_states',
      where: 'peer_device_id = ?',
      whereArgs: [peerDeviceId],
    );
  }

  Future<void> _update(
    String itemId,
    String peerDeviceId, {
    required ItemSyncStatus status,
    required Map<String, Object?> values,
  }) async {
    await _database.database.update(
      'item_sync_states',
      {'sync_status': status.name, ...values},
      where: 'item_id = ? AND peer_device_id = ?',
      whereArgs: [itemId, peerDeviceId],
    );
  }

  ItemSyncState _fromRow(Map<String, Object?> row) {
    DateTime? date(String key) {
      final value = row[key] as int?;
      return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
    }

    return ItemSyncState(
      itemId: row['item_id'] as String,
      peerDeviceId: row['peer_device_id'] as String,
      status: ItemSyncStatus.values.byName(row['sync_status'] as String),
      lastAttemptAt: date('last_attempt_at'),
      syncedAt: date('synced_at'),
      retryCount: row['retry_count'] as int,
      errorMessage: row['error_message'] as String?,
    );
  }
}
