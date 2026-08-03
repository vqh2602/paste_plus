import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  Future<File> getMmprojFile(String modelId) async {
    final dir = await _modelsDir;
    return File(p.join(dir.path, '${modelId}_mmproj.gguf'));
  }

  Future<File> _getPartFile(String modelId) async {
    final dir = await _modelsDir;
    return File(p.join(dir.path, '$modelId.gguf.part'));
  }

  Future<bool> isModelDownloaded(String modelId) async {
    final file = await getModelFile(modelId);
    if (!await file.exists()) return false;
    final len = await file.length();
    if (len <= 10 * 1024 * 1024) return false;

    // Check if model has a required vision mmproj projector
    final model = AiModelInfo.findById(modelId);
    if (model.mmprojUrl != null) {
      final mmprojFile = await getMmprojFile(modelId);
      if (!await mmprojFile.exists()) return false;
      if (await mmprojFile.length() <= 5 * 1024 * 1024) return false;
    }
    return true;
  }

  /// Check if a partial download (.part file) exists for this model.
  Future<bool> hasPartialDownload(String modelId) async {
    final partFile = await _getPartFile(modelId);
    final mmprojPartFile = File('${(await getMmprojFile(modelId)).path}.part');
    if (await partFile.exists() && await partFile.length() > 0) return true;
    if (await mmprojPartFile.exists() && await mmprojPartFile.length() > 0) return true;
    return false;
  }

  /// Get the size of a partial download (.part file) in bytes.
  Future<int> getPartialDownloadSize(String modelId) async {
    final partFile = await _getPartFile(modelId);
    int total = 0;
    if (await partFile.exists()) {
      total += await partFile.length();
    }
    final mmprojPartFile = File('${(await getMmprojFile(modelId)).path}.part');
    if (await mmprojPartFile.exists()) {
      total += await mmprojPartFile.length();
    }
    return total;
  }

  Future<int> getDownloadedModelSizeBytes(String modelId) async {
    final file = await getModelFile(modelId);
    int total = 0;
    if (await file.exists()) {
      total += await file.length();
    }
    final mmprojFile = await getMmprojFile(modelId);
    if (await mmprojFile.exists()) {
      total += await mmprojFile.length();
    }
    return total;
  }

  /// Verifies SHA-256 checksum of downloaded model file.
  Future<bool> verifyModelChecksum(File file, String? expectedSha256) async {
    if (expectedSha256 == null ||
        expectedSha256.isEmpty ||
        !isValidSha256(expectedSha256)) {
      return true;
    }
    if (!await file.exists()) return false;
    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
    } catch (_) {
      return false;
    }
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
    int totalBytes = (model.fileSizeMb + (model.mmprojFileSizeMb ?? 0)) * 1024 * 1024;
    DateTime lastTime = DateTime.now();
    int bytesSinceLastTime = 0;
    double currentSpeed = 0;

    try {
      final request = await client.getUrl(Uri.parse(model.downloadUrl));

      if (existingBytes > 0) {
        request.headers.set('Range', 'bytes=$existingBytes-');
      }

      final response = await request.close();

      bool isResume = false;
      if (response.statusCode == 206) {
        isResume = true;
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          final totalMatch = RegExp(r'/(\d+)').firstMatch(contentRange);
          if (totalMatch != null) {
            totalBytes = int.parse(totalMatch.group(1)!) +
                ((model.mmprojFileSizeMb ?? 0) * 1024 * 1024);
          }
        } else if (response.contentLength > 0) {
          totalBytes = existingBytes +
              response.contentLength +
              ((model.mmprojFileSizeMb ?? 0) * 1024 * 1024);
        }
      } else if (response.statusCode == 200) {
        isResume = false;
        existingBytes = 0;
        bytesReceived = 0;
        if (response.contentLength > 0) {
          totalBytes = response.contentLength +
              ((model.mmprojFileSizeMb ?? 0) * 1024 * 1024);
        }
      } else {
        throw HttpException('Server HTTP ${response.statusCode}');
      }

      final sink = partFile.openWrite(
        mode: isResume ? FileMode.append : FileMode.write,
      );

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

      if (model.sha256 != null && model.sha256!.isNotEmpty) {
        final valid = await verifyModelChecksum(partFile, model.sha256);
        if (!valid) {
          await partFile.delete();
          client.close();
          _activeClients.remove(model.id);
          controller.add(
            ModelDownloadProgress(
              modelId: model.id,
              bytesReceived: bytesReceived,
              totalBytes: totalBytes,
              speedBytesPerSec: 0,
              state: DownloadState.error,
            ),
          );
          throw const FormatException(
            'Model checksum không hợp lệ. File có thể bị lỗi hoặc bị thay đổi trong quá trình tải.',
          );
        }
      }

      final finalFile = await getModelFile(model.id);
      await partFile.rename(finalFile.path);

      // Download mmproj projector GGUF file if available
      if (model.mmprojUrl != null && model.mmprojUrl!.isNotEmpty) {
        final mmprojFile = await getMmprojFile(model.id);
        final mmprojPartFile = File('${mmprojFile.path}.part');
        int mmprojExisting = 0;
        if (await mmprojPartFile.exists()) {
          mmprojExisting = await mmprojPartFile.length();
        }

        try {
          final mmReq = await client.getUrl(Uri.parse(model.mmprojUrl!));
          if (mmprojExisting > 0) {
            mmReq.headers.set('Range', 'bytes=$mmprojExisting-');
          }
          final mmRes = await mmReq.close();
          bool mmResume = mmRes.statusCode == 206;
          final mmSink = mmprojPartFile.openWrite(
            mode: mmResume ? FileMode.append : FileMode.write,
          );

          await for (final chunk in mmRes) {
            mmSink.add(chunk);
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
          await mmSink.close();

          if (model.mmprojSha256 != null && model.mmprojSha256!.isNotEmpty) {
            final valid = await verifyModelChecksum(mmprojPartFile, model.mmprojSha256);
            if (valid) {
              await mmprojPartFile.rename(mmprojFile.path);
            } else {
              await mmprojPartFile.delete();
            }
          } else {
            await mmprojPartFile.rename(mmprojFile.path);
          }
        } catch (_) {
          // If mmproj projector fails, main model GGUF is still usable in text mode
        }
      }

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
