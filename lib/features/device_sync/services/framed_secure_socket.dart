import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FramedSecureSocket {
  FramedSecureSocket(
    this.socket, {
    this.maximumFrameBytes = 110 * 1024 * 1024,
  }) {
    _subscription = socket.listen(
      _onData,
      onError: _fail,
      onDone: () => _fail(const SocketException('Connection closed')),
      cancelOnError: true,
    );
  }

  final SecureSocket socket;
  final int maximumFrameBytes;
  final _buffer = BytesBuilder(copy: false);
  final _frames = <Uint8List>[];
  final _waiters = <Completer<Uint8List>>[];
  late final StreamSubscription<Uint8List> _subscription;
  Object? _terminalError;

  Future<Map<String, Object?>> readJson() async {
    final bytes = await readFrame();
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('Expected JSON object');
    return decoded.cast<String, Object?>();
  }

  Future<Uint8List> readFrame() {
    if (_frames.isNotEmpty) return Future.value(_frames.removeAt(0));
    if (_terminalError != null) return Future.error(_terminalError!);
    final waiter = Completer<Uint8List>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void writeJson(Map<String, Object?> value) {
    writeFrame(Uint8List.fromList(utf8.encode(jsonEncode(value))));
  }

  void writeFrame(Uint8List bytes) {
    if (bytes.length > maximumFrameBytes) {
      throw ArgumentError.value(bytes.length, 'bytes', 'Frame is too large');
    }
    final header = ByteData(4)..setUint32(0, bytes.length, Endian.big);
    socket.add(header.buffer.asUint8List());
    socket.add(bytes);
  }

  Future<void> flush() => socket.flush();

  void _onData(Uint8List data) {
    _buffer.add(data);
    var bytes = _buffer.takeBytes();
    var offset = 0;
    while (bytes.length - offset >= 4) {
      final length = ByteData.sublistView(
        bytes,
        offset,
        offset + 4,
      ).getUint32(0, Endian.big);
      if (length > maximumFrameBytes) {
        _fail(const FormatException('Frame exceeds maximum size'));
        return;
      }
      if (bytes.length - offset - 4 < length) break;
      final frame = Uint8List.sublistView(
        bytes,
        offset + 4,
        offset + 4 + length,
      );
      _deliver(Uint8List.fromList(frame));
      offset += 4 + length;
    }
    if (offset < bytes.length) _buffer.add(bytes.sublist(offset));
  }

  void _deliver(Uint8List frame) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(frame);
    } else {
      _frames.add(frame);
    }
  }

  void _fail(Object error) {
    if (_terminalError != null) return;
    _terminalError = error;
    for (final waiter in _waiters) {
      waiter.completeError(error);
    }
    _waiters.clear();
  }

  Future<void> close() async {
    await _subscription.cancel();
    await socket.close();
    _fail(const SocketException('Connection closed'));
  }
}
