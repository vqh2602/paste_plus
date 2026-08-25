import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:local_auth/local_auth.dart';

import '../../device_sync/services/device_identity_store.dart';

abstract interface class VaultDeviceAuthenticator {
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

class PlatformVaultDeviceAuthenticator implements VaultDeviceAuthenticator {
  PlatformVaultDeviceAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _authentication.isDeviceSupported();
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}

class VaultCrypto {
  VaultCrypto({
    required SecretStore secretStore,
    required VaultDeviceAuthenticator deviceAuthenticator,
  }) : _secretStore = secretStore,
       _deviceAuthenticator = deviceAuthenticator;

  static const encryptedPrefix = 'clipflow-vault:v1:';
  static const _configKey = 'clipflow.vault.config.v1';
  static const _deviceKey = 'clipflow.vault.device-key.v1';
  static const _iterations = 210000;

  final SecretStore _secretStore;
  final VaultDeviceAuthenticator _deviceAuthenticator;
  final Cipher _cipher = AesGcm.with256bits();
  _VaultConfig? _config;
  SecretKey? _masterKey;

  bool get isConfigured => _config != null;
  bool get isUnlocked => _masterKey != null;
  bool get deviceUnlockEnabled => _config?.deviceUnlockEnabled ?? false;
  int get failedAttempts => _config?.failedAttempts ?? 0;

  Future<void> initialize() async {
    final source = await _secretStore.read(_configKey);
    if (source == null) return;
    try {
      _config = _VaultConfig.fromJson(
        (jsonDecode(source) as Map).cast<String, Object?>(),
      );
    } on Object {
      _config = null;
    }
  }

  Future<bool> deviceAuthenticationAvailable() {
    return _deviceAuthenticator.isAvailable();
  }

  Future<void> enable(String password) async {
    if (password.length < 6) {
      throw ArgumentError.value(password, 'password', 'Minimum 6 characters.');
    }
    final masterKey = await _cipher.newSecretKey();
    final salt = _cipher.newNonce();
    final wrappingKey = await _deriveWrappingKey(password, salt);
    final masterBytes = await masterKey.extractBytes();
    final wrappedKey = await _cipher.encrypt(
      masterBytes,
      secretKey: wrappingKey,
      aad: utf8.encode(_configKey),
    );
    final config = _VaultConfig(
      salt: salt,
      wrappedKey: wrappedKey,
      failedAttempts: 0,
      deviceUnlockEnabled: false,
    );
    // Commit secure storage before changing in-memory state. A stale device
    // key is harmless while deviceUnlockEnabled is false and will be
    // overwritten if device authentication is enabled later. Avoiding an
    // unnecessary delete also keeps non-provisioned macOS builds on the
    // supported login-Keychain path.
    await _secretStore.write(_configKey, jsonEncode(config.toJson()));
    _masterKey = masterKey;
    _config = config;
  }

  Future<bool> unlockWithPassword(String password) async {
    final config = _config;
    if (config == null) return false;
    try {
      final wrappingKey = await _deriveWrappingKey(password, config.salt);
      final masterBytes = await _cipher.decrypt(
        config.wrappedKey,
        secretKey: wrappingKey,
        aad: utf8.encode(_configKey),
      );
      _masterKey = SecretKey(masterBytes);
      if (config.failedAttempts != 0) {
        _config = config.copyWith(failedAttempts: 0);
        await _persistConfig();
      }
      return true;
    } on Object {
      _config = config.copyWith(failedAttempts: config.failedAttempts + 1);
      await _persistConfig();
      return false;
    }
  }

  Future<bool> unlockWithDevice(String reason) async {
    final config = _config;
    if (config == null || !config.deviceUnlockEnabled) return false;
    if (!await _deviceAuthenticator.authenticate(reason)) return false;
    final encodedKey = await _secretStore.read(_deviceKey);
    if (encodedKey == null) return false;
    try {
      _masterKey = SecretKey(base64Decode(encodedKey));
      if (config.failedAttempts != 0) {
        _config = config.copyWith(failedAttempts: 0);
        await _persistConfig();
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> setDeviceUnlock(bool enabled, String reason) async {
    final config = _config;
    if (config == null) return false;
    if (!enabled) {
      await _secretStore.delete(_deviceKey);
      _config = config.copyWith(deviceUnlockEnabled: false);
      await _persistConfig();
      return true;
    }
    final key = _requireKey();
    if (!await _deviceAuthenticator.isAvailable() ||
        !await _deviceAuthenticator.authenticate(reason)) {
      return false;
    }
    await _secretStore.write(
      _deviceKey,
      base64Encode(await key.extractBytes()),
    );
    _config = config.copyWith(deviceUnlockEnabled: true);
    await _persistConfig();
    return true;
  }

  Future<void> changePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw ArgumentError.value(
        newPassword,
        'newPassword',
        'Minimum 6 characters.',
      );
    }
    final config = _config;
    if (config == null) throw StateError('Vault is not configured.');
    final key = _requireKey();
    final salt = _cipher.newNonce();
    final wrappingKey = await _deriveWrappingKey(newPassword, salt);
    final wrappedKey = await _cipher.encrypt(
      await key.extractBytes(),
      secretKey: wrappingKey,
      aad: utf8.encode(_configKey),
    );
    _config = config.copyWith(
      salt: salt,
      wrappedKey: wrappedKey,
      failedAttempts: 0,
    );
    await _persistConfig();
  }

  Future<void> resetFailedAttempts() async {
    final config = _config;
    if (config == null || config.failedAttempts == 0) return;
    _config = config.copyWith(failedAttempts: 0);
    await _persistConfig();
  }

  Future<void> disable() async {
    lock();
    _config = null;
    await _secretStore.delete(_configKey);
    await _secretStore.delete(_deviceKey);
  }

  void lock() {
    _masterKey = null;
  }

  Future<String> encryptString(String value) async {
    final box = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: _requireKey(),
    );
    return '$encryptedPrefix${base64Encode(utf8.encode(jsonEncode(_boxToJson(box))))}';
  }

  Future<String> decryptString(String value) async {
    if (!value.startsWith(encryptedPrefix)) return value;
    final encoded = value.substring(encryptedPrefix.length);
    final json = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
    final bytes = await _cipher.decrypt(
      _boxFromJson(json.cast<String, Object?>()),
      secretKey: _requireKey(),
    );
    return utf8.decode(bytes);
  }

  Future<Uint8List> encryptBytes(List<int> bytes) async {
    final box = await _cipher.encrypt(bytes, secretKey: _requireKey());
    return Uint8List.fromList(utf8.encode(jsonEncode(_boxToJson(box))));
  }

  Future<Uint8List> decryptBytes(List<int> bytes) async {
    final json = jsonDecode(utf8.decode(bytes)) as Map;
    final clear = await _cipher.decrypt(
      _boxFromJson(json.cast<String, Object?>()),
      secretKey: _requireKey(),
    );
    return Uint8List.fromList(clear);
  }

  Future<SecretKey> _deriveWrappingKey(String password, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }

  SecretKey _requireKey() {
    final key = _masterKey;
    if (key == null) throw const VaultLockedException();
    return key;
  }

  Future<void> _persistConfig() async {
    final config = _config;
    if (config == null) return;
    await _secretStore.write(_configKey, jsonEncode(config.toJson()));
  }
}

class VaultLockedException implements Exception {
  const VaultLockedException();

  @override
  String toString() => 'VaultLockedException';
}

class _VaultConfig {
  const _VaultConfig({
    required this.salt,
    required this.wrappedKey,
    required this.failedAttempts,
    required this.deviceUnlockEnabled,
  });

  final List<int> salt;
  final SecretBox wrappedKey;
  final int failedAttempts;
  final bool deviceUnlockEnabled;

  _VaultConfig copyWith({
    List<int>? salt,
    SecretBox? wrappedKey,
    int? failedAttempts,
    bool? deviceUnlockEnabled,
  }) {
    return _VaultConfig(
      salt: salt ?? this.salt,
      wrappedKey: wrappedKey ?? this.wrappedKey,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      deviceUnlockEnabled: deviceUnlockEnabled ?? this.deviceUnlockEnabled,
    );
  }

  Map<String, Object?> toJson() => {
    'salt': base64Encode(salt),
    'wrappedKey': _boxToJson(wrappedKey),
    'failedAttempts': failedAttempts,
    'deviceUnlockEnabled': deviceUnlockEnabled,
  };

  factory _VaultConfig.fromJson(Map<String, Object?> json) {
    return _VaultConfig(
      salt: base64Decode(json['salt']! as String),
      wrappedKey: _boxFromJson(
        (json['wrappedKey']! as Map).cast<String, Object?>(),
      ),
      failedAttempts: json['failedAttempts'] as int? ?? 0,
      deviceUnlockEnabled: json['deviceUnlockEnabled'] as bool? ?? false,
    );
  }
}

Map<String, Object?> _boxToJson(SecretBox box) => {
  'cipherText': base64Encode(box.cipherText),
  'nonce': base64Encode(box.nonce),
  'mac': base64Encode(box.mac.bytes),
};

SecretBox _boxFromJson(Map<String, Object?> json) => SecretBox(
  base64Decode(json['cipherText']! as String),
  nonce: base64Decode(json['nonce']! as String),
  mac: Mac(base64Decode(json['mac']! as String)),
);
