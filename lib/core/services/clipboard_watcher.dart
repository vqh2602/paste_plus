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
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  Future<void> poll() async {
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
    if (payload.filePaths.isNotEmpty) {
      return 'files:${payload.filePaths.join('\n')}';
    }
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
  int? _lastChangeCount;

  @override
  Future<void> start() async {
    if (_timer != null) return;
    // Read initial changeCount without emitting
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      _lastChangeCount = result?['changeCount'] as int?;
    } on Object catch (_) {}
    _lastObserved = _signature(await readCurrent());
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  @override
  Future<void> poll() async {
    if (_reading) return;
    _reading = true;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      if (result == null) return;

      final changeCount = result['changeCount'] as int?;
      // changeCount is the most reliable detector: it increments for every
      // clipboard write regardless of HOW the copy was triggered
      // (keyboard shortcut, right-click menu, in-app copy button, etc.)
      final changed = changeCount != null && changeCount != _lastChangeCount;
      if (!changed) return;
      _lastChangeCount = changeCount;

      final payload = _payloadFromNativeResult(result);
      if (payload.isEmpty) return;

      final signature = _signature(payload);
      if (signature == _lastObserved) return;
      _lastObserved = signature;
      _controller.add(payload);
    } on Object catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    } finally {
      _reading = false;
    }
  }

  @override
  Future<ClipboardPayload?> readCurrent() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      if (result == null) return null;
      final payload = _payloadFromNativeResult(result);
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
      if (payload.text == null) return;
      // Text write — suppress and sync changeCount
      suppress(payload);
      await Clipboard.setData(ClipboardData(text: payload.text!));
      try {
        final result = await _channel.invokeMapMethod<String, dynamic>(
          'readClipboard',
        );
        _lastChangeCount = result?['changeCount'] as int?;
      } on Object catch (_) {}
      return;
    }
    suppress(payload);
    // Sync changeCount before image write
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      _lastChangeCount = result?['changeCount'] as int?;
    } on Object catch (_) {}
    await _channel.invokeMethod<void>('writeImage', {
      'imageBase64': base64Encode(payload.imageBytes!),
    });
    // Update changeCount again after the image write
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      _lastChangeCount = result?['changeCount'] as int?;
    } on Object catch (_) {}
  }
}

class WindowsClipboardWatcher extends FlutterClipboardWatcher {
  WindowsClipboardWatcher({super.pollInterval});

  static const _channel = MethodChannel('clipflow/clipboard');
  int? _lastSequenceNumber;

  @override
  Future<void> start() async {
    if (_timer != null) return;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      _lastSequenceNumber = result?['sequenceNumber'] as int?;
    } on Object catch (_) {}
    _lastObserved = _signature(await readCurrent());
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  @override
  Future<void> poll() async {
    if (_reading) return;
    _reading = true;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      if (result == null) return;

      final seqNum = result['sequenceNumber'] as int?;
      // sequenceNumber increments on every clipboard write (Windows API)
      final changed = seqNum != null && seqNum != _lastSequenceNumber;
      if (!changed) return;
      _lastSequenceNumber = seqNum;

      final payload = _payloadFromNativeResult(result);
      if (payload.isEmpty) return;

      final signature = _signature(payload);
      if (signature == _lastObserved) return;
      _lastObserved = signature;
      _controller.add(payload);
    } on Object catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    } finally {
      _reading = false;
    }
  }

  @override
  Future<ClipboardPayload?> readCurrent() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      if (result == null) return null;
      final payload = _payloadFromNativeResult(result);
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
      if (payload.text == null) return;
      suppress(payload);
      await Clipboard.setData(ClipboardData(text: payload.text!));
      try {
        final result = await _channel.invokeMapMethod<String, dynamic>(
          'readClipboard',
        );
        _lastSequenceNumber = result?['sequenceNumber'] as int?;
      } on Object catch (_) {}
      return;
    }
    suppress(payload);
    await _channel.invokeMethod<void>('writeImage', {
      'imageBase64': base64Encode(payload.imageBytes!),
    });
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readClipboard',
      );
      _lastSequenceNumber = result?['sequenceNumber'] as int?;
    } on Object catch (_) {}
  }
}

ClipboardPayload _payloadFromNativeResult(Map<String, dynamic> result) {
  final filePaths = (result['filePaths'] as List<Object?>? ?? const [])
      .whereType<String>()
      .where((path) => path.trim().isNotEmpty)
      .toList(growable: false);
  final imageSource = result['imageBase64'] as String?;
  return ClipboardPayload(
    text: filePaths.isEmpty ? result['text'] as String? : filePaths.join('\n'),
    // Finder and Explorer may expose a thumbnail together with CF_HDROP/file
    // URLs. A file-list payload must never be downgraded to an image payload.
    imageBytes: filePaths.isNotEmpty || imageSource == null
        ? null
        : base64Decode(imageSource),
    filePaths: filePaths,
    sourceAppName: result['sourceAppName'] as String?,
    sourceAppIdentifier: result['sourceAppIdentifier'] as String?,
  );
}
