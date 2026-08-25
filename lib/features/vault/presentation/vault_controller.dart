import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../clipboard_history/domain/clipboard_repository.dart';
import '../services/vault_crypto.dart';

enum VaultUnlockResult { success, invalidPassword, unavailable, wiped, error }

class VaultState {
  const VaultState({
    this.initialized = false,
    this.configured = false,
    this.unlocked = false,
    this.deviceAuthenticationAvailable = false,
    this.deviceUnlockEnabled = false,
    this.deviceAuthenticationInProgress = false,
    this.failedAttempts = 0,
  });

  final bool initialized;
  final bool configured;
  final bool unlocked;
  final bool deviceAuthenticationAvailable;
  final bool deviceUnlockEnabled;
  final bool deviceAuthenticationInProgress;
  final int failedAttempts;

  VaultState copyWith({
    bool? initialized,
    bool? configured,
    bool? unlocked,
    bool? deviceAuthenticationAvailable,
    bool? deviceUnlockEnabled,
    bool? deviceAuthenticationInProgress,
    int? failedAttempts,
  }) {
    return VaultState(
      initialized: initialized ?? this.initialized,
      configured: configured ?? this.configured,
      unlocked: unlocked ?? this.unlocked,
      deviceAuthenticationAvailable:
          deviceAuthenticationAvailable ?? this.deviceAuthenticationAvailable,
      deviceUnlockEnabled: deviceUnlockEnabled ?? this.deviceUnlockEnabled,
      deviceAuthenticationInProgress:
          deviceAuthenticationInProgress ?? this.deviceAuthenticationInProgress,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}

class VaultController extends StateNotifier<VaultState> {
  VaultController(this._crypto, this._repository) : super(const VaultState()) {
    unawaited(initialize());
  }

  final VaultCrypto _crypto;
  final ClipboardRepository _repository;
  Timer? _deviceAuthenticationTransitionTimer;

  void _beginDeviceAuthentication() {
    _deviceAuthenticationTransitionTimer?.cancel();
    state = state.copyWith(deviceAuthenticationInProgress: true);
  }

  void _finishDeviceAuthenticationAfterSystemTransition() {
    _deviceAuthenticationTransitionTimer?.cancel();
    _deviceAuthenticationTransitionTimer = Timer(
      const Duration(milliseconds: 900),
      () {
        if (mounted) {
          state = state.copyWith(deviceAuthenticationInProgress: false);
        }
      },
    );
  }

  Future<void> initialize() async {
    try {
      await _crypto.initialize();
      final deviceAvailable = await _crypto.deviceAuthenticationAvailable();
      state = VaultState(
        initialized: true,
        configured: _crypto.isConfigured,
        unlocked: _crypto.isUnlocked,
        deviceAuthenticationAvailable: deviceAvailable,
        deviceUnlockEnabled: _crypto.deviceUnlockEnabled,
        failedAttempts: _crypto.failedAttempts,
      );
    } on Object {
      state = const VaultState(initialized: true);
    }
  }

  Future<void> enable(String password) async {
    await _crypto.enable(password);
    state = state.copyWith(
      initialized: true,
      configured: true,
      unlocked: true,
      deviceUnlockEnabled: false,
      failedAttempts: 0,
    );
  }

  Future<VaultUnlockResult> unlockWithPassword(
    String password, {
    required bool wipeAfterFiveFailures,
  }) async {
    try {
      final success = await _crypto.unlockWithPassword(password);
      if (success) {
        state = state.copyWith(unlocked: true, failedAttempts: 0);
        return VaultUnlockResult.success;
      }
      final attempts = _crypto.failedAttempts;
      state = state.copyWith(unlocked: false, failedAttempts: attempts);
      if (wipeAfterFiveFailures && attempts >= 5) {
        final repository = _repository;
        if (repository is VaultClipboardRepository) {
          await (repository as VaultClipboardRepository).clearVault();
        }
        await _crypto.resetFailedAttempts();
        state = state.copyWith(failedAttempts: 0);
        return VaultUnlockResult.wiped;
      }
      return VaultUnlockResult.invalidPassword;
    } on Object {
      return VaultUnlockResult.error;
    }
  }

  Future<VaultUnlockResult> unlockWithDevice(String reason) async {
    if (!state.deviceAuthenticationAvailable || !state.deviceUnlockEnabled) {
      return VaultUnlockResult.unavailable;
    }
    _beginDeviceAuthentication();
    try {
      final success = await _crypto.unlockWithDevice(reason);
      if (!success) return VaultUnlockResult.unavailable;
      state = state.copyWith(unlocked: true, failedAttempts: 0);
      return VaultUnlockResult.success;
    } on Object {
      return VaultUnlockResult.error;
    } finally {
      _finishDeviceAuthenticationAfterSystemTransition();
    }
  }

  Future<bool> setDeviceUnlock(bool enabled, String reason) async {
    if (enabled) _beginDeviceAuthentication();
    try {
      final updated = await _crypto.setDeviceUnlock(enabled, reason);
      if (updated) state = state.copyWith(deviceUnlockEnabled: enabled);
      return updated;
    } on Object {
      return false;
    } finally {
      if (enabled) _finishDeviceAuthenticationAfterSystemTransition();
    }
  }

  Future<void> changePassword(String newPassword) async {
    await _crypto.changePassword(newPassword);
    state = state.copyWith(failedAttempts: 0);
  }

  Future<void> disable() async {
    final repository = _repository;
    if (repository is VaultClipboardRepository) {
      await (repository as VaultClipboardRepository).disableVault();
    }
    await _crypto.disable();
    state = state.copyWith(
      configured: false,
      unlocked: false,
      deviceUnlockEnabled: false,
      failedAttempts: 0,
    );
  }

  void lock() {
    _crypto.lock();
    final repository = _repository;
    if (repository is VaultClipboardRepository) {
      unawaited((repository as VaultClipboardRepository).clearVaultPreviews());
    }
    if (state.unlocked) state = state.copyWith(unlocked: false);
  }

  @override
  void dispose() {
    _deviceAuthenticationTransitionTimer?.cancel();
    super.dispose();
  }
}
