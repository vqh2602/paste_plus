import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    this.releaseNotes,
    this.downloadUrl,
    this.releasePageUrl,
  });

  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? releasePageUrl;
}

class UpdateService {
  const UpdateService();

  static const String currentVersion = '1.0.4';
  static const MethodChannel _windowChannel = MethodChannel('clipflow/window');

  /// Check GitHub releases for available update
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final client = HttpClient();
      final url = Uri.parse(
        'https://api.github.com/repos/vqh2602/paste_plus/releases/latest',
      );
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, 'ClipFlowApp');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github.v3+json',
      );

      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final Map<String, dynamic> json =
          jsonDecode(responseBody) as Map<String, dynamic>;
      final tagName = (json['tag_name'] as String?) ?? '';
      final body = (json['body'] as String?) ?? '';
      final htmlUrl =
          (json['html_url'] as String?) ??
          'https://github.com/vqh2602/paste_plus/releases';

      String? downloadUrl;
      if (json['assets'] is List) {
        final assets = json['assets'] as List<dynamic>;
        for (final asset in assets) {
          if (asset is Map<String, dynamic>) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            final url = asset['browser_download_url'] as String?;
            if (name.endsWith('.zip') ||
                name.endsWith('.dmg') ||
                name.endsWith('.tar.gz')) {
              downloadUrl = url;
              break;
            }
          }
        }
      }

      final cleanRemote = tagName.replaceAll(RegExp(r'[^0-9.]'), '');
      final hasUpdate =
          cleanRemote.isNotEmpty && cleanRemote != currentVersion;

      return UpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: tagName.isEmpty ? cleanRemote : tagName,
        currentVersion: currentVersion,
        releaseNotes: body,
        downloadUrl: downloadUrl,
        releasePageUrl: htmlUrl,
      );
    } catch (e) {
      if (kDebugMode) print('Error checking update: $e');
      return null;
    }
  }

  /// Download release zip asset, unpack and install automatically on macOS.
  Future<bool> downloadAndInstallUpdate({
    required String downloadUrl,
    required ValueChanged<double> onProgress,
  }) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('clipflow_update_');
      final zipPath = '${tempDir.path}/update.zip';
      final zipFile = File(zipPath);

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'ClipFlowApp');
      final response = await request.close();

      if (response.statusCode != 200) {
        client.close();
        return false;
      }

      final contentLength = response.contentLength;
      int downloadedBytes = 0;
      final outputStream = zipFile.openWrite();

      await for (final chunk in response) {
        downloadedBytes += chunk.length;
        outputStream.add(chunk);
        if (contentLength > 0) {
          onProgress(downloadedBytes / contentLength);
        }
      }
      await outputStream.flush();
      await outputStream.close();
      client.close();

      final extractDir = '${tempDir.path}/extracted';
      await Directory(extractDir).create(recursive: true);
      final unzipResult = await Process.run('unzip', [
        '-o',
        zipPath,
        '-d',
        extractDir,
      ]);
      if (unzipResult.exitCode != 0) {
        return false;
      }

      final extractedEntities = Directory(extractDir).listSync();
      FileSystemEntity? appEntity;
      for (final entity in extractedEntities) {
        if (entity.path.endsWith('.app')) {
          appEntity = entity;
          break;
        }
      }

      if (appEntity == null) {
        return false;
      }

      String? currentBundlePath;
      if (Platform.isMacOS) {
        try {
          currentBundlePath = await _windowChannel.invokeMethod<String>(
            'getAppBundlePath',
          );
        } catch (_) {}
      }

      currentBundlePath ??= Platform.resolvedExecutable;
      if (currentBundlePath.contains('.app/Contents/MacOS/')) {
        currentBundlePath = currentBundlePath.substring(
          0,
          currentBundlePath.indexOf('.app/Contents/MacOS/') + 4,
        );
      }

      final newAppPath = appEntity.path;

      final installScript = '''
sleep 1
rm -rf "$currentBundlePath"
cp -R "$newAppPath" "$currentBundlePath"
open "$currentBundlePath"
rm -rf "${tempDir.path}"
''';

      await Process.start('sh', ['-c', installScript]);

      if (Platform.isMacOS) {
        try {
          await _windowChannel.invokeMethod<void>('restartApp');
        } catch (_) {}
      }
      exit(0);
    } catch (e) {
      if (kDebugMode) print('Update installation error: $e');
      return false;
    }
  }
}
