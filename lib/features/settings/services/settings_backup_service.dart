import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../domain/app_settings.dart';

class SettingsBackupResult {
  const SettingsBackupResult.success([this.settings])
    : isSuccess = true,
      errorMessage = null;

  const SettingsBackupResult.failure(this.errorMessage)
    : isSuccess = false,
      settings = null;

  final bool isSuccess;
  final String? errorMessage;
  final AppSettings? settings;
}

class SettingsBackupService {
  const SettingsBackupService();

  /// Export AppSettings into password-protected .clipflow zip file
  Future<SettingsBackupResult> exportSettings({
    required AppSettings settings,
    required String password,
    required String filePath,
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
        'format': 'clipflow_config_v1',
        'app': 'ClipFlow',
        'version': '1.0.4',
        'created_at': DateTime.now().toIso8601String(),
        'salt': _toHex(salt),
        'iv': _toHex(iv),
        'hmac': _toHex(hmac),
      };

      final manifestBytes = utf8.encode(jsonEncode(manifestMap));

      final zipBytes = _createZip([
        _ZipEntry('manifest.json', manifestBytes),
        _ZipEntry('settings.enc', ciphertext),
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

      return SettingsBackupResult.success(settings);
    } on FormatException catch (_) {
      return const SettingsBackupResult.failure(
        'Mật khẩu không đúng hoặc nội dung giải mã không hợp lệ.',
      );
    } on Object catch (e) {
      return SettingsBackupResult.failure('Không thể đọc tệp cấu hình: $e');
    }
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
