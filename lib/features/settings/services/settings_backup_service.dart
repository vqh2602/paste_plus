import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as secure;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_version.dart';
import '../../../core/database/app_database.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../../clipboard_history/domain/content_classifier.dart';
import '../domain/app_settings.dart';

class SettingsBackupResult {
  const SettingsBackupResult.success([
    this.settings,
    this.importedClipboardItems = 0,
  ]) : isSuccess = true,
       errorMessage = null;

  const SettingsBackupResult.failure(this.errorMessage)
    : isSuccess = false,
      settings = null,
      importedClipboardItems = 0;

  final bool isSuccess;
  final String? errorMessage;
  final AppSettings? settings;
  final int importedClipboardItems;
}

class SettingsBackupService {
  const SettingsBackupService();

  /// Export AppSettings into password-protected .clipflow zip file
  Future<SettingsBackupResult> exportSettings({
    required AppSettings settings,
    required String password,
    required String filePath,
    AppDatabase? database,
  }) async {
    if (password.trim().isEmpty) {
      return const SettingsBackupResult.failure(
        'Mật khẩu không được để trống.',
      );
    }

    try {
      final salt = _randomBytes(16);
      final iv = _randomBytes(16);

      final key = _pbkdf2(password, salt, 10000, 32);
      final macKey = sha256.convert([...key, ...utf8.encode('HMAC')]).bytes;

      final jsonString = settings.toJson();
      final plaintext = utf8.encode(jsonString);

      final ciphertext = _encryptStream(plaintext, Uint8List.fromList(key), iv);

      final hmacInput = [...salt, ...iv, ...ciphertext];
      final hmac = Hmac(sha256, macKey).convert(hmacInput).bytes;

      final manifestMap = {
        'format': database == null
            ? 'clipflow_config_v1'
            : 'clipflow_archive_v2',
        'archive_schema': database == null ? 1 : 2,
        'app': 'ClipFlow',
        'version': ClipFlowVersion.current,
        'created_at': DateTime.now().toIso8601String(),
        'salt': _toHex(salt),
        'iv': _toHex(iv),
        'hmac': _toHex(hmac),
      };

      Uint8List? historyCiphertext;
      if (database != null) {
        const historyKdfIterations = 210000;
        final historySalt = _randomBytes(16);
        final historyNonce = _randomBytes(12);
        final historyJson = await _exportHistory(database);
        final historyKey = await _deriveSecureKey(
          password,
          historySalt,
          historyKdfIterations,
        );
        final secretBox = await secure.AesGcm.with256bits().encrypt(
          utf8.encode(jsonEncode(historyJson)),
          secretKey: historyKey,
          nonce: historyNonce,
        );
        historyCiphertext = Uint8List.fromList(secretBox.cipherText);
        manifestMap
          ..['history_format'] = 'clipflow_history_v1'
          ..['history_encryption'] = 'aes-256-gcm'
          ..['history_kdf'] = 'pbkdf2-hmac-sha256'
          ..['history_kdf_iterations'] = historyKdfIterations
          ..['history_salt'] = _toHex(historySalt)
          ..['history_nonce'] = _toHex(historyNonce)
          ..['history_mac'] = _toHex(secretBox.mac.bytes);
      }

      final manifestBytes = utf8.encode(jsonEncode(manifestMap));

      final zipBytes = _createZip([
        _ZipEntry('manifest.json', manifestBytes),
        _ZipEntry('settings.enc', ciphertext),
        if (historyCiphertext != null)
          _ZipEntry('history.enc', historyCiphertext),
      ]);

      final file = File(filePath);
      await file.writeAsBytes(zipBytes, flush: true);

      return const SettingsBackupResult.success();
    } on Object catch (e) {
      return SettingsBackupResult.failure('Lỗi khi xuất cấu hình: $e');
    }
  }

  /// Import AppSettings from password-protected .clipflow zip file
  Future<SettingsBackupResult> importSettings({
    required String filePath,
    required String password,
    AppDatabase? database,
  }) async {
    if (password.trim().isEmpty) {
      return const SettingsBackupResult.failure(
        'Mật khẩu không được để trống.',
      );
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const SettingsBackupResult.failure(
          'Tệp cấu hình không tồn tại.',
        );
      }

      final zipBytes = await file.readAsBytes();
      final entries = _readZip(zipBytes);

      final manifestData = entries['manifest.json'];
      final ciphertext = entries['settings.enc'];

      if (manifestData == null || ciphertext == null) {
        return const SettingsBackupResult.failure(
          'Định dạng tệp .clipflow không hợp lệ hoặc bị hư hỏng.',
        );
      }

      final manifestMap =
          jsonDecode(utf8.decode(manifestData)) as Map<String, dynamic>;

      final saltHex = manifestMap['salt'] as String?;
      final ivHex = manifestMap['iv'] as String?;
      final hmacHex = manifestMap['hmac'] as String?;

      if (saltHex == null || ivHex == null || hmacHex == null) {
        return const SettingsBackupResult.failure(
          'Tệp cấu hình thiếu dữ liệu mã hóa.',
        );
      }

      final salt = _fromHex(saltHex);
      final iv = _fromHex(ivHex);
      final expectedHmac = _fromHex(hmacHex);

      final key = _pbkdf2(password, salt, 10000, 32);
      final macKey = sha256.convert([...key, ...utf8.encode('HMAC')]).bytes;

      final hmacInput = [...salt, ...iv, ...ciphertext];
      final computedHmac = Hmac(sha256, macKey).convert(hmacInput).bytes;

      if (!_bytesEqual(expectedHmac, computedHmac)) {
        return const SettingsBackupResult.failure(
          'Mật khẩu không chính xác hoặc tệp đã bị thay đổi.',
        );
      }

      final decryptedBytes = _encryptStream(
        ciphertext,
        Uint8List.fromList(key),
        iv,
      );
      final jsonString = utf8.decode(decryptedBytes);
      final settings = AppSettings.fromJson(jsonString);

      var importedClipboardItems = 0;
      final historyCiphertext = entries['history.enc'];
      if (database != null && historyCiphertext != null) {
        final historySaltHex = manifestMap['history_salt'] as String?;
        final historyNonceHex = manifestMap['history_nonce'] as String?;
        final historyMacHex = manifestMap['history_mac'] as String?;
        final historyKdfIterations =
            (manifestMap['history_kdf_iterations'] as num?)?.toInt() ?? 210000;
        if (historySaltHex == null ||
            historyNonceHex == null ||
            historyMacHex == null) {
          return const SettingsBackupResult.failure(
            'Tệp lịch sử thiếu dữ liệu mã hóa.',
          );
        }
        final historyKey = await _deriveSecureKey(
          password,
          _fromHex(historySaltHex),
          historyKdfIterations.clamp(10000, 1000000),
        );
        final historyBytes = await secure.AesGcm.with256bits().decrypt(
          secure.SecretBox(
            historyCiphertext,
            nonce: _fromHex(historyNonceHex),
            mac: secure.Mac(_fromHex(historyMacHex)),
          ),
          secretKey: historyKey,
        );
        final history = jsonDecode(utf8.decode(historyBytes));
        if (history is! Map<String, dynamic>) {
          return const SettingsBackupResult.failure(
            'Định dạng lịch sử clipboard không hợp lệ.',
          );
        }
        importedClipboardItems = await _importHistory(database, history);
      }

      return SettingsBackupResult.success(settings, importedClipboardItems);
    } on FormatException catch (_) {
      return const SettingsBackupResult.failure(
        'Mật khẩu không đúng hoặc nội dung giải mã không hợp lệ.',
      );
    } on Object catch (e) {
      return SettingsBackupResult.failure('Không thể đọc tệp cấu hình: $e');
    }
  }

  Future<Map<String, dynamic>> _exportHistory(AppDatabase database) async {
    final db = database.database;
    final itemRows = await db.query(
      'clipboard_items',
      where: 'is_vault = 0',
      orderBy: 'created_at ASC',
    );
    final items = <Map<String, dynamic>>[];
    for (final sourceRow in itemRows) {
      final row = <String, dynamic>{...sourceRow};
      final imagePath = row['image_path'] as String?;
      row['image_path'] = null;
      if (imagePath != null && imagePath.isNotEmpty) {
        final image = File(imagePath);
        if (await image.exists()) {
          row['image_data'] = base64Encode(await image.readAsBytes());
          row['image_extension'] = p.extension(imagePath).replaceFirst('.', '');
        }
      }
      items.add(row);
    }
    final collections = await db.query(
      'collections',
      where: 'id != ?',
      whereArgs: ['vault'],
      orderBy: 'sort_order ASC',
    );
    final memberships = await db.rawQuery('''
      SELECT clipboard_item_id, collection_id, created_at
      FROM clipboard_item_collections
      WHERE collection_id != 'vault'
        AND clipboard_item_id IN (
          SELECT id FROM clipboard_items WHERE is_vault = 0
        )
      ''');
    return {
      'format': 'clipflow_history_v1',
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'items': items,
      'collections': collections,
      'memberships': memberships,
    };
  }

  Future<secure.SecretKey> _deriveSecureKey(
    String password,
    Uint8List salt,
    int iterations,
  ) {
    return secure.Pbkdf2(
      macAlgorithm: secure.Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  Future<int> _importHistory(
    AppDatabase database,
    Map<String, dynamic> history,
  ) async {
    final db = database.database;
    final itemColumns = await _tableColumns(db, 'clipboard_items');
    final collectionColumns = await _tableColumns(db, 'collections');
    final membershipColumns = await _tableColumns(
      db,
      'clipboard_item_collections',
    );
    final collectionIdMap = <String, String>{};
    final itemIdMap = <String, String>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final record in _mapRecords(history['collections'])) {
      final archiveId = record['id']?.toString();
      final name = record['name']?.toString().trim();
      if (archiveId == null ||
          archiveId.isEmpty ||
          archiveId == 'vault' ||
          name == null ||
          name.isEmpty) {
        continue;
      }
      final sameName = await db.query(
        'collections',
        columns: ['id'],
        where: 'LOWER(name) = LOWER(?)',
        whereArgs: [name],
        limit: 1,
      );
      if (sameName.isNotEmpty) {
        collectionIdMap[archiveId] = sameName.single['id']! as String;
        continue;
      }
      final values = _knownValues(record, collectionColumns)
        ..['id'] = archiveId
        ..['name'] = name
        ..putIfAbsent('icon', () => 'folder')
        ..putIfAbsent('created_at', () => now)
        ..putIfAbsent('updated_at', () => now)
        ..putIfAbsent('sort_order', () => 0);
      await db.insert(
        'collections',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final resolved = await db.query(
        'collections',
        columns: ['id'],
        where: 'id = ? OR LOWER(name) = LOWER(?)',
        whereArgs: [archiveId, name],
        limit: 1,
      );
      if (resolved.isNotEmpty) {
        collectionIdMap[archiveId] = resolved.single['id']! as String;
      }
    }

    var importedItems = 0;
    final imageDirectory = await _importImageDirectory(database);
    for (final record in _mapRecords(history['items'])) {
      final archiveId = record['id']?.toString();
      final content = record['content']?.toString() ?? '';
      Uint8List? imageBytes;
      final encodedImage = record['image_data'];
      if (encodedImage is String && encodedImage.isNotEmpty) {
        try {
          imageBytes = base64Decode(encodedImage);
        } on FormatException {
          imageBytes = null;
        }
      }
      if (archiveId == null ||
          archiveId.isEmpty ||
          (content.trim().isEmpty && imageBytes == null)) {
        continue;
      }
      final normalized =
          record['normalized_content']?.toString() ??
          ContentNormalizer.normalize(content);
      // Recompute instead of trusting archive metadata. Besides preserving the
      // live database invariant, this prevents a crafted archive from mapping
      // memberships onto an unrelated item by supplying its content hash.
      final hash = sha256
          .convert(imageBytes ?? utf8.encode(normalized))
          .toString();
      final duplicate = await db.query(
        'clipboard_items',
        columns: ['id'],
        where: 'content_hash = ? AND is_vault = 0',
        whereArgs: [hash],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        itemIdMap[archiveId] = duplicate.single['id']! as String;
        continue;
      }

      final rawType = record['content_type']?.toString();
      final type =
          ClipboardContentType.values.any(
            (candidate) => candidate.name == rawType,
          )
          ? rawType!
          : imageBytes != null
          ? ClipboardContentType.image.name
          : ContentClassifier.classify(normalized).name;
      final values = _knownValues(record, itemColumns)
        ..remove('image_data')
        ..remove('image_extension')
        ..['id'] = archiveId
        ..['content'] = content
        ..['normalized_content'] = normalized
        ..['content_hash'] = hash
        ..['content_type'] = type
        ..['is_vault'] = 0
        ..putIfAbsent('created_at', () => now)
        ..putIfAbsent('updated_at', () => now)
        ..putIfAbsent('last_copied_at', () => now)
        ..putIfAbsent('is_pinned', () => 0)
        ..putIfAbsent('is_sensitive', () => 0)
        ..putIfAbsent('copy_count', () => 1)
        ..putIfAbsent('contains_url', () => 0)
        ..putIfAbsent('has_ocr_text', () => 0)
        ..putIfAbsent('searchable_text', () => normalized);

      if (imageBytes != null) {
        try {
          final extension = _safeImageExtension(
            record['image_extension']?.toString(),
          );
          final image = File(p.join(imageDirectory.path, '$hash.$extension'));
          await image.writeAsBytes(imageBytes, flush: true);
          values['image_path'] = image.path;
        } on Object {
          values['image_path'] = null;
        }
      } else {
        values['image_path'] = null;
      }

      final inserted = await db.insert(
        'clipboard_items',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (inserted > 0) importedItems++;
      final resolved = await db.query(
        'clipboard_items',
        columns: ['id'],
        where: 'id = ? OR content_hash = ?',
        whereArgs: [archiveId, hash],
        limit: 1,
      );
      if (resolved.isNotEmpty) {
        itemIdMap[archiveId] = resolved.single['id']! as String;
      }
    }

    for (final record in _mapRecords(history['memberships'])) {
      final itemId = itemIdMap[record['clipboard_item_id']?.toString()];
      final collectionId = collectionIdMap[record['collection_id']?.toString()];
      if (itemId == null || collectionId == null) continue;
      final values = _knownValues(record, membershipColumns)
        ..['clipboard_item_id'] = itemId
        ..['collection_id'] = collectionId
        ..putIfAbsent('created_at', () => now);
      await db.insert(
        'clipboard_item_collections',
        values,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    return importedItems;
  }

  Iterable<Map<String, dynamic>> _mapRecords(Object? value) sync* {
    if (value is! List) return;
    for (final record in value) {
      if (record is Map) {
        yield record.map((key, value) => MapEntry(key.toString(), value));
      }
    }
  }

  Future<Set<String>> _tableColumns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((row) => row['name'] as String).toSet();
  }

  Map<String, Object?> _knownValues(
    Map<String, dynamic> source,
    Set<String> columns,
  ) => {
    for (final entry in source.entries)
      if (columns.contains(entry.key) &&
          (entry.value is String || entry.value is num || entry.value == null))
        entry.key: entry.value,
  };

  Future<Directory> _importImageDirectory(AppDatabase database) async {
    final base = database.databasePath == inMemoryDatabasePath
        ? Directory(p.join(Directory.systemTemp.path, 'clipflow_import_images'))
        : Directory(
            p.join(p.dirname(database.databasePath), 'clipboard_images'),
          );
    await base.create(recursive: true);
    return base;
  }

  String _safeImageExtension(String? value) {
    final normalized = value?.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return const {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
        }.contains(normalized)
        ? normalized!
        : 'png';
  }

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  Uint8List _pbkdf2(
    String password,
    Uint8List salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final result = Uint8List(keyLength);
    var blockIndex = 1;
    var offset = 0;

    while (offset < keyLength) {
      final blockIndexBytes = ByteData(4)..setUint32(0, blockIndex, Endian.big);
      final buffer = Uint8List.fromList([
        ...salt,
        ...blockIndexBytes.buffer.asUint8List(),
      ]);
      var u = hmac.convert(buffer).bytes;
      final block = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < block.length; j++) {
          block[j] ^= u[j];
        }
      }

      final bytesToCopy = (keyLength - offset < block.length)
          ? (keyLength - offset)
          : block.length;
      result.setRange(offset, offset + bytesToCopy, block);
      offset += bytesToCopy;
      blockIndex++;
    }

    return result;
  }

  Uint8List _encryptStream(List<int> input, Uint8List key, Uint8List iv) {
    final output = Uint8List(input.length);
    var counter = 0;
    var keystream = <int>[];
    var keystreamPos = 0;

    for (var i = 0; i < input.length; i++) {
      if (keystreamPos >= keystream.length) {
        final counterBytes = ByteData(4)..setUint32(0, counter++, Endian.big);
        final blockInput = [
          ...key,
          ...iv,
          ...counterBytes.buffer.asUint8List(),
        ];
        keystream = sha256.convert(blockInput).bytes;
        keystreamPos = 0;
      }

      output[i] = input[i] ^ keystream[keystreamPos++];
    }

    return output;
  }

  String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Uint8List _fromHex(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      final str = hex.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(str, radix: 16);
    }
    return bytes;
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  Uint8List _createZip(List<_ZipEntry> entries) {
    final builder = BytesBuilder();
    final cdBuilder = BytesBuilder();
    var offset = 0;

    for (final entry in entries) {
      final nameBytes = utf8.encode(entry.filename);
      final crc = _crc32(entry.content);
      final size = entry.content.length;

      final header = ByteData(30);
      header.setUint32(0, 0x04034b50, Endian.little);
      header.setUint16(4, 20, Endian.little);
      header.setUint16(6, 0, Endian.little);
      header.setUint16(8, 0, Endian.little);
      header.setUint16(10, 0, Endian.little);
      header.setUint16(12, 0, Endian.little);
      header.setUint32(14, crc, Endian.little);
      header.setUint32(18, size, Endian.little);
      header.setUint32(22, size, Endian.little);
      header.setUint16(26, nameBytes.length, Endian.little);
      header.setUint16(28, 0, Endian.little);

      builder.add(header.buffer.asUint8List());
      builder.add(nameBytes);
      builder.add(entry.content);

      final cdHeader = ByteData(46);
      cdHeader.setUint32(0, 0x02014b50, Endian.little);
      cdHeader.setUint16(4, 20, Endian.little);
      cdHeader.setUint16(6, 20, Endian.little);
      cdHeader.setUint16(8, 0, Endian.little);
      cdHeader.setUint16(10, 0, Endian.little);
      cdHeader.setUint16(12, 0, Endian.little);
      cdHeader.setUint16(14, 0, Endian.little);
      cdHeader.setUint32(16, crc, Endian.little);
      cdHeader.setUint32(20, size, Endian.little);
      cdHeader.setUint32(24, size, Endian.little);
      cdHeader.setUint16(28, nameBytes.length, Endian.little);
      cdHeader.setUint16(30, 0, Endian.little);
      cdHeader.setUint16(32, 0, Endian.little);
      cdHeader.setUint16(34, 0, Endian.little);
      cdHeader.setUint16(36, 0, Endian.little);
      cdHeader.setUint32(38, 0, Endian.little);
      cdHeader.setUint32(42, offset, Endian.little);

      cdBuilder.add(cdHeader.buffer.asUint8List());
      cdBuilder.add(nameBytes);

      offset += 30 + nameBytes.length + size;
    }

    final cdOffset = offset;
    final cdBytes = cdBuilder.toBytes();
    builder.add(cdBytes);

    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little);
    eocd.setUint16(4, 0, Endian.little);
    eocd.setUint16(6, 0, Endian.little);
    eocd.setUint16(8, entries.length, Endian.little);
    eocd.setUint16(10, entries.length, Endian.little);
    eocd.setUint32(12, cdBytes.length, Endian.little);
    eocd.setUint32(16, cdOffset, Endian.little);
    eocd.setUint16(20, 0, Endian.little);

    builder.add(eocd.buffer.asUint8List());

    return builder.toBytes();
  }

  Map<String, Uint8List> _readZip(Uint8List bytes) {
    final result = <String, Uint8List>{};
    var offset = 0;

    while (offset + 30 <= bytes.length) {
      final sig = ByteData.sublistView(
        bytes,
        offset,
        offset + 4,
      ).getUint32(0, Endian.little);
      if (sig != 0x04034b50) break;

      final compSize = ByteData.sublistView(
        bytes,
        offset + 18,
        offset + 22,
      ).getUint32(0, Endian.little);
      final filenameLen = ByteData.sublistView(
        bytes,
        offset + 26,
        offset + 28,
      ).getUint16(0, Endian.little);
      final extraLen = ByteData.sublistView(
        bytes,
        offset + 28,
        offset + 30,
      ).getUint16(0, Endian.little);

      final filenameStart = offset + 30;
      final dataStart = filenameStart + filenameLen + extraLen;

      if (dataStart + compSize > bytes.length) break;

      final filename = utf8.decode(
        bytes.sublist(filenameStart, filenameStart + filenameLen),
      );
      final data = bytes.sublist(dataStart, dataStart + compSize);

      result[filename] = Uint8List.fromList(data);
      offset = dataStart + compSize;
    }

    return result;
  }

  int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var j = 0; j < 8; j++) {
        final mask = -(crc & 1);
        crc = (crc >> 1) ^ (0xEDB88320 & mask);
      }
    }
    return ~crc & 0xFFFFFFFF;
  }
}

class _ZipEntry {
  const _ZipEntry(this.filename, this.content);

  final String filename;
  final List<int> content;
}
