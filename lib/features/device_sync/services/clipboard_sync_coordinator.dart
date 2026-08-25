import 'dart:io';
import 'dart:typed_data';

import '../../clipboard_history/domain/clipboard_item.dart';
import '../../clipboard_history/domain/clipboard_repository.dart';
import '../../settings/domain/app_settings.dart';
import '../data/item_sync_state_repository.dart';
import '../domain/local_sharing_state.dart';
import '../domain/shared_collection_payload.dart';
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
  final _connectedPeers = <String>{};
  final _metadataSyncedPeers = <String>{};
  final _lastMetadataSync = <String, DateTime>{};
  static const _metadataRefreshInterval = Duration(minutes: 2);

  Future<void> itemStored(ClipboardItem item, LocalSharingState sharing) async {
    final settings = _readSettings();
    if (!_shouldSync(item, settings)) return;
    final peerIds = sharing.pairedDevices.map((peer) => peer.deviceId).toList();
    await _syncStates.enqueue(item.id, peerIds);
    for (final peer in sharing.pairedDevices.where(
      (peer) => peer.isConnected,
    )) {
      await _send(
        item,
        peer.deviceId,
        settings,
        writeToSystemClipboard: true,
        metadataAuthoritative: false,
      );
    }
  }

  Future<void> itemMetadataChanged(
    ClipboardItem item,
    LocalSharingState sharing,
  ) async {
    final settings = _readSettings();
    if (!_sharingEnabled(settings)) return;
    for (final peer in sharing.pairedDevices.where(
      (peer) => peer.isConnected,
    )) {
      await _send(
        item,
        peer.deviceId,
        settings,
        writeToSystemClipboard: false,
        metadataAuthoritative: true,
      );
    }
  }

  Future<void> collectionChanged(
    ClipboardCollection collection,
    LocalSharingState sharing, {
    bool deleted = false,
  }) async {
    if (collection.isVault) return;
    final settings = _readSettings();
    if (!_sharingEnabled(settings)) return;
    for (final peer in sharing.pairedDevices.where(
      (peer) => peer.isConnected,
    )) {
      try {
        await _transport.sendCollection(
          peer.deviceId,
          _collectionPayload(collection, deleted: deleted),
        );
      } on Object {
        _metadataSyncedPeers.remove(peer.deviceId);
        _lastMetadataSync.remove(peer.deviceId);
      }
    }
  }

  Future<void> drainConnectedPeers(LocalSharingState sharing) async {
    final connectedNow = sharing.pairedDevices
        .where((peer) => peer.isConnected)
        .map((peer) => peer.deviceId)
        .toSet();
    _connectedPeers.removeWhere((peerId) => !connectedNow.contains(peerId));
    _metadataSyncedPeers.removeWhere(
      (peerId) => !connectedNow.contains(peerId),
    );
    _lastMetadataSync.removeWhere(
      (peerId, _) => !connectedNow.contains(peerId),
    );
    for (final peer in sharing.pairedDevices.where(
      (peer) => peer.isConnected,
    )) {
      final isNewConnection = _connectedPeers.add(peer.deviceId);
      final lastMetadataSync = _lastMetadataSync[peer.deviceId];
      final metadataExpired =
          lastMetadataSync == null ||
          DateTime.now().difference(lastMetadataSync) >=
              _metadataRefreshInterval;
      final shouldSyncMetadata =
          isNewConnection ||
          !_metadataSyncedPeers.contains(peer.deviceId) ||
          metadataExpired;
      if (!_drainingPeers.add(peer.deviceId)) continue;
      try {
        var collectionsSynced = true;
        if (shouldSyncMetadata) {
          collectionsSynced = await _sendCollections(peer.deviceId);
        }
        await _drain(peer.deviceId, includeSavedItems: shouldSyncMetadata);
        if (shouldSyncMetadata && collectionsSynced) {
          _metadataSyncedPeers.add(peer.deviceId);
          _lastMetadataSync[peer.deviceId] = DateTime.now();
        }
      } finally {
        _drainingPeers.remove(peer.deviceId);
      }
    }
  }

  Future<void> _drain(String peerId, {required bool includeSavedItems}) async {
    final allItems = await _clipboardRepository.getItems(limit: 5000);
    final allItemIds = allItems.map((it) => it.id).toList();
    await _syncStates.enqueueForPeer(peerId, allItemIds);

    final pending = await _syncStates.pendingForPeer(peerId);
    final wantedIds = pending.map((state) => state.itemId).toSet();
    final savedItemIds = <String>{};
    final byId = {for (final item in allItems) item.id: item};
    final settings = _readSettings();
    if (includeSavedItems) {
      for (final item in allItems) {
        final collectionIds = await _clipboardRepository.collectionIdsForItem(
          item.id,
        );
        if (item.isPinned ||
            (!settings.syncPinnedItemsOnly && collectionIds.isNotEmpty)) {
          savedItemIds.add(item.id);
          wantedIds.add(item.id);
        }
      }
    }
    for (final id in wantedIds) {
      final item = byId[id];
      if (item != null &&
          (_shouldSync(item, settings) || savedItemIds.contains(item.id))) {
        await _send(
          item,
          peerId,
          settings,
          writeToSystemClipboard: false,
          metadataAuthoritative: false,
        );
      }
    }
  }

  Future<bool> _sendCollections(String peerId) async {
    final settings = _readSettings();
    if (!_sharingEnabled(settings)) return false;
    final collections = (await _clipboardRepository.getCollections())
        .where((collection) => !collection.isVault)
        .toList(growable: false);
    var allSucceeded = true;
    for (final collection in collections) {
      try {
        await _transport.sendCollection(peerId, _collectionPayload(collection));
      } on Object {
        allSucceeded = false;
      }
    }
    return allSucceeded;
  }

  Future<void> _send(
    ClipboardItem item,
    String peerId,
    AppSettings settings, {
    required bool writeToSystemClipboard,
    required bool metadataAuthoritative,
  }) async {
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
      final collectionIds = await _clipboardRepository.collectionIdsForItem(
        item.id,
      );
      final allCollections = collectionIds.isEmpty
          ? const <ClipboardCollection>[]
          : await _clipboardRepository.getCollections();
      final collections = allCollections
          .where(
            (collection) =>
                !collection.isVault && collectionIds.contains(collection.id),
          )
          .map(_collectionPayload)
          .toList(growable: false);
      await _transport.sendClipboard(
        peerId,
        SharedClipboardPayload(
          messageId:
              '${item.id}:${DateTime.now().microsecondsSinceEpoch}:$peerId',
          sourceDeviceId: '',
          createdAt: DateTime.now(),
          text: item.content.isEmpty ? null : item.content,
          imageBytes: imageBytes,
          isPinned: item.isPinned,
          collections: collections,
          writeToSystemClipboard: writeToSystemClipboard,
          metadataAuthoritative: metadataAuthoritative,
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
    return _sharingEnabled(settings) &&
        (!settings.syncPinnedItemsOnly || item.isPinned);
  }

  bool _sharingEnabled(AppSettings settings) =>
      settings.localSharingEnabled &&
      !settings.allConnectionsPaused &&
      settings.autoSyncClipboard;

  SharedCollectionPayload _collectionPayload(
    ClipboardCollection collection, {
    bool deleted = false,
  }) {
    return SharedCollectionPayload(
      messageId:
          'collection:${collection.id}:${DateTime.now().microsecondsSinceEpoch}',
      sourceDeviceId: '',
      collectionId: collection.id,
      name: collection.name,
      icon: collection.icon,
      createdAt: collection.createdAt,
      updatedAt: collection.updatedAt,
      sortOrder: collection.sortOrder,
      deleted: deleted,
    );
  }
}
