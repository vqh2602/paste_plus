import 'dart:io';

import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/features/settings/services/settings_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SettingsBackupService service;
  late Directory tempDir;

  setUp(() async {
    service = const SettingsBackupService();
    tempDir = await Directory.systemTemp.createTemp('clipflow_backup_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Export and import settings with correct password succeeds', () async {
    final filePath = '${tempDir.path}/test_config.clipflow';
    const originalSettings = AppSettings(
      themeMode: 'dark',
      accentColor: 'orange',
      language: 'vi',
      retentionDays: 45,
      soundEnabled: false,
    );

    final exportResult = await service.exportSettings(
      settings: originalSettings,
      password: 'MySecretPassword123!',
      filePath: filePath,
    );

    expect(exportResult.isSuccess, isTrue);
    expect(File(filePath).existsSync(), isTrue);

    final importResult = await service.importSettings(
      filePath: filePath,
      password: 'MySecretPassword123!',
    );

    expect(importResult.isSuccess, isTrue);
    expect(importResult.settings, isNotNull);
    expect(importResult.settings!.themeMode, equals('dark'));
    expect(importResult.settings!.accentColor, equals('orange'));
    expect(importResult.settings!.retentionDays, equals(45));
    expect(importResult.settings!.soundEnabled, isFalse);
  });

  test(
    'Import settings with wrong password fails with error message',
    () async {
      final filePath = '${tempDir.path}/test_config_wrong_pwd.clipflow';
      const originalSettings = AppSettings(themeMode: 'light');

      await service.exportSettings(
        settings: originalSettings,
        password: 'CorrectPassword123',
        filePath: filePath,
      );

      final importResult = await service.importSettings(
        filePath: filePath,
        password: 'WrongPassword999',
      );

      expect(importResult.isSuccess, isFalse);
      expect(importResult.settings, isNull);
      expect(importResult.errorMessage, contains('Mật khẩu không chính xác'));
    },
  );

  test('Export with empty password fails', () async {
    final filePath = '${tempDir.path}/empty_pwd.clipflow';
    final result = await service.exportSettings(
      settings: const AppSettings(),
      password: '   ',
      filePath: filePath,
    );

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('Mật khẩu không được để trống'));
  });
}
