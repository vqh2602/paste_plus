import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../settings/domain/app_settings.dart';
import '../domain/local_sharing_state.dart';
import '../services/local_sharing_service.dart';

class LocalSharingController extends StateNotifier<LocalSharingState> {
  LocalSharingController(this._service, AppSettings settings)
    : super(const LocalSharingState()) {
    _subscription = _service.states.listen(
      (next) => state = next,
      onError: (_) => state = state.copyWith(errorKey: 'sharing_service_error'),
    );
    unawaited(_run(() => _service.start(settings)));
  }

  final LocalSharingService _service;
  late final StreamSubscription<LocalSharingState> _subscription;

  Future<void> updateConfiguration(AppSettings settings) =>
      _run(() => _service.updateConfiguration(settings));

  Future<void> refresh() => _run(_service.refresh);

  Future<void> requestPairing(String deviceId) =>
      _run(() => _service.requestPairing(deviceId));

  Future<void> confirmPairing(String deviceId) =>
      _run(() => _service.confirmPairing(deviceId));

  Future<void> cancelPairing(String deviceId) =>
      _run(() => _service.cancelPairing(deviceId));

  Future<void> disconnect(String deviceId) =>
      _run(() => _service.disconnect(deviceId));

  Future<void> forget(String deviceId) => _run(() => _service.forget(deviceId));

  Future<void> block(String deviceId) => _run(() => _service.block(deviceId));

  Future<void> unblock(String deviceId) =>
      _run(() => _service.unblock(deviceId));

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object {
      state = state.copyWith(errorKey: 'sharing_service_error');
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
