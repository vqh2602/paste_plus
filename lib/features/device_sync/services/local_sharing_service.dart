import 'dart:async';

import '../../settings/domain/app_settings.dart';
import '../domain/local_sharing_state.dart';
import '../domain/shared_collection_payload.dart';
import '../domain/shared_clipboard_payload.dart';

abstract interface class LocalSharingService {
  Stream<LocalSharingState> get states;

  Stream<SharedClipboardPayload> get receivedPayloads;

  Stream<SharedCollectionPayload> get receivedCollections;

  Future<void> start(AppSettings settings);

  Future<void> updateConfiguration(AppSettings settings);

  Future<void> refresh();

  Future<void> requestPairing(String deviceId);

  Future<void> confirmPairing(String deviceId);

  Future<void> cancelPairing(String deviceId);

  Future<void> disconnect(String deviceId);

  Future<void> forget(String deviceId);

  Future<void> block(String deviceId);

  Future<void> unblock(String deviceId);

  Future<void> sendClipboard(String deviceId, SharedClipboardPayload payload);

  Future<void> sendCollection(String deviceId, SharedCollectionPayload payload);

  Future<void> dispose();
}

/// Safe default while the platform mDNS/TLS transport is not registered.
///
/// It exposes real service state to the presentation layer without fabricating
/// peers. A native transport can implement [LocalSharingService] and be
/// injected through the provider without changing the settings UI.
class PassiveLocalSharingService implements LocalSharingService {
  final _states = StreamController<LocalSharingState>.broadcast();
  final _receivedPayloads =
      StreamController<SharedClipboardPayload>.broadcast();
  final _receivedCollections =
      StreamController<SharedCollectionPayload>.broadcast();
  LocalSharingState _state = const LocalSharingState();
  AppSettings _settings = const AppSettings();

  @override
  Stream<LocalSharingState> get states => _states.stream;

  @override
  Stream<SharedClipboardPayload> get receivedPayloads =>
      _receivedPayloads.stream;

  @override
  Stream<SharedCollectionPayload> get receivedCollections =>
      _receivedCollections.stream;

  @override
  Future<void> start(AppSettings settings) async {
    _settings = settings;
    _emit(
      _state.copyWith(
        isDiscovering:
            settings.localSharingEnabled && !settings.allConnectionsPaused,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> updateConfiguration(AppSettings settings) async {
    _settings = settings;
    await start(settings);
  }

  @override
  Future<void> refresh() async {
    if (!_settings.localSharingEnabled || _settings.allConnectionsPaused) {
      return;
    }
    _emit(_state.copyWith(isDiscovering: true, clearError: true));
  }

  @override
  Future<void> requestPairing(String deviceId) async {}

  @override
  Future<void> confirmPairing(String deviceId) async {}

  @override
  Future<void> cancelPairing(String deviceId) async {}

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> forget(String deviceId) async {}

  @override
  Future<void> block(String deviceId) async {}

  @override
  Future<void> unblock(String deviceId) async {}

  @override
  Future<void> sendClipboard(
    String deviceId,
    SharedClipboardPayload payload,
  ) async {
    throw StateError('No active network transport');
  }

  @override
  Future<void> sendCollection(
    String deviceId,
    SharedCollectionPayload payload,
  ) async {
    throw StateError('No active network transport');
  }

  void _emit(LocalSharingState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _receivedPayloads.close();
    await _receivedCollections.close();
  }
}
