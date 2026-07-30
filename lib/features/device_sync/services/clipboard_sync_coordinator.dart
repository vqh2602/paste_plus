import 'dart:io';
import 'dart:typed_data';

import '../../clipboard_history/domain/clipboard_item.dart';
import '../../clipboard_history/domain/clipboard_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../data/item_sync_state_repository.dart';
import '../domain/local_sharing_state.dart';
import '../domain/shared_clipboard_payload.dart';
import 'local_sharing_service.dart';

class ClipboardSyncCoordinator {
  ClipboardSyncCoordinator({
    required LocalSharingService transport,
    required ItemSyncStateRepository syncStates,
    required ClipboardRepository clipboardRepository,
    required AppSettings Function() readSettings,
  }) : _transport = transport,
       _syncStates = syncStates,
       _clipboardRepository = clipboardRepository,
       _readSettings = readSettings;

  final LocalSharingService _transport;
  final ItemSyncStateRepository _syncStates;
  final ClipboardRepository _clipboardRepository;
  final AppSettings Function() _readSettings;
  final _drainingPeers = <String>{};
  final _sendingOperations = <String>{};

  Future<void> itemStored(ClipboardItem item, LocalSharingState sharing) async {
    final settings = _readSettings();
    if (!_shouldSync(item, settings)) return;
    final peerIds = sharing.pairedDevices.map((peer) => peer.deviceId).toList();
    await _syncStates.enqueue(item.id, peerIds);
    for (final peer in sharing.pairedDevices.where(
      (peer) => peer.isConnected,
    )) {
      await _send(item, peer.deviceId, settings);
    }
  }

  Future<void> drainConnectedPeers(LocalSharingState sharing) async {
    for (final peer in sharing.pairedDevices.where(
      (peer) => peer.isConnected,
    )) {
      if (!_drainingPeers.add(peer.deviceId)) continue;
      try {
        await _drain(peer.deviceId);
      } finally {
        _drainingPeers.remove(peer.deviceId);
      }
    }
  }

  Future<void> _drain(String peerId) async {
    final pending = await _syncStates.pendingForPeer(peerId);
    if (pending.isEmpty) return;
    final wantedIds = pending.map((state) => state.itemId).toSet();
    final items = await _clipboardRepository.getItems(limit: 5000);
    final byId = {for (final item in items) item.id: item};
    final settings = _readSettings();
    for (final id in wantedIds) {
      final item = byId[id];
      if (item != null && _shouldSync(item, settings)) {
        await _send(item, peerId, settings);
      }
    }
  }

  Future<void> _send(
    ClipboardItem item,
    String peerId,
    AppSettings settings,
  ) async {
    final operationId = '${item.id}:$peerId';
    if (!_sendingOperations.add(operationId)) return;
    try {
      await _syncStates.markSending(item.id, peerId);
      Uint8List? imageBytes;
      if (item.imagePath != null) {
        final file = File(item.imagePath!);
        if (await file.exists()) {
          final length = await file.length();
          if (length <= settings.sharingMaxImageMb * 1024 * 1024) {
            imageBytes = await file.readAsBytes();
          }
        }
      }
      await _transport.sendClipboard(
        peerId,
        SharedClipboardPayload(
          messageId:
              '${item.id}:${item.updatedAt.microsecondsSinceEpoch}:$peerId',
          sourceDeviceId: '',
          createdAt: item.updatedAt,
          text: item.content.isEmpty ? null : item.content,
          imageBytes: imageBytes,
        ),
      );
      await _syncStates.markCompleted(item.id, peerId);
    } on Object catch (error) {
      await _syncStates.markFailed(
        item.id,
        peerId,
        errorMessage: error.runtimeType.toString(),
      );
    } finally {
      _sendingOperations.remove(operationId);
    }
  }

  bool _shouldSync(ClipboardItem item, AppSettings settings) {
    return settings.localSharingEnabled &&
        !settings.allConnectionsPaused &&
        settings.autoSyncClipboard &&
        (!settings.syncPinnedItemsOnly || item.isPinned);
  }
}
