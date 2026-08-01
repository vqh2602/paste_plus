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
    'finds the Windows executable inside an extracted release folder',
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

      final found = await UpdateService.findExtractedExecutable(
        root,
        'ClipFlow.exe',
      );

      expect(found?.path, executable.path);
    },
  );
}
