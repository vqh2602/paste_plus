import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/ai_model_info.dart';

enum DownloadState { notDownloaded, downloading, paused, downloaded, error }

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.modelId,
    required this.bytesReceived,
    required this.totalBytes,
    required this.speedBytesPerSec,
    required this.state,
    this.errorMessage,
  });

  final String modelId;
  final int bytesReceived;
  final int totalBytes;
  final double speedBytesPerSec;
  final DownloadState state;
  final String? errorMessage;

  double get progress =>
      totalBytes > 0 ? (bytesReceived / totalBytes).clamp(0.0, 1.0) : 0.0;

  int get percentage => (progress * 100).toInt();

  String get bytesFormatted {
    final rec = (bytesReceived / (1024 * 1024)).toStringAsFixed(1);
    final tot = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$rec / $tot MB';
  }

  String get speedFormatted {
    final mbps = speedBytesPerSec / (1024 * 1024);
    return '${mbps.toStringAsFixed(1)} MB/s';
  }
}

class AiModelDownloaderService {
  AiModelDownloaderService();

  final Map<String, HttpClient> _activeClients = {};
  final Map<String, StreamController<ModelDownloadProgress>>
  _progressControllers = {};

  Future<Directory> get _modelsDir async {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appSupport.path, 'ai_models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> getModelFile(String modelId) async {
    final dir = await _modelsDir;
    return File(p.join(dir.path, '$modelId.gguf'));
  }

  Future<File> _getPartFile(String modelId) async {
    final dir = await _modelsDir;
    return File(p.join(dir.path, '$modelId.gguf.part'));
  }

  Future<bool> isModelDownloaded(String modelId) async {
    final file = await getModelFile(modelId);
    if (!await file.exists()) return false;
    final len = await file.length();
    // Consider downloaded if length > 10 MB
    return len > 10 * 1024 * 1024;
  }

  /// Check if a partial download (.part file) exists for this model.
  Future<bool> hasPartialDownload(String modelId) async {
    final partFile = await _getPartFile(modelId);
    if (!await partFile.exists()) return false;
    final len = await partFile.length();
    return len > 0;
  }

  /// Get the size of a partial download (.part file) in bytes.
  Future<int> getPartialDownloadSize(String modelId) async {
    final partFile = await _getPartFile(modelId);
    if (await partFile.exists()) {
      return partFile.length();
    }
    return 0;
  }

  Future<int> getDownloadedModelSizeBytes(String modelId) async {
    final file = await getModelFile(modelId);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  Stream<ModelDownloadProgress> downloadModel(AiModelInfo model) {
    if (_progressControllers.containsKey(model.id)) {
      return _progressControllers[model.id]!.stream;
    }

    final controller = StreamController<ModelDownloadProgress>.broadcast();
    _progressControllers[model.id] = controller;

    _startDownload(model, controller);

    return controller.stream;
  }

  Future<void> _startDownload(
    AiModelInfo model,
    StreamController<ModelDownloadProgress> controller,
  ) async {
    final partFile = await _getPartFile(model.id);
    final client = HttpClient();
    _activeClients[model.id] = client;

    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    }

    int bytesReceived = existingBytes;
    int totalBytes = model.fileSizeMb * 1024 * 1024;
    DateTime lastTime = DateTime.now();
    int bytesSinceLastTime = 0;
    double currentSpeed = 0;

    try {
      final request = await client.getUrl(Uri.parse(model.downloadUrl));

      // Send Range header for resuming partial downloads
      if (existingBytes > 0) {
        request.headers.set('Range', 'bytes=$existingBytes-');
      }

      final response = await request.close();

      // Handle response status
      bool isResume = false;
      if (response.statusCode == 206) {
        // Partial Content — server supports resume
        isResume = true;
        // Parse Content-Range header for total size
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          // Format: bytes start-end/total
          final totalMatch = RegExp(r'/(\d+)').firstMatch(contentRange);
          if (totalMatch != null) {
            totalBytes = int.parse(totalMatch.group(1)!);
          }
        } else if (response.contentLength > 0) {
          totalBytes = existingBytes + response.contentLength;
        }
      } else if (response.statusCode == 200) {
        // Server doesn't support Range — start from scratch
        isResume = false;
        existingBytes = 0;
        bytesReceived = 0;
        if (response.contentLength > 0) {
          totalBytes = response.contentLength;
        }
      } else {
        throw HttpException('Server HTTP ${response.statusCode}');
      }

      // Open file in append mode (resume) or write mode (fresh start)
      final sink = partFile.openWrite(
        mode: isResume ? FileMode.append : FileMode.write,
      );

      // Emit initial progress immediately
      controller.add(
        ModelDownloadProgress(
          modelId: model.id,
          bytesReceived: bytesReceived,
          totalBytes: totalBytes,
          speedBytesPerSec: 0,
          state: DownloadState.downloading,
        ),
      );

      await for (final chunk in response) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        bytesSinceLastTime += chunk.length;

        final now = DateTime.now();
        final elapsedMs = now.difference(lastTime).inMilliseconds;
        if (elapsedMs >= 300) {
          currentSpeed = (bytesSinceLastTime * 1000.0) / elapsedMs;
          bytesSinceLastTime = 0;
          lastTime = now;

          controller.add(
            ModelDownloadProgress(
              modelId: model.id,
              bytesReceived: bytesReceived,
              totalBytes: totalBytes,
              speedBytesPerSec: currentSpeed,
              state: DownloadState.downloading,
            ),
          );
        }
      }

      await sink.close();

      // Download complete — rename .part to .gguf
      final finalFile = await getModelFile(model.id);
      await partFile.rename(finalFile.path);

      client.close();
      _activeClients.remove(model.id);

      controller.add(
        ModelDownloadProgress(
          modelId: model.id,
          bytesReceived: totalBytes,
          totalBytes: totalBytes,
          speedBytesPerSec: 0,
          state: DownloadState.downloaded,
        ),
      );
    } catch (e) {
      client.close();
      _activeClients.remove(model.id);

      // DO NOT delete the .part file — keep it for resume
      controller.add(
        ModelDownloadProgress(
          modelId: model.id,
          bytesReceived: bytesReceived,
          totalBytes: totalBytes,
          speedBytesPerSec: 0,
          state: DownloadState.error,
          errorMessage: e.toString(),
        ),
      );
    } finally {
      await controller.close();
      _progressControllers.remove(model.id);
    }
  }

  void cancelDownload(String modelId) {
    final client = _activeClients.remove(modelId);
    client?.close(force: true);
  }

  Future<bool> deleteModel(String modelId) async {
    cancelDownload(modelId);

    bool deleted = false;
    final file = await getModelFile(modelId);
    if (await file.exists()) {
      await file.delete();
      deleted = true;
    }
    // Also clean up any .part file
    final partFile = await _getPartFile(modelId);
    if (await partFile.exists()) {
      await partFile.delete();
      deleted = true;
    }
    return deleted;
  }

  /// Delete only the partial download (.part) file.
  Future<void> deletePartialDownload(String modelId) async {
    cancelDownload(modelId);
    final partFile = await _getPartFile(modelId);
    if (await partFile.exists()) {
      await partFile.delete();
    }
  }
}
