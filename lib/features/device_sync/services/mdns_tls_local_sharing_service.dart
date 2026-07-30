import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bonsoir/bonsoir.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

import '../../settings/domain/app_settings.dart';
import '../domain/local_sharing_protocol.dart';
import '../domain/local_sharing_state.dart';
import '../domain/peer_connection_info.dart';
import '../domain/shared_clipboard_payload.dart';
import 'device_identity_store.dart';
import 'framed_secure_socket.dart';
import 'local_sharing_service.dart';

class MdnsTlsLocalSharingService implements LocalSharingService {
  MdnsTlsLocalSharingService({
    DeviceIdentityStore? identityStore,
    this.enableMdns = true,
    this.appVersion = '1.0.9',
    this.platformOverride,
  }) : _identityStore =
           identityStore ?? DeviceIdentityStore(const PlatformSecretStore());

  final DeviceIdentityStore _identityStore;
  final bool enableMdns;
  final String appVersion;
  final String? platformOverride;
  final _states = StreamController<LocalSharingState>.broadcast();
  final _receivedPayloads =
      StreamController<SharedClipboardPayload>.broadcast();
  final _discovered = <String, PeerConnectionInfo>{};
  final _connections = <String, _PeerConnection>{};
  final _pairings = <String, _PendingPairing>{};
  final _seenMessageIds = <String, DateTime>{};
  Map<String, TrustedDeviceRecord> _trusted = {};
  AppSettings _settings = const AppSettings();
  DeviceIdentity? _identity;
  SecureServerSocket? _server;
  StreamSubscription<SecureSocket>? _serverSubscription;
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySubscription;
  Future<void>? _starting;
  bool _disposed = false;

  @override
  Stream<LocalSharingState> get states => _states.stream;

  @override
  Stream<SharedClipboardPayload> get receivedPayloads =>
      _receivedPayloads.stream;

  int? get listeningPort => _server?.port;
  String? get deviceId => _identity?.deviceId;

  @override
  Future<void> start(AppSettings settings) async {
    _settings = settings;
    if (!settings.localSharingEnabled || settings.allConnectionsPaused) {
      await _stopNetwork();
      _emit();
      return;
    }
    if (_server != null) {
      _emit();
      return;
    }
    final running = _starting;
    if (running != null) return running;
    final future = _startNetwork();
    _starting = future;
    try {
      await future;
    } finally {
      _starting = null;
    }
  }

  Future<void> _startNetwork() async {
    try {
      final identity = await _identityStore.loadOrCreateIdentity();
      _identity = identity;
      _trusted = await _identityStore.loadTrustedDevices();
      final context = SecurityContext(withTrustedRoots: false)
        ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
        ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem));
      _server = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        0,
        context,
        requestClientCertificate: false,
        requireClientCertificate: false,
      );
      _serverSubscription = _server!.listen(
        (socket) => unawaited(_handleSocket(socket, outgoing: false)),
        onError: (_) => _emit(errorKey: 'sharing_service_error'),
      );
      if (enableMdns) await _startMdns();
      _emit();
    } on Object {
      await _stopNetworkAfterFailedStart();
      rethrow;
    }
  }

  Future<void> _stopNetworkAfterFailedStart() async {
    try {
      await _stopNetwork();
    } on Object {
      // Preserve the startup exception; every resource is independently
      // replaced when the next start attempt runs.
      _server = null;
      _serverSubscription = null;
      _broadcast = null;
      _discovery = null;
      _discoverySubscription = null;
    }
  }

  Future<void> _startMdns() async {
    final identity = _identity!;
    final service = BonsoirService(
      name: _displayName,
      type: LocalSharingProtocol.serviceType,
      port: _server!.port,
      attributes: {
        'id': identity.deviceId,
        'platform': _platform,
        'version': appVersion,
        'proto': LocalSharingProtocol.protocolVersion,
      },
    );
    if (_settings.deviceDiscoverable) {
      _broadcast = BonsoirBroadcast(service: service, printLogs: false);
      await _broadcast!.initialize();
      await _broadcast!.start();
    }
    _discovery = BonsoirDiscovery(
      type: LocalSharingProtocol.serviceType,
      printLogs: false,
    );
    await _discovery!.initialize();
    _discoverySubscription = _discovery!.eventStream!.listen(_onDiscovery);
    await _discovery!.start();
  }

  void _onDiscovery(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        unawaited(event.service.resolve(_discovery!.serviceResolver));
      case BonsoirDiscoveryServiceResolvedEvent():
        _recordDiscovered(event.service);
      case BonsoirDiscoveryServiceUpdatedEvent():
        _recordDiscovered(event.service);
      case BonsoirDiscoveryServiceLostEvent():
        final id = event.service.attributes['id'];
        if (id != null) _markLost(id);
      default:
        break;
    }
  }

  void _recordDiscovered(BonsoirService service) {
    final id = service.attributes['id'];
    if (id == null ||
        id == _identity?.deviceId ||
        service.hostAddresses.isEmpty) {
      return;
    }
    final trusted = _trusted[id];
    final address = service.hostAddresses.firstWhere(
      (value) =>
          InternetAddress.tryParse(value)?.type == InternetAddressType.IPv4,
      orElse: () => service.hostAddresses.first,
    );
    final current = _connections[id];
    _discovered[id] = PeerConnectionInfo(
      deviceId: id,
      deviceName: service.name,
      platform: service.attributes['platform'] ?? 'Unknown',
      ipAddress: address,
      port: service.port,
      status: trusted?.blocked == true
          ? PeerConnectionStatus.blocked
          : current != null
          ? PeerConnectionStatus.connected
          : PeerConnectionStatus.discovered,
      quality: current?.quality ?? ConnectionQuality.good,
      latencyMs: current?.latencyMs,
      lastSeenAt: DateTime.now(),
      lastSyncedAt: current?.lastSyncedAt,
      pendingItems: 0,
      isTrusted: trusted != null && !trusted.blocked,
      isBlocked: trusted?.blocked ?? false,
      appVersion: service.attributes['version'] ?? '',
      protocolVersion: service.attributes['proto'] ?? '',
    );
    _emit();
    if (trusted != null &&
        !trusted.blocked &&
        _settings.autoConnectTrustedDevices &&
        _identity!.deviceId.compareTo(id) < 0 &&
        !_connections.containsKey(id) &&
        !_pairings.containsKey(id)) {
      unawaited(_connect(_discovered[id]!));
    }
  }

  void _markLost(String id) {
    final peer = _discovered[id];
    if (peer == null || _connections.containsKey(id)) return;
    if (peer.isTrusted || peer.isBlocked) {
      _discovered[id] = peer.copyWith(
        status: peer.isBlocked
            ? PeerConnectionStatus.blocked
            : PeerConnectionStatus.disconnected,
        quality: ConnectionQuality.offline,
        lastSeenAt: DateTime.now(),
      );
    } else {
      _discovered.remove(id);
    }
    _emit();
  }

  Future<void> connectDirect({
    required String address,
    required int port,
    required String expectedDeviceId,
    String deviceName = 'ClipFlow Device',
    String platform = 'test',
  }) async {
    final peer = PeerConnectionInfo(
      deviceId: expectedDeviceId,
      deviceName: deviceName,
      platform: platform,
      ipAddress: address,
      port: port,
      status: PeerConnectionStatus.discovered,
      quality: ConnectionQuality.good,
      pendingItems: 0,
      isTrusted: _trusted.containsKey(expectedDeviceId),
      isBlocked: _trusted[expectedDeviceId]?.blocked ?? false,
      protocolVersion: LocalSharingProtocol.protocolVersion,
    );
    _discovered[expectedDeviceId] = peer;
    _emit();
    await _connect(peer);
  }

  @override
  Future<void> requestPairing(String deviceId) async {
    final peer = _discovered[deviceId];
    if (peer == null || peer.isBlocked) return;
    await _connect(peer);
  }

  Future<void> _connect(PeerConnectionInfo peer) async {
    if (_connections.containsKey(peer.deviceId) ||
        _pairings.containsKey(peer.deviceId)) {
      return;
    }
    _setPeerStatus(peer.deviceId, PeerConnectionStatus.connecting);
    try {
      final expectedFingerprint =
          _trusted[peer.deviceId]?.certificateFingerprint;
      final context = SecurityContext(withTrustedRoots: false);
      final socket = await SecureSocket.connect(
        peer.ipAddress,
        peer.port,
        context: context,
        timeout: const Duration(seconds: 8),
        onBadCertificate: (certificate) {
          if (expectedFingerprint == null || expectedFingerprint.isEmpty) {
            return true;
          }
          return _certificateFingerprint(certificate) == expectedFingerprint;
        },
      );
      await _handleSocket(
        socket,
        outgoing: true,
        expectedDeviceId: peer.deviceId,
      );
    } on Object {
      _setPeerStatus(peer.deviceId, PeerConnectionStatus.disconnected);
    }
  }

  Future<void> _handleSocket(
    SecureSocket socket, {
    required bool outgoing,
    String? expectedDeviceId,
  }) async {
    final maximumImageBytes = _settings.sharingMaxImageMb * 1024 * 1024;
    final maximumFrameBytes = ((maximumImageBytes * 4 / 3).ceil() + 1024 * 1024)
        .clamp(1024 * 1024, 140 * 1024 * 1024);
    final channel = FramedSecureSocket(
      socket,
      maximumFrameBytes: maximumFrameBytes,
    );
    String? remoteId;
    try {
      final identity = _identity!;
      final ephemeral = await X25519().newKeyPair();
      final ephemeralPublic = await ephemeral.extractPublicKey();
      final nonce = _randomBytes(24);
      final localHello = <String, Object?>{
        'type': 'hello',
        'deviceId': identity.deviceId,
        'deviceName': _displayName,
        'platform': _platform,
        'appVersion': appVersion,
        'protocolVersion': LocalSharingProtocol.protocolVersion,
        'identityKey': base64Encode(identity.identityPublicKey),
        'ephemeralKey': base64Encode(ephemeralPublic.bytes),
        'nonce': base64Encode(nonce),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      channel.writeJson(localHello);
      await channel.flush();
      final remoteHello = await channel.readJson().timeout(
        const Duration(seconds: 8),
      );
      if (remoteHello['type'] != 'hello') throw const FormatException('hello');
      remoteId = remoteHello['deviceId'] as String;
      if (remoteId == identity.deviceId ||
          (expectedDeviceId != null && expectedDeviceId != remoteId)) {
        throw const FormatException('Unexpected peer');
      }
      if (remoteHello['protocolVersion'] !=
          LocalSharingProtocol.protocolVersion) {
        _setPeerStatus(remoteId, PeerConnectionStatus.incompatible);
        throw const FormatException('Protocol mismatch');
      }
      final timestamp = remoteHello['timestamp'] as int;
      if ((DateTime.now().millisecondsSinceEpoch - timestamp).abs() > 120000) {
        throw const FormatException('Stale hello');
      }
      final remoteIdentityKey = base64Decode(
        remoteHello['identityKey'] as String,
      );
      final remoteEphemeral = SimplePublicKey(
        base64Decode(remoteHello['ephemeralKey'] as String),
        type: KeyPairType.x25519,
      );
      final shared = await X25519().sharedSecretKey(
        keyPair: ephemeral,
        remotePublicKey: remoteEphemeral,
      );
      final sharedBytes = await shared.extractBytes();
      final transcript = _transcript(localHello, remoteHello);
      final trusted = _trusted[remoteId];
      if (trusted?.blocked == true) {
        channel.writeJson({'type': 'rejected'});
        throw const FormatException('Blocked peer');
      }
      final sameIdentity =
          trusted != null &&
          _constantTimeEquals(trusted.publicKey, remoteIdentityKey);
      if (trusted != null && !sameIdentity) {
        _setPeerStatus(remoteId, PeerConnectionStatus.rejected);
        channel.writeJson({'type': 'rejected'});
        throw const FormatException('Trusted identity key changed');
      }
      final authenticated = sameIdentity
          ? await _authenticate(
              channel,
              transcript,
              remoteIdentityKey,
              messageType: 'auth',
            )
          : await _pair(
              channel: channel,
              remoteId: remoteId,
              remoteHello: remoteHello,
              remoteIdentityKey: remoteIdentityKey,
              transcript: transcript,
              sharedSecret: sharedBytes,
              certificateFingerprint: outgoing
                  ? _certificateFingerprint(socket.peerCertificate!)
                  : '',
            );
      if (!authenticated) throw const FormatException('Authentication failed');
      final peer = _peerFromHello(remoteHello, socket, trusted: true);
      final connection = _PeerConnection(
        peer: peer,
        channel: channel,
        onMessage: (message) => _handleMessage(remoteId!, message),
        onClosed: () => _connectionClosed(remoteId!),
      );
      _connections[remoteId] = connection;
      _discovered[remoteId] = peer;
      _pairings.remove(remoteId);
      _emit();
      connection.start();
    } on Object {
      if (remoteId != null) _pairings.remove(remoteId);
      await channel.close();
      if (remoteId != null && !_connections.containsKey(remoteId)) {
        _setPeerStatus(remoteId, PeerConnectionStatus.disconnected);
      }
    }
  }

  Future<bool> _authenticate(
    FramedSecureSocket channel,
    List<int> transcript,
    List<int> remoteIdentityKey, {
    required String messageType,
  }) async {
    final signature = await Ed25519().sign(
      transcript,
      keyPair: _identity!.signingKeyPair,
    );
    channel.writeJson({
      'type': messageType,
      'signature': base64Encode(signature.bytes),
    });
    await channel.flush();
    final remote = await channel.readJson().timeout(const Duration(seconds: 8));
    if (remote['type'] != messageType) return false;
    return Ed25519().verify(
      transcript,
      signature: Signature(
        base64Decode(remote['signature'] as String),
        publicKey: SimplePublicKey(
          remoteIdentityKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
  }

  Future<bool> _pair({
    required FramedSecureSocket channel,
    required String remoteId,
    required Map<String, Object?> remoteHello,
    required List<int> remoteIdentityKey,
    required List<int> transcript,
    required List<int> sharedSecret,
    required String certificateFingerprint,
  }) async {
    final digest = crypto.sha256.convert([
      ...sharedSecret,
      ...transcript,
    ]).bytes;
    final numeric =
        ByteData.sublistView(
          Uint8List.fromList(digest),
        ).getUint32(0, Endian.big) %
        1000000;
    final code = numeric.toString().padLeft(6, '0');
    final peer = _peerFromHello(
      remoteHello,
      channel.socket,
      trusted: false,
    ).copyWith(status: PeerConnectionStatus.pairing);
    final pending = _PendingPairing(
      peer: peer,
      code: code,
      expiresAt: DateTime.now().add(LocalSharingProtocol.pairingCodeLifetime),
    );
    _pairings[remoteId] = pending;
    _discovered[remoteId] = peer;
    _emit();

    final remoteFrame = channel.readJson().timeout(
      LocalSharingProtocol.pairingCodeLifetime,
    );
    final first = await Future.any<Object>([
      pending.decision.future,
      remoteFrame,
    ]);
    Map<String, Object?>? remoteConfirmation;
    if (first is Map<String, Object?>) {
      if (first['type'] == 'pair_cancel') return false;
      remoteConfirmation = first;
    }
    final accepted = await pending.decision.future.timeout(
      LocalSharingProtocol.pairingCodeLifetime,
      onTimeout: () => false,
    );
    if (!accepted) {
      channel.writeJson({'type': 'pair_cancel'});
      return false;
    }
    final localSignature = await Ed25519().sign(
      transcript,
      keyPair: _identity!.signingKeyPair,
    );
    channel.writeJson({
      'type': 'pair_confirm',
      'signature': base64Encode(localSignature.bytes),
    });
    await channel.flush();
    remoteConfirmation ??= await remoteFrame;
    if (remoteConfirmation['type'] != 'pair_confirm') return false;
    final valid = await Ed25519().verify(
      transcript,
      signature: Signature(
        base64Decode(remoteConfirmation['signature'] as String),
        publicKey: SimplePublicKey(
          remoteIdentityKey,
          type: KeyPairType.ed25519,
        ),
      ),
    );
    if (!valid) return false;
    _trusted[remoteId] = TrustedDeviceRecord(
      deviceId: remoteId,
      publicKey: remoteIdentityKey,
      certificateFingerprint: certificateFingerprint,
      deviceName: peer.deviceName,
      platform: peer.platform,
    );
    await _identityStore.saveTrustedDevices(_trusted);
    return true;
  }

  PeerConnectionInfo _peerFromHello(
    Map<String, Object?> hello,
    SecureSocket socket, {
    required bool trusted,
  }) {
    final id = hello['deviceId'] as String;
    final existing = _discovered[id];
    return PeerConnectionInfo(
      deviceId: id,
      deviceName: hello['deviceName'] as String,
      platform: hello['platform'] as String,
      ipAddress: socket.remoteAddress.address,
      port: existing?.port ?? socket.remotePort,
      status: trusted
          ? PeerConnectionStatus.connected
          : PeerConnectionStatus.pairing,
      quality: ConnectionQuality.excellent,
      latencyMs: existing?.latencyMs,
      lastSeenAt: DateTime.now(),
      lastSyncedAt: existing?.lastSyncedAt,
      pendingItems: existing?.pendingItems ?? 0,
      isTrusted: trusted,
      isBlocked: false,
      appVersion: hello['appVersion'] as String? ?? '',
      protocolVersion: hello['protocolVersion'] as String? ?? '',
    );
  }

  Future<void> _handleMessage(
    String remoteId,
    Map<String, Object?> message,
  ) async {
    switch (message['type']) {
      case 'clipboard':
        final messageId = message['messageId'] as String;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          message['timestamp'] as int,
        );
        if ((DateTime.now().difference(timestamp).inMinutes).abs() > 5 ||
            _seenMessageIds.containsKey(messageId)) {
          return;
        }
        _seenMessageIds[messageId] = DateTime.now();
        _pruneSeenMessages();
        final imageValue = message['image'] as String?;
        final maximumImageBytes = _settings.sharingMaxImageMb * 1024 * 1024;
        final maximumEncodedImageLength =
            (maximumImageBytes * 4 / 3).ceil() + 4;
        final text = message['text'] as String?;
        if ((text != null && text.length > _settings.maxTextLength) ||
            (imageValue != null &&
                imageValue.length > maximumEncodedImageLength)) {
          _connections[remoteId]?.send({
            'type': 'ack',
            'messageId': messageId,
            'ok': false,
          });
          return;
        }
        final image = imageValue == null ? null : base64Decode(imageValue);
        if (image != null &&
            (!_settings.allowReceivingImages ||
                image.length > _settings.sharingMaxImageMb * 1024 * 1024)) {
          _connections[remoteId]?.send({
            'type': 'ack',
            'messageId': messageId,
            'ok': false,
          });
          return;
        }
        _receivedPayloads.add(
          SharedClipboardPayload(
            messageId: messageId,
            sourceDeviceId: remoteId,
            createdAt: timestamp,
            text: text,
            imageBytes: image == null ? null : Uint8List.fromList(image),
          ),
        );
        _connections[remoteId]?.send({
          'type': 'ack',
          'messageId': messageId,
          'ok': true,
        });
        final peer = _discovered[remoteId];
        if (peer != null) {
          _discovered[remoteId] = peer.copyWith(lastSyncedAt: DateTime.now());
          _emit();
        }
      case 'ack':
        _connections[remoteId]?.completeAck(
          message['messageId'] as String,
          message['ok'] as bool? ?? false,
        );
      case 'ping':
        _connections[remoteId]?.send({
          'type': 'pong',
          'id': message['id'],
          'timestamp': message['timestamp'],
        });
      case 'pong':
        final sentAt = message['timestamp'] as int;
        final latency = DateTime.now().millisecondsSinceEpoch - sentAt;
        _connections[remoteId]?.recordLatency(latency);
        final peer = _discovered[remoteId];
        if (peer != null) {
          _discovered[remoteId] = peer.copyWith(
            latencyMs: latency,
            quality: _qualityForLatency(latency),
            lastSeenAt: DateTime.now(),
          );
          _emit();
        }
      case 'disconnect':
        final connection = _connections.remove(remoteId);
        await connection?.close();
        _setPeerStatus(remoteId, PeerConnectionStatus.disconnected);
      default:
        break;
    }
  }

  @override
  Future<void> sendClipboard(
    String deviceId,
    SharedClipboardPayload payload,
  ) async {
    final connection = _connections[deviceId];
    if (connection == null) throw StateError('Peer is not connected');
    final image = payload.imageBytes;
    if (image != null &&
        image.length > _settings.sharingMaxImageMb * 1024 * 1024) {
      throw ArgumentError('Image exceeds configured limit');
    }
    await connection.sendWithAck({
      'type': 'clipboard',
      'messageId': payload.messageId,
      'timestamp': payload.createdAt.millisecondsSinceEpoch,
      if (payload.text != null) 'text': payload.text,
      if (image != null) 'image': base64Encode(image),
    });
    final peer = _discovered[deviceId];
    if (peer != null) {
      _discovered[deviceId] = peer.copyWith(lastSyncedAt: DateTime.now());
      _emit();
    }
  }

  @override
  Future<void> confirmPairing(String deviceId) async {
    final pending = _pairings[deviceId];
    if (pending != null && !pending.decision.isCompleted) {
      pending.decision.complete(true);
    }
  }

  @override
  Future<void> cancelPairing(String deviceId) async {
    final pending = _pairings[deviceId];
    if (pending != null && !pending.decision.isCompleted) {
      pending.decision.complete(false);
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final connection = _connections.remove(deviceId);
    connection?.send({'type': 'disconnect'});
    await connection?.close();
    _setPeerStatus(deviceId, PeerConnectionStatus.disconnected);
  }

  @override
  Future<void> forget(String deviceId) async {
    await disconnect(deviceId);
    _trusted.remove(deviceId);
    await _identityStore.saveTrustedDevices(_trusted);
    final peer = _discovered[deviceId];
    if (peer != null) {
      _discovered[deviceId] = peer.copyWith(
        isTrusted: false,
        status: PeerConnectionStatus.discovered,
      );
    }
    _emit();
  }

  @override
  Future<void> block(String deviceId) async {
    await disconnect(deviceId);
    final current = _trusted[deviceId];
    final peer = _discovered[deviceId];
    _trusted[deviceId] =
        current?.copyWith(blocked: true) ??
        TrustedDeviceRecord(
          deviceId: deviceId,
          publicKey: const [],
          certificateFingerprint: '',
          deviceName: peer?.deviceName ?? deviceId,
          platform: peer?.platform ?? '',
          blocked: true,
        );
    await _identityStore.saveTrustedDevices(_trusted);
    if (peer != null) {
      _discovered[deviceId] = peer.copyWith(
        isTrusted: false,
        isBlocked: true,
        status: PeerConnectionStatus.blocked,
      );
    }
    _emit();
  }

  @override
  Future<void> unblock(String deviceId) async {
    final record = _trusted[deviceId];
    if (record == null) return;
    if (record.publicKey.isEmpty) {
      _trusted.remove(deviceId);
    } else {
      _trusted[deviceId] = record.copyWith(blocked: false);
    }
    await _identityStore.saveTrustedDevices(_trusted);
    final peer = _discovered[deviceId];
    if (peer != null) {
      _discovered[deviceId] = peer.copyWith(
        isTrusted: record.publicKey.isNotEmpty,
        isBlocked: false,
        status: PeerConnectionStatus.discovered,
      );
    }
    _emit();
  }

  @override
  Future<void> refresh() async {
    if (!enableMdns || _discovery == null) return;
    await _discoverySubscription?.cancel();
    await _discovery?.stop();
    _discovery = BonsoirDiscovery(
      type: LocalSharingProtocol.serviceType,
      printLogs: false,
    );
    await _discovery!.initialize();
    _discoverySubscription = _discovery!.eventStream!.listen(_onDiscovery);
    await _discovery!.start();
    _emit();
  }

  @override
  Future<void> updateConfiguration(AppSettings settings) async {
    final wasEnabled =
        _settings.localSharingEnabled && !_settings.allConnectionsPaused;
    final nameChanged =
        _settings.deviceDisplayName != settings.deviceDisplayName ||
        _settings.deviceDiscoverable != settings.deviceDiscoverable;
    _settings = settings;
    final enabled =
        settings.localSharingEnabled && !settings.allConnectionsPaused;
    if (!enabled) {
      await _stopNetwork();
    } else if (!wasEnabled || _server == null) {
      await start(settings);
    } else if (nameChanged && enableMdns) {
      await _broadcast?.stop();
      _broadcast = null;
      if (settings.deviceDiscoverable) {
        final service = BonsoirService(
          name: _displayName,
          type: LocalSharingProtocol.serviceType,
          port: _server!.port,
          attributes: {
            'id': _identity!.deviceId,
            'platform': _platform,
            'version': appVersion,
            'proto': LocalSharingProtocol.protocolVersion,
          },
        );
        _broadcast = BonsoirBroadcast(service: service, printLogs: false);
        await _broadcast!.initialize();
        await _broadcast!.start();
      }
    }
    _emit();
  }

  void _connectionClosed(String id) {
    final removed = _connections.remove(id);
    if (removed == null) return;
    _setPeerStatus(id, PeerConnectionStatus.disconnected);
  }

  void _setPeerStatus(String id, PeerConnectionStatus status) {
    final peer = _discovered[id];
    if (peer != null) {
      _discovered[id] = peer.copyWith(
        status: status,
        quality: status == PeerConnectionStatus.disconnected
            ? ConnectionQuality.offline
            : peer.quality,
      );
    }
    _emit();
  }

  void _emit({String? errorKey}) {
    if (_states.isClosed) return;
    final peers = <String, PeerConnectionInfo>{..._discovered};
    for (final record in _trusted.values) {
      peers.putIfAbsent(
        record.deviceId,
        () => PeerConnectionInfo(
          deviceId: record.deviceId,
          deviceName: record.deviceName,
          platform: record.platform,
          ipAddress: '',
          port: 0,
          status: record.blocked
              ? PeerConnectionStatus.blocked
              : PeerConnectionStatus.disconnected,
          quality: ConnectionQuality.offline,
          pendingItems: 0,
          isTrusted: !record.blocked,
          isBlocked: record.blocked,
        ),
      );
    }
    final pairing = _pairings.values.firstOrNull;
    _states.add(
      LocalSharingState(
        peers: peers.values.toList(growable: false),
        isDiscovering: _server != null && enableMdns,
        pairingSession: pairing == null
            ? null
            : PairingSession(
                peer: pairing.peer,
                confirmationCode: pairing.code,
                expiresAt: pairing.expiresAt,
                isIncoming: true,
              ),
        errorKey: errorKey,
      ),
    );
  }

  Future<void> _stopNetwork() async {
    for (final pairing in _pairings.values) {
      if (!pairing.decision.isCompleted) pairing.decision.complete(false);
    }
    _pairings.clear();
    for (final connection in _connections.values.toList()) {
      await connection.close();
    }
    _connections.clear();
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    if (_discovery != null && !_discovery!.isStopped) await _discovery!.stop();
    _discovery = null;
    if (_broadcast != null && !_broadcast!.isStopped) await _broadcast!.stop();
    _broadcast = null;
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _server?.close();
    _server = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stopNetwork();
    await _states.close();
    await _receivedPayloads.close();
  }

  String get _displayName => _settings.deviceDisplayName.trim().isEmpty
      ? Platform.localHostname
      : _settings.deviceDisplayName.trim();

  String get _platform => platformOverride ?? Platform.operatingSystem;

  static String _certificateFingerprint(X509Certificate certificate) =>
      crypto.sha256.convert(certificate.der).toString();

  static List<int> _transcript(
    Map<String, Object?> local,
    Map<String, Object?> remote,
  ) {
    final hellos = [local, remote]
      ..sort(
        (a, b) => (a['deviceId'] as String).compareTo(b['deviceId'] as String),
      );
    Map<String, Object?> canonical(Map<String, Object?> value) => {
      'deviceId': value['deviceId'],
      'identityKey': value['identityKey'],
      'ephemeralKey': value['ephemeralKey'],
      'nonce': value['nonce'],
      'protocolVersion': value['protocolVersion'],
      'timestamp': value['timestamp'],
    };
    return utf8.encode(jsonEncode(hellos.map(canonical).toList()));
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  void _pruneSeenMessages() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    _seenMessageIds.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
  }

  static ConnectionQuality _qualityForLatency(int latency) {
    if (latency < 20) return ConnectionQuality.excellent;
    if (latency <= 60) return ConnectionQuality.good;
    if (latency <= 150) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }
}

class _PendingPairing {
  _PendingPairing({
    required this.peer,
    required this.code,
    required this.expiresAt,
  });

  final PeerConnectionInfo peer;
  final String code;
  final DateTime expiresAt;
  final decision = Completer<bool>();
}

class _PeerConnection {
  _PeerConnection({
    required this.peer,
    required this.channel,
    required this.onMessage,
    required this.onClosed,
  });

  final PeerConnectionInfo peer;
  final FramedSecureSocket channel;
  final Future<void> Function(Map<String, Object?> message) onMessage;
  final VoidCallback onClosed;
  final _acks = <String, Completer<bool>>{};
  Timer? _pingTimer;
  bool _closed = false;
  int? latencyMs;
  DateTime? lastSyncedAt;

  ConnectionQuality get quality => latencyMs == null
      ? ConnectionQuality.excellent
      : MdnsTlsLocalSharingService._qualityForLatency(latencyMs!);

  void start() {
    unawaited(_readLoop());
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      send({'type': 'ping', 'id': '$now', 'timestamp': now});
    });
  }

  Future<void> _readLoop() async {
    try {
      while (!_closed) {
        await onMessage(await channel.readJson());
      }
    } on Object {
      if (!_closed) onClosed();
    }
  }

  void send(Map<String, Object?> message) {
    if (_closed) return;
    channel.writeJson(message);
  }

  Future<void> sendWithAck(Map<String, Object?> message) async {
    final id = message['messageId'] as String;
    final completer = Completer<bool>();
    _acks[id] = completer;
    send(message);
    await channel.flush();
    final accepted = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
    _acks.remove(id);
    if (!accepted) {
      throw const SocketException('Clipboard was not acknowledged');
    }
  }

  void completeAck(String id, bool accepted) {
    final completer = _acks.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(accepted);
    }
  }

  void recordLatency(int value) => latencyMs = value;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pingTimer?.cancel();
    for (final ack in _acks.values) {
      if (!ack.isCompleted) ack.complete(false);
    }
    _acks.clear();
    await channel.close();
  }
}

typedef VoidCallback = void Function();
