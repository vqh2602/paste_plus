import 'dart:io';
import 'dart:typed_data';

import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
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

  test(
    'encrypted archive restores history and collection memberships',
    () async {
      final sourceDatabase = await AppDatabase.open(inMemory: true);
      final sourceRepository = SqliteClipboardRepository(sourceDatabase);
      final item = await sourceRepository.store(
        const ClipboardPayload(text: 'archive me'),
        const AppSettings(ignoreSensitive: false),
      );
      final collection = ClipboardCollection(
        id: 'archive-work',
        name: 'Archive Work',
        icon: 'folder',
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
        sortOrder: 99,
      );
      await sourceRepository.upsertCollection(collection);
      await sourceRepository.addToCollection(item!.id, collection.id);
      // Simulate a newer producer adding a column that the importing database
      // does not know yet. Import must keep working and ignore that field.
      await sourceDatabase.database.execute(
        'ALTER TABLE clipboard_items ADD COLUMN future_archive_field TEXT',
      );
      await sourceDatabase.database.update(
        'clipboard_items',
        {'future_archive_field': 'newer-schema-value'},
        where: 'id = ?',
        whereArgs: [item.id],
      );

      final filePath = '${tempDir.path}/history.clipflow';
      final exported = await service.exportSettings(
        settings: const AppSettings(themeMode: 'dark'),
        password: 'ArchivePassword123!',
        filePath: filePath,
        database: sourceDatabase,
      );
      await sourceDatabase.close();
      final targetDatabase = await AppDatabase.open(inMemory: true);
      addTearDown(targetDatabase.close);
      final targetRepository = SqliteClipboardRepository(targetDatabase);
      final imported = await service.importSettings(
        filePath: filePath,
        password: 'ArchivePassword123!',
        database: targetDatabase,
      );

      expect(exported.isSuccess, isTrue);
      expect(imported.isSuccess, isTrue);
      expect(imported.importedClipboardItems, 1);
      final restored = await targetRepository.getItems();
      expect(restored.single.content, 'archive me');
      final restoredCollections = await targetRepository.collectionIdsForItem(
        restored.single.id,
      );
      expect(restoredCollections, contains('archive-work'));
    },
  );

  test('encrypted archive embeds and restores clipboard images', () async {
    final sourceDatabase = await AppDatabase.open(inMemory: true);
    final imageBytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      1,
      2,
      3,
    ]);
    final sourceImage = File('${tempDir.path}/source-image.png');
    await sourceImage.writeAsBytes(imageBytes);
    final now = DateTime.now().millisecondsSinceEpoch;
    await sourceDatabase.database.insert('clipboard_items', {
      'id': 'archived-image',
      'content': '',
      'normalized_content': '',
      'content_hash': 'source-image-hash',
      'content_type': 'image',
      'created_at': now,
      'updated_at': now,
      'last_copied_at': now,
      'image_path': sourceImage.path,
    });

    final filePath = '${tempDir.path}/image-history.clipflow';
    final exported = await service.exportSettings(
      settings: const AppSettings(),
      password: 'ImageArchivePassword123!',
      filePath: filePath,
      database: sourceDatabase,
    );
    await sourceDatabase.close();

    final targetDatabase = await AppDatabase.open(inMemory: true);
    addTearDown(targetDatabase.close);
    final targetRepository = SqliteClipboardRepository(targetDatabase);
    final imported = await service.importSettings(
      filePath: filePath,
      password: 'ImageArchivePassword123!',
      database: targetDatabase,
    );

    expect(exported.isSuccess, isTrue);
    expect(imported.isSuccess, isTrue);
    expect(imported.importedClipboardItems, 1);
    final restored = (await targetRepository.getItems()).single;
    expect(restored.imagePath, isNotNull);
    expect(await File(restored.imagePath!).readAsBytes(), imageBytes);
  });

  test('new importer remains compatible with settings-only v1 files', () async {
    final filePath = '${tempDir.path}/legacy.clipflow';
    await service.exportSettings(
      settings: const AppSettings(language: 'de'),
      password: 'LegacyPassword123!',
      filePath: filePath,
    );
    final database = await AppDatabase.open(inMemory: true);
    addTearDown(database.close);

    final imported = await service.importSettings(
      filePath: filePath,
      password: 'LegacyPassword123!',
      database: database,
    );

    expect(imported.isSuccess, isTrue);
    expect(imported.settings!.language, 'de');
    expect(imported.importedClipboardItems, 0);
  });
}
