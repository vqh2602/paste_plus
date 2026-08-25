import 'dart:io';

import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/clipboard_history/data/sqlite_clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/search_query.dart';
import 'package:clipflow/features/device_sync/services/device_identity_store.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/features/vault/presentation/vault_controller.dart';
import 'package:clipflow/features/vault/services/vault_crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory supportDirectory;
  late AppDatabase database;
  late _MemorySecretStore secrets;
  late VaultCrypto crypto;
  late SqliteClipboardRepository repository;

  setUpAll(() async {
    supportDirectory = await Directory.systemTemp.createTemp('clipflow-vault-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      (_) async => supportDirectory.path,
    );
  });

  tearDownAll(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(pathProvider, null);
    await supportDirectory.delete(recursive: true);
  });

  setUp(() async {
    database = await AppDatabase.open(inMemory: true);
    secrets = _MemorySecretStore();
    crypto = VaultCrypto(
      secretStore: secrets,
      deviceAuthenticator: _FakeDeviceAuthenticator(),
    );
    await crypto.initialize();
    await crypto.enable('correct-password');
    repository = SqliteClipboardRepository(database, vaultCrypto: crypto);
  });

  tearDown(() async {
    await repository.clearVault();
    await database.close();
  });

  test(
    'vault encrypts SQLite fields and hides items from normal queries',
    () async {
      final item = await repository.store(
        const ClipboardPayload(
          text: 'top secret account 123',
          sourceAppName: 'Secret source',
        ),
        const AppSettings(ignoreSensitive: false),
      );

      await repository.addToCollection(item!.id, ClipboardCollection.vaultId);

      final raw = (await database.database.query(
        'clipboard_items',
        where: 'id = ?',
        whereArgs: [item.id],
      )).single;
      expect(raw['is_vault'], 1);
      expect(raw['content'], isNot(contains('top secret')));
      expect(raw['content'], startsWith(VaultCrypto.encryptedPrefix));
      expect(
        raw['normalized_content'],
        startsWith(VaultCrypto.encryptedPrefix),
      );
      expect(raw['content_hash'], startsWith(VaultCrypto.encryptedPrefix));
      expect(raw['source_app_name'], startsWith(VaultCrypto.encryptedPrefix));
      expect(raw['searchable_text'], isEmpty);

      expect(await repository.getItems(), isEmpty);
      expect(await repository.getItemsByIds([item.id]), isEmpty);
      expect(
        (await repository.search(const ClipboardSearchQuery())).items,
        isEmpty,
      );

      final vaultItems = await repository.getItems(
        collectionId: ClipboardCollection.vaultId,
      );
      expect(vaultItems.single.content, 'top secret account 123');
      expect(vaultItems.single.sourceAppName, 'Secret source');

      final ftsRows = await database.database.query(
        'clipboard_items_fts',
        where: 'clipboard_id = ?',
        whereArgs: [item.id],
      );
      expect(ftsRows, isEmpty);
    },
  );

  test('locked vault cannot be queried and password restores access', () async {
    final item = await repository.store(
      const ClipboardPayload(text: 'locked secret'),
      const AppSettings(ignoreSensitive: false),
    );
    await repository.addToCollection(item!.id, ClipboardCollection.vaultId);
    crypto.lock();

    await expectLater(
      repository.getItems(collectionId: ClipboardCollection.vaultId),
      throwsA(isA<VaultLockedException>()),
    );
    expect(await crypto.unlockWithPassword('wrong-password'), isFalse);
    expect(await crypto.unlockWithPassword('correct-password'), isTrue);
    expect(
      (await repository.getItems(
        collectionId: ClipboardCollection.vaultId,
      )).single.content,
      'locked secret',
    );
  });

  test(
    'vault encrypts image files and only creates an unlocked preview',
    () async {
      final imageBytes = Uint8List.fromList(<int>[137, 80, 78, 71, 1, 2, 3]);
      final item = await repository.store(
        ClipboardPayload(imageBytes: imageBytes),
        const AppSettings(ignoreSensitive: false),
      );
      final originalPath = item!.imagePath!;

      await repository.addToCollection(item.id, ClipboardCollection.vaultId);

      final raw = (await database.database.query(
        'clipboard_items',
        where: 'id = ?',
        whereArgs: [item.id],
      )).single;
      final encryptedPath = raw['image_path']! as String;
      expect(encryptedPath, endsWith('.cfv'));
      expect(await File(originalPath).exists(), isFalse);
      expect(await File(encryptedPath).readAsBytes(), isNot(imageBytes));

      final unlocked = (await repository.getItems(
        collectionId: ClipboardCollection.vaultId,
      )).single;
      expect(await File(unlocked.imagePath!).readAsBytes(), imageBytes);
      await repository.clearVaultPreviews();
      expect(await File(unlocked.imagePath!).exists(), isFalse);
    },
  );

  test('disabling vault decrypts items back into normal history', () async {
    final item = await repository.store(
      const ClipboardPayload(text: 'restore this value'),
      const AppSettings(ignoreSensitive: false),
    );
    await repository.addToCollection(item!.id, ClipboardCollection.vaultId);

    await repository.disableVault();

    final visible = await repository.getItems();
    expect(visible.single.content, 'restore this value');
    final raw = (await database.database.query(
      'clipboard_items',
      where: 'id = ?',
      whereArgs: [item.id],
    )).single;
    expect(raw['is_vault'], 0);
    expect(raw['content'], 'restore this value');
  });

  test('five invalid attempts wipe only Vault data when enabled', () async {
    final item = await repository.store(
      const ClipboardPayload(text: 'wipe this secret'),
      const AppSettings(ignoreSensitive: false),
    );
    await repository.addToCollection(item!.id, ClipboardCollection.vaultId);
    crypto.lock();
    final controller = VaultController(crypto, repository);
    await controller.initialize();

    VaultUnlockResult? result;
    for (var attempt = 0; attempt < 5; attempt++) {
      result = await controller.unlockWithPassword(
        'wrong-password',
        wipeAfterFiveFailures: true,
      );
    }

    expect(result, VaultUnlockResult.wiped);
    expect(
      await database.database.query('clipboard_items', where: 'is_vault = 1'),
      isEmpty,
    );
    controller.dispose();
  });
}

class _MemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeDeviceAuthenticator implements VaultDeviceAuthenticator {
  @override
  Future<bool> authenticate(String reason) async => true;

  @override
  Future<bool> isAvailable() async => true;
}
