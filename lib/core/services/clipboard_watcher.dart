import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../features/clipboard_history/domain/clipboard_payload.dart';

abstract interface class ClipboardWatcher {
  Stream<ClipboardPayload> watch();
  Future<ClipboardPayload?> readCurrent();
  Future<void> write(ClipboardPayload payload);
  Future<void> start();
  Future<void> stop();
}

class FlutterClipboardWatcher implements ClipboardWatcher {
  FlutterClipboardWatcher({
    this.pollInterval = const Duration(milliseconds: 700),
  });

  final Duration pollInterval;
  final _controller = StreamController<ClipboardPayload>.broadcast();
  Timer? _timer;
  String? _lastObserved;
  bool _reading = false;

  @override
  Stream<ClipboardPayload> watch() => _controller.stream;

  @override
  Future<ClipboardPayload?> readCurrent() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return null;
    return ClipboardPayload(text: text);
  }

  @override
  Future<void> start() async {
    if (_timer != null) return;
    final current = await readCurrent();
    _lastObserved = _signature(current);
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_reading) return;
    _reading = true;
    try {
      final payload = await readCurrent();
      final signature = _signature(payload);
      if (payload != null && signature != _lastObserved) {
        _lastObserved = signature;
        _controller.add(payload);
      }
    } on Object catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    } finally {
      _reading = false;
    }
  }

  @override
  Future<void> write(ClipboardPayload payload) async {
    if (payload.text == null) return;
    suppress(payload);
    await Clipboard.setData(ClipboardData(text: payload.text!));
  }

  void suppress(ClipboardPayload payload) {
    _lastObserved = _signature(payload);
  }

  String? _signature(ClipboardPayload? payload) {
    if (payload == null) return null;
    if (payload.imageBytes != null) {
      final bytes = payload.imageBytes!;
      final sample = bytes.take(32).toList(growable: false);
      return 'image:${bytes.length}:${base64Encode(sample)}';
    }
    return 'text:${payload.text}';
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

class MacOSClipboardWatcher extends FlutterClipboardWatcher {
  MacOSClipboardWatcher({super.pollInterval});

  static const _channel = MethodChannel('clipflow/clipboard');

  @override
  Future<ClipboardPayload?> readCurrent() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      if (result == null) return null;
      final imageSource = result['imageBase64'] as String?;
      final payload = ClipboardPayload(
        text: result['text'] as String?,
        imageBytes: imageSource == null ? null : base64Decode(imageSource),
        sourceAppName: result['sourceAppName'] as String?,
        sourceAppIdentifier: result['sourceAppIdentifier'] as String?,
      );
      return payload.isEmpty ? null : payload;
    } on PlatformException {
      return super.readCurrent();
    } on MissingPluginException {
      return super.readCurrent();
    }
  }

  @override
  Future<void> write(ClipboardPayload payload) async {
    if (payload.imageBytes == null) {
      await super.write(payload);
      return;
    }
    suppress(payload);
    await _channel.invokeMethod<void>('writeImage', {
      'imageBase64': base64Encode(payload.imageBytes!),
    });
  }
}
