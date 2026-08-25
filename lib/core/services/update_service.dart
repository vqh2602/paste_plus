import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;

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

  static const String currentVersion = '1.2.0';
  static const MethodChannel _windowChannel = MethodChannel('clipflow/window');
  static bool _autoUpdateChecked = false;

  /// Compares [remote] and [local] version strings semantically
  static bool isVersionHigher(String remote, String local) {
    final cleanRemote = remote.replaceAll(RegExp(r'[^0-9.]'), '');
    final cleanLocal = local.replaceAll(RegExp(r'[^0-9.]'), '');

    final rParts = cleanRemote
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final lParts = cleanLocal
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final maxLen = rParts.length > lParts.length
        ? rParts.length
        : lParts.length;

    for (int i = 0; i < maxLen; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final l = i < lParts.length ? lParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }

  /// Navigates to the Settings > About screen.
  static Future<void> navigateToAbout(BuildContext context) async {
    if (!context.mounted) return;
    context.push('/settings?page=about');
  }

  /// Called on app launch. Starts background download via the global provider,
  /// then opens Settings > About so the user can see progress.
  static Future<void> checkAutoUpdate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_autoUpdateChecked) return;
    _autoUpdateChecked = true;

    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    await Future.delayed(const Duration(seconds: 3));
    if (!context.mounted) return;

    // Quick pre-check before navigating
    final info = await const UpdateService().checkForUpdate();
    if (!context.mounted || info == null || !info.hasUpdate) return;

    // Navigate to About so the user can see the download progress.
    navigateToAbout(context);
  }

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

      final assets = json['assets'] is List
          ? json['assets'] as List<dynamic>
          : const <dynamic>[];
      final downloadUrl = selectPlatformAssetUrl(assets);

      final cleanRemote = tagName.replaceAll(RegExp(r'[^0-9.]'), '');
      final hasUpdate = isVersionHigher(cleanRemote, currentVersion);

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

  static String? selectPlatformAssetUrl(
    List<dynamic> assets, {
    String? platform,
  }) {
    final target = platform ?? Platform.operatingSystem;
    final expectedName = switch (target) {
      'windows' => 'clipflow-windows.zip',
      'macos' => 'clipflow-macos.zip',
      'android' => 'clipflow-android.apk',
      'ios' => 'clipflow-ios.ipa',
      _ => null,
    };
    if (expectedName == null) return null;

    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = '${asset['name'] ?? ''}'.toLowerCase();
      if (name != expectedName) continue;
      final url = asset['browser_download_url'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  /// Download the platform release archive and install it automatically.
  Future<bool> downloadAndInstallUpdate({
    required String downloadUrl,
    required ValueChanged<double> onProgress,
  }) async {
    if (!Platform.isMacOS && !Platform.isWindows) return false;
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
      await extractFileToDisk(zipPath, extractDir);

      if (Platform.isWindows) {
        return _installWindowsDirectory(
          extractedDirectory: Directory(extractDir),
          temporaryDirectory: tempDir,
        );
      }

      final appEntity = await _findMacApp(Directory(extractDir));

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

      final installScript =
          '''
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

  Future<bool> _installWindowsDirectory({
    required Directory extractedDirectory,
    required Directory temporaryDirectory,
  }) async {
    final currentExecutable = File(Platform.resolvedExecutable);
    final executableName = path.basename(currentExecutable.path);
    final sourceBundle = await findWindowsBundleDirectory(
      extractedDirectory,
      executableName,
    );
    if (sourceBundle == null) return false;

    final sourceDirectory = sourceBundle.path;
    final targetDirectory = currentExecutable.parent.path;
    if (path.equals(sourceDirectory, targetDirectory)) return false;

    final targetExecutable = path.join(targetDirectory, executableName);
    final script = File(
      path.join(temporaryDirectory.path, 'install-update.ps1'),
    );
    await script.writeAsString(
      buildWindowsInstallScript(
        appProcessId: pid,
        sourceDirectory: sourceDirectory,
        targetDirectory: targetDirectory,
        targetExecutable: targetExecutable,
        temporaryDirectory: temporaryDirectory.path,
      ),
      flush: true,
    );

    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
      ],
      mode: ProcessStartMode.detached,
      workingDirectory: temporaryDirectory.path,
    );
    exit(0);
  }

  static Future<Directory?> findWindowsBundleDirectory(
    Directory root,
    String executableName,
  ) async {
    final executable = await findExtractedExecutable(root, executableName);
    if (executable == null) return null;
    final bundle = executable.parent;
    return await isValidWindowsBundle(bundle, executableName) ? bundle : null;
  }

  static Future<bool> isValidWindowsBundle(
    Directory directory,
    String executableName,
  ) async {
    final executable = File(path.join(directory.path, executableName));
    final flutterLibrary = File(
      path.join(directory.path, 'flutter_windows.dll'),
    );
    final dataDirectory = Directory(path.join(directory.path, 'data'));
    final flutterAssets = Directory(
      path.join(dataDirectory.path, 'flutter_assets'),
    );
    final appLibrary = File(path.join(dataDirectory.path, 'app.so'));
    return await executable.exists() &&
        await flutterLibrary.exists() &&
        await dataDirectory.exists() &&
        await flutterAssets.exists() &&
        await appLibrary.exists();
  }

  static String buildWindowsInstallScript({
    required int appProcessId,
    required String sourceDirectory,
    required String targetDirectory,
    required String targetExecutable,
    required String temporaryDirectory,
  }) {
    final targetFlutterLibrary = path.windows.join(
      targetDirectory,
      'flutter_windows.dll',
    );
    final targetAssets = path.windows.join(
      targetDirectory,
      'data',
      'flutter_assets',
    );
    final logPath = path.join(temporaryDirectory, 'install-update.log');
    return '''
\$ErrorActionPreference = 'Stop'
\$updateLog = ${_powerShellQuote(logPath)}
try {
  Wait-Process -Id $appProcessId -ErrorAction SilentlyContinue
  & robocopy.exe ${_powerShellQuote(sourceDirectory)} ${_powerShellQuote(targetDirectory)} /MIR /R:10 /W:1 /XJ /NP /LOG:\$updateLog
  \$copyExitCode = \$LASTEXITCODE
  if (\$copyExitCode -gt 7) { throw "Robocopy failed with exit code \$copyExitCode" }
  if (-not (Test-Path -LiteralPath ${_powerShellQuote(targetExecutable)} -PathType Leaf)) { throw 'Updated executable is missing' }
  if (-not (Test-Path -LiteralPath ${_powerShellQuote(targetFlutterLibrary)} -PathType Leaf)) { throw 'flutter_windows.dll is missing' }
  if (-not (Test-Path -LiteralPath ${_powerShellQuote(targetAssets)} -PathType Container)) { throw 'Flutter assets are missing' }
  Start-Process -FilePath ${_powerShellQuote(targetExecutable)} -WorkingDirectory ${_powerShellQuote(targetDirectory)}
  Start-Sleep -Seconds 2
  Remove-Item -LiteralPath ${_powerShellQuote(temporaryDirectory)} -Recurse -Force -ErrorAction SilentlyContinue
} catch {
  Add-Content -LiteralPath \$updateLog -Value \$_.Exception.ToString() -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath ${_powerShellQuote(targetExecutable)} -PathType Leaf) {
    Start-Process -FilePath ${_powerShellQuote(targetExecutable)} -WorkingDirectory ${_powerShellQuote(targetDirectory)}
  }
  exit 1
}
''';
  }

  static Future<File?> findExtractedExecutable(
    Directory root,
    String executableName,
  ) async {
    final expected = executableName.toLowerCase();
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          path.basename(entity.path).toLowerCase() == expected) {
        return entity;
      }
    }
    return null;
  }

  static Future<Directory?> _findMacApp(Directory root) async {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is Directory && entity.path.toLowerCase().endsWith('.app')) {
        return entity;
      }
    }
    return null;
  }

  static String _powerShellQuote(String value) =>
      "'${value.replaceAll("'", "''")}'";
}
