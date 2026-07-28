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

  final Map<String, HttpClientRequest> _activeRequests = {};
  final Map<String, StreamController<ModelDownloadProgress>> _progressControllers = {};

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

  Future<bool> isModelDownloaded(String modelId) async {
    final file = await getModelFile(modelId);
    if (!await file.exists()) return false;
    final len = await file.length();
    // Consider downloaded if length > 10 MB
    return len > 10 * 1024 * 1024;
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
    final file = await getModelFile(model.id);
    final client = HttpClient();
    int bytesReceived = 0;
    int totalBytes = model.fileSizeMb * 1024 * 1024;
    DateTime lastTime = DateTime.now();
    int bytesSinceLastTime = 0;
    double currentSpeed = 0;

    try {
      final request = await client.getUrl(Uri.parse(model.downloadUrl));
      _activeRequests[model.id] = request;

      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Server HTTP ${response.statusCode}');
      }

      if (response.contentLength > 0) {
        totalBytes = response.contentLength;
      }

      final sink = file.openWrite();

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
      client.close();
      _activeRequests.remove(model.id);

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
      _activeRequests.remove(model.id);
      if (await file.exists()) {
        await file.delete();
      }
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
    final req = _activeRequests.remove(modelId);
    req?.abort();
  }

  Future<bool> deleteModel(String modelId) async {
    cancelDownload(modelId);
    final file = await getModelFile(modelId);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}
