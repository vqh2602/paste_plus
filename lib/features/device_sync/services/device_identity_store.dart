import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStore implements SecretStore {
  const PlatformSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.identityPrivateKey,
    required this.identityPublicKey,
    required this.certificatePem,
    required this.privateKeyPem,
  });

  final String deviceId;
  final List<int> identityPrivateKey;
  final List<int> identityPublicKey;
  final String certificatePem;
  final String privateKeyPem;

  SimpleKeyPairData get signingKeyPair => SimpleKeyPairData(
    identityPrivateKey,
    publicKey: SimplePublicKey(identityPublicKey, type: KeyPairType.ed25519),
    type: KeyPairType.ed25519,
  );
}

class TrustedDeviceRecord {
  const TrustedDeviceRecord({
    required this.deviceId,
    required this.publicKey,
    required this.certificateFingerprint,
    required this.deviceName,
    required this.platform,
    this.blocked = false,
  });

  final String deviceId;
  final List<int> publicKey;
  final String certificateFingerprint;
  final String deviceName;
  final String platform;
  final bool blocked;

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'publicKey': base64Encode(publicKey),
    'certificateFingerprint': certificateFingerprint,
    'deviceName': deviceName,
    'platform': platform,
    'blocked': blocked,
  };

  factory TrustedDeviceRecord.fromJson(Map<String, Object?> json) {
    return TrustedDeviceRecord(
      deviceId: json['deviceId'] as String,
      publicKey: base64Decode(json['publicKey'] as String),
      certificateFingerprint: json['certificateFingerprint'] as String,
      deviceName: json['deviceName'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      blocked: json['blocked'] as bool? ?? false,
    );
  }

  TrustedDeviceRecord copyWith({bool? blocked}) => TrustedDeviceRecord(
    deviceId: deviceId,
    publicKey: publicKey,
    certificateFingerprint: certificateFingerprint,
    deviceName: deviceName,
    platform: platform,
    blocked: blocked ?? this.blocked,
  );
}

class DeviceIdentityStore {
  DeviceIdentityStore(this._store);

  static const _identityKey = 'clipflow.sharing.identity.v1';
  static const _trustedKey = 'clipflow.sharing.trusted.v1';
  final SecretStore _store;

  Future<DeviceIdentity> loadOrCreateIdentity() async {
    final stored = await _store.read(_identityKey);
    if (stored != null) {
      try {
        return _identityFromJson(
          (jsonDecode(stored) as Map).cast<String, Object?>(),
        );
      } on Object {
        await _store.delete(_identityKey);
      }
    }
    final signingKey = await Ed25519().newKeyPair();
    final privateBytes = await signingKey.extractPrivateKeyBytes();
    final publicKey = await signingKey.extractPublicKey();
    final tls = await Isolate.run(_generateTlsIdentity);
    final identity = DeviceIdentity(
      deviceId: _randomId(),
      identityPrivateKey: privateBytes,
      identityPublicKey: publicKey.bytes,
      certificatePem: tls.$1,
      privateKeyPem: tls.$2,
    );
    await _store.write(_identityKey, jsonEncode(_identityToJson(identity)));
    return identity;
  }

  Future<Map<String, TrustedDeviceRecord>> loadTrustedDevices() async {
    final stored = await _store.read(_trustedKey);
    if (stored == null) return {};
    try {
      final decoded = (jsonDecode(stored) as Map).cast<String, Object?>();
      return decoded.map(
        (id, value) => MapEntry(
          id,
          TrustedDeviceRecord.fromJson((value as Map).cast<String, Object?>()),
        ),
      );
    } on Object {
      return {};
    }
  }

  Future<void> saveTrustedDevices(Map<String, TrustedDeviceRecord> devices) {
    return _store.write(
      _trustedKey,
      jsonEncode(devices.map((id, value) => MapEntry(id, value.toJson()))),
    );
  }

  static String _randomId() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static (String, String) _generateTlsIdentity() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;
    const dn = {'CN': 'ClipFlow Local Device', 'O': 'ClipFlow'};
    final csr = X509Utils.generateRsaCsrPem(dn, privateKey, publicKey);
    final certificate = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      3650,
      extKeyUsage: [ExtendedKeyUsage.SERVER_AUTH, ExtendedKeyUsage.CLIENT_AUTH],
    );
    return (certificate, CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey));
  }

  static Map<String, Object?> _identityToJson(DeviceIdentity identity) => {
    'deviceId': identity.deviceId,
    'identityPrivateKey': base64Encode(identity.identityPrivateKey),
    'identityPublicKey': base64Encode(identity.identityPublicKey),
    'certificatePem': identity.certificatePem,
    'privateKeyPem': identity.privateKeyPem,
  };

  static DeviceIdentity _identityFromJson(Map<String, Object?> json) {
    return DeviceIdentity(
      deviceId: json['deviceId'] as String,
      identityPrivateKey: base64Decode(json['identityPrivateKey'] as String),
      identityPublicKey: base64Decode(json['identityPublicKey'] as String),
      certificatePem: json['certificatePem'] as String,
      privateKeyPem: json['privateKeyPem'] as String,
    );
  }
}
