abstract final class LocalSharingProtocol {
  static const serviceType = '_clipflow._tcp';
  static const protocolVersion = '1';
  static const pairingCodeLength = 6;
  static const pairingCodeLifetime = Duration(seconds: 60);
  static const maximumPairingAttempts = 5;
}
