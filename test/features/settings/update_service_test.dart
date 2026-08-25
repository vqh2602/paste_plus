import 'dart:io';

import 'package:clipflow/core/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('selects the release asset for the requested platform', () {
    final assets = <Map<String, String>>[
      {
        'name': 'ClipFlow-macOS.zip',
        'browser_download_url': 'https://example.test/macos',
      },
      {
        'name': 'ClipFlow-Windows.zip',
        'browser_download_url': 'https://example.test/windows',
      },
      {
        'name': 'ClipFlow-Android.apk',
        'browser_download_url': 'https://example.test/android',
      },
    ];

    expect(
      UpdateService.selectPlatformAssetUrl(assets, platform: 'windows'),
      'https://example.test/windows',
    );
    expect(
      UpdateService.selectPlatformAssetUrl(assets, platform: 'macos'),
      'https://example.test/macos',
    );
    expect(
      UpdateService.selectPlatformAssetUrl(assets, platform: 'android'),
      'https://example.test/android',
    );
  });

  test(
    'validates the full Windows bundle and builds a directory installer',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'clipflow_update_test_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final release = Directory(path.join(root.path, 'nested', 'Release'));
      await release.create(recursive: true);
      final executable = File(path.join(release.path, 'clipflow.exe'));
      await executable.writeAsBytes(const [1, 2, 3]);
      await File(
        path.join(release.path, 'flutter_windows.dll'),
      ).writeAsBytes(const [4, 5, 6]);
      final data = Directory(path.join(release.path, 'data'));
      await Directory(
        path.join(data.path, 'flutter_assets'),
      ).create(recursive: true);
      await File(path.join(data.path, 'app.so')).writeAsBytes(const [7, 8, 9]);

      final found = await UpdateService.findWindowsBundleDirectory(
        root,
        'ClipFlow.exe',
      );

      expect(found?.path, release.path);

      final script = UpdateService.buildWindowsInstallScript(
        appProcessId: 4242,
        sourceDirectory: release.path,
        targetDirectory: r'D:\Apps\ClipFlow',
        targetExecutable: r'D:\Apps\ClipFlow\clipflow.exe',
        temporaryDirectory: root.path,
      );
      expect(script, contains('Wait-Process -Id 4242'));
      expect(script, isNot(contains(r'Wait-Process -Id $pid')));
      expect(script, contains('robocopy.exe'));
      expect(script, contains('/MIR'));
      expect(script, contains('flutter_windows.dll'));
      expect(script, contains(r'data\flutter_assets'));
    },
  );
}
