import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../settings/domain/app_settings.dart';
import '../../vault/services/vault_crypto.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_feature_extractor.dart';
import '../domain/clipboard_item.dart';
import '../domain/clipboard_payload.dart';
import '../domain/clipboard_repository.dart';
import '../domain/content_classifier.dart';
import '../domain/search_query.dart';

class SqliteClipboardRepository
    implements
        ClipboardRepository,
        StructuredClipboardRepository,
        EditableClipboardRepository,
        VaultClipboardRepository {
  SqliteClipboardRepository(this._appDatabase, {VaultCrypto? vaultCrypto})
    : _vaultCrypto = vaultCrypto;

  final AppDatabase _appDatabase;
  final VaultCrypto? _vaultCrypto;
  final Set<String> _vaultPreviewPaths = <String>{};
  Database get _db => _appDatabase.database;

  Future<String?> _resolveImagePath(String? path) async {
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (await file.exists()) return path;

    if (_appDatabase.databasePath == inMemoryDatabasePath) return path;

    final supportPath = p.dirname(_appDatabase.databasePath);
    final filename = p.basename(path);
    final candidatePath = p.join(supportPath, 'clipboard_images', filename);
    final candidateFile = File(candidatePath);

    if (await candidateFile.exists()) {
      return candidatePath;
    }

    return path;
  }

  Future<Map<String, Object?>> _normalizeRow(Map<String, Object?> row) async {
    final rawPath = row['image_path'] as String?;
    if (rawPath == null || rawPath.isEmpty) return row;

    final resolved = await _resolveImagePath(rawPath);
    if (resolved == rawPath) return row;

    final mutable = Map<String, Object?>.from(row);
    mutable['image_path'] = resolved;

    if (resolved != null && row['id'] != null) {
      unawaited(
        _db.update(
          'clipboard_items',
          {'image_path': resolved},
          where: 'id = ?',
          whereArgs: [row['id']],
        ),
      );
    }

    return mutable;
  }

  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    final loadingVault = collectionId == ClipboardCollection.vaultId;
    if (loadingVault && _vaultCrypto?.isUnlocked != true) {
      throw const VaultLockedException();
    }
    where.add(loadingVault ? 'i.is_vault = 1' : 'i.is_vault = 0');
    if (pinnedOnly) where.add('i.is_pinned = 1');
    if (type != null) {
      where.add('i.content_type = ?');
      args.add(type.name);
    }
    if (collectionId != null) {
      where.add('ic.collection_id = ?');
      args.add(collectionId);
    }
    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT i.* FROM clipboard_items i
      ${collectionId == null ? '' : 'INNER JOIN clipboard_item_collections ic ON ic.clipboard_item_id = i.id'}
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY i.last_copied_at DESC
      LIMIT ?
      ''',
      [...args, limit],
    );
    final items = <ClipboardItem>[];
    for (final row in rows) {
      items.add(await _itemFromRow(row));
    }
    return items;
  }

  Future<ClipboardItem> _itemFromRow(Map<String, Object?> row) async {
    if ((row['is_vault'] as int? ?? 0) == 0) {
      return ClipboardItem.fromMap(await _normalizeRow(row));
    }
    final crypto = _vaultCrypto;
    if (crypto == null || !crypto.isUnlocked) {
      throw const VaultLockedException();
    }
    final clear = Map<String, Object?>.from(row);
    for (final field in _vaultEncryptedFields) {
      final value = clear[field] as String?;
      if (value != null && value.isNotEmpty) {
        clear[field] = await crypto.decryptString(value);
      }
    }
    final encryptedImagePath = row['image_path'] as String?;
    if (encryptedImagePath != null && encryptedImagePath.isNotEmpty) {
      clear['image_path'] = await _createVaultPreview(
        row['id']! as String,
        encryptedImagePath,
      );
    }
    return ClipboardItem.fromMap(clear);
  }

  Future<String> _createVaultPreview(
    String itemId,
    String encryptedPath,
  ) async {
    final crypto = _vaultCrypto!;
    final source = File(encryptedPath);
    if (!await source.exists()) return encryptedPath;
    final directory = Directory(
      p.join(Directory.systemTemp.path, 'clipflow_vault_preview'),
    );
    await directory.create(recursive: true);
    final preview = File(p.join(directory.path, '$itemId.png'));
    final clearBytes = await crypto.decryptBytes(await source.readAsBytes());
    await preview.writeAsBytes(clearBytes, flush: true);
    _vaultPreviewPaths.add(preview.path);
    return preview.path;
  }

  @override
  Future<ClipboardItem?> store(
    ClipboardPayload payload,
    AppSettings settings,
  ) async {
    if (payload.isEmpty) return null;
    final source = payload.sourceAppName;
    if (source != null &&
        settings.excludedApplications.any(
          (app) => source.toLowerCase().contains(app.toLowerCase()),
        )) {
      return null;
    }
    if (settings.protectSensitiveWindows && payload.sensitiveContext) {
      return null;
    }

    final payloadText = payload.filePaths.isEmpty
        ? payload.text
        : payload.filePaths.join('\n');
    final imageBytes = payload.filePaths.isEmpty ? payload.imageBytes : null;
    final normalized = payloadText == null
        ? ''
        : ContentNormalizer.normalize(payloadText);
    if (imageBytes == null &&
        (normalized.length < settings.minTextLength ||
            normalized.length > settings.maxTextLength)) {
      return null;
    }
    if (imageBytes != null &&
        imageBytes.length > settings.maxImageMb * 1024 * 1024) {
      return null;
    }
    if (settings.ignoreSensitive &&
        SensitiveContentDetector.isSensitive(
          normalized,
          ignoreOtp: settings.ignoreOtp,
          ignoreLongToken: settings.ignoreLongToken,
          ignoreFinancialAndIdentity: settings.ignoreFinancialAndIdentity,
        )) {
      return null;
    }

    final contentType = payload.filePaths.isNotEmpty
        ? ClipboardContentType.file
        : imageBytes == null
        ? ContentClassifier.classify(normalized)
        : ClipboardContentType.image;
    if (!settings.allowedTypes.contains(contentType.name)) return null;
    final hashBytes = imageBytes ?? Uint8List.fromList(utf8.encode(normalized));
    final hash = sha256.convert(hashBytes).toString();
    final now = DateTime.now();

    if (settings.ignoreDuplicates) {
      final matches = await _db.query(
        'clipboard_items',
        where: 'content_hash = ?',
        whereArgs: [hash],
        limit: 1,
      );
      if (matches.isNotEmpty) {
        final normalizedRow = await _normalizeRow(matches.first);
        final existing = ClipboardItem.fromMap(normalizedRow);
        if (settings.duplicateBehavior != DuplicateBehavior.createNew) {
          final values = <String, Object?>{
            'updated_at': now.millisecondsSinceEpoch,
            'last_copied_at':
                settings.duplicateBehavior == DuplicateBehavior.bringToTop
                ? now.millisecondsSinceEpoch
                : existing.lastCopiedAt.millisecondsSinceEpoch,
            'copy_count': existing.copyCount + 1,
          };
          await _db.update(
            'clipboard_items',
            values,
            where: 'id = ?',
            whereArgs: [existing.id],
          );
          return existing.copyWith(
            lastCopiedAt:
                settings.duplicateBehavior == DuplicateBehavior.bringToTop
                ? now
                : existing.lastCopiedAt,
            copyCount: existing.copyCount + 1,
          );
        }
      }
    }

    final imagePath = imageBytes == null
        ? null
        : await _saveImage(hash, imageBytes);
    final features = const ClipboardFeatureExtractor().extract(
      content: payloadText ?? '',
      contentType: contentType,
      imagePath: imagePath,
      sourceAppName: payload.sourceAppName,
    );
    final id = '${now.microsecondsSinceEpoch}-${hash.substring(0, 8)}';
    final item = ClipboardItem(
      id: id,
      content: payloadText ?? '',
      normalizedContent: normalized,
      contentHash: hash,
      contentType: contentType,
      createdAt: now,
      updatedAt: now,
      lastCopiedAt: now,
      sourceAppName: payload.sourceAppName,
      sourceAppIdentifier: payload.sourceAppIdentifier,
      isPinned: false,
      isSensitive: false,
      imagePath: imagePath,
      copyCount: 1,
      containsUrl: features.containsUrl,
      primaryUrl: features.primaryUrl,
      urlHost: features.urlHost,
      urlKind: features.urlKind?.name,
      mimeType: features.mimeType,
      fileExtension: features.fileExtension,
      hasOcrText: features.hasOcrText,
      searchableText: features.searchableText,
    );
    await _db.insert('clipboard_items', item.toMap());
    return item;
  }

  Future<String> _saveImage(String hash, Uint8List bytes) async {
    final supportPath = _appDatabase.databasePath == inMemoryDatabasePath
        ? (await getApplicationSupportDirectory()).path
        : p.dirname(_appDatabase.databasePath);
    final directory = Directory(p.join(supportPath, 'clipboard_images'));
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '$hash.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<void> markCopied(String id) async {
    final rows = await _db.query(
      'clipboard_items',
      columns: ['copy_count'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'clipboard_items',
      {
        'last_copied_at': now,
        'updated_at': now,
        'copy_count': (rows.first['copy_count'] as int? ?? 1) + 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> setPinned(String id, bool pinned) async {
    await _db.update(
      'clipboard_items',
      {
        'is_pinned': pinned ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateMetadata(String id, String metadataJson) async {
    final rows = await _db.query(
      'clipboard_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final values = <String, Object?>{
      'metadata_json': metadataJson,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (rows.isNotEmpty) {
      if (_isVaultRow(rows.first)) {
        values['metadata_json'] = await _encryptNullable(metadataJson);
      } else {
        final item = await _itemFromRow(rows.first);
        final features = const ClipboardFeatureExtractor().extract(
          content: item.content,
          contentType: item.contentType,
          imagePath: item.imagePath,
          metadataJson: metadataJson,
          note: item.note,
          sourceAppName: item.sourceAppName,
        );
        values.addAll(_featureValues(features));
      }
    }
    await _db.update(
      'clipboard_items',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateNote(String id, String? note) async {
    final trimmed = note?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final rows = await _db.query(
      'clipboard_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final values = <String, Object?>{
      'note': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (rows.isNotEmpty) {
      if (_isVaultRow(rows.first)) {
        values['note'] = await _encryptNullable(value);
      } else {
        final item = await _itemFromRow(rows.first);
        final features = const ClipboardFeatureExtractor().extract(
          content: item.content,
          contentType: item.contentType,
          imagePath: item.imagePath,
          metadataJson: item.metadataJson,
          note: value,
          sourceAppName: item.sourceAppName,
        );
        values.addAll(_featureValues(features));
      }
    }
    await _db.update(
      'clipboard_items',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<ClipboardItem> updateItemContent(
    ClipboardItem item, {
    required String content,
    Uint8List? imageBytes,
  }) async {
    final rows = await _db.query(
      'clipboard_items',
      where: 'id = ?',
      whereArgs: [item.id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Clipboard item ${item.id} no longer exists.');
    }

    final vaultItem = _isVaultRow(rows.first);
    final stored = await _itemFromRow(rows.first);
    final editingImage = imageBytes != null;
    final normalized = editingImage
        ? content
        : ContentNormalizer.normalize(content);
    if (!editingImage && normalized.isEmpty) {
      throw ArgumentError.value(content, 'content', 'Content cannot be empty.');
    }

    final contentType = editingImage
        ? ClipboardContentType.image
        : ContentClassifier.classify(normalized);
    final hashBytes = editingImage
        ? imageBytes
        : Uint8List.fromList(utf8.encode(normalized));
    final hash = sha256.convert(hashBytes).toString();
    final oldImagePath = vaultItem
        ? rows.first['image_path'] as String?
        : stored.imagePath;
    var imagePath = editingImage
        ? await _saveImage(hash, imageBytes)
        : oldImagePath;
    String? pendingPlainImagePath;
    if (vaultItem && editingImage && imagePath != null) {
      pendingPlainImagePath = imagePath;
      imagePath = await _encryptImageFile(item.id, imagePath);
    }
    final features = const ClipboardFeatureExtractor().extract(
      content: editingImage ? content : normalized,
      contentType: contentType,
      imagePath: vaultItem && !editingImage ? stored.imagePath : imagePath,
      metadataJson: stored.metadataJson,
      note: stored.note,
      sourceAppName: stored.sourceAppName,
    );
    var values = <String, Object?>{
      'content': editingImage ? content : normalized,
      'normalized_content': normalized,
      'content_hash': hash,
      'content_type': contentType.name,
      'image_path': imagePath,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      ..._featureValues(features),
    };
    if (vaultItem) {
      values = await _encryptVaultValues(values);
      values
        ..['contains_url'] = 0
        ..['primary_url'] = await _encryptNullable(features.primaryUrl)
        ..['url_host'] = await _encryptNullable(features.urlHost)
        ..['url_kind'] = await _encryptNullable(features.urlKind?.name)
        ..['mime_type'] = await _encryptNullable(features.mimeType)
        ..['file_extension'] = await _encryptNullable(features.fileExtension)
        ..['has_ocr_text'] = 0
        ..['searchable_text'] = ''
        ..['is_vault'] = 1;
    }
    await _db.update(
      'clipboard_items',
      values,
      where: 'id = ?',
      whereArgs: [item.id],
    );
    if (editingImage && oldImagePath != null && oldImagePath != imagePath) {
      await _deleteImage(oldImagePath);
    }
    if (pendingPlainImagePath != null) {
      await _deleteImage(pendingPlainImagePath);
    }

    final updatedRows = await _db.query(
      'clipboard_items',
      where: 'id = ?',
      whereArgs: [item.id],
      limit: 1,
    );
    return _itemFromRow(updatedRows.single);
  }

  @override
  Future<void> deleteItem(String id) async {
    final rows = await _db.query(
      'clipboard_items',
      columns: ['image_path'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await _db.transaction((transaction) async {
      await transaction.delete(
        'clipboard_items',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    if (rows.isNotEmpty) {
      await _deleteImage(rows.first['image_path'] as String?);
    }
  }

  @override
  Future<void> clearHistory({bool includePinned = false}) async {
    final where = includePinned
        ? 'is_vault = 0'
        : 'is_pinned = 0 AND is_vault = 0';
    final rows = await _db.query(
      'clipboard_items',
      columns: ['image_path'],
      where: where,
    );
    await _db.transaction((transaction) async {
      await transaction.delete('clipboard_items', where: where);
    });
    for (final row in rows) {
      await _deleteImage(row['image_path'] as String?);
    }
  }

  Future<void> _deleteImage(String? path) async {
    final resolved = await _resolveImagePath(path);
    if (resolved == null) return;
    final file = File(resolved);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<ClipboardCollection>> getCollections() async {
    final rows = await _db.query('collections', orderBy: 'sort_order, name');
    return rows.map(ClipboardCollection.fromMap).toList(growable: false);
  }

  @override
  Future<ClipboardCollection> createCollection(String name) async {
    final now = DateTime.now();
    final id = 'collection-${now.microsecondsSinceEpoch}';
    final values = {
      'id': id,
      'name': name.trim(),
      'icon': 'folder',
      'created_at': now.millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
      'sort_order': now.millisecondsSinceEpoch,
    };
    await _db.insert('collections', values);
    return ClipboardCollection.fromMap(values);
  }

  @override
  Future<void> upsertCollection(ClipboardCollection collection) async {
    if (collection.isVault) return;
    final value = collection.toMap();
    await _db.rawInsert(
      '''
      INSERT INTO collections
        (id, name, icon, created_at, updated_at, sort_order)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        icon = excluded.icon,
        updated_at = excluded.updated_at,
        sort_order = excluded.sort_order
      WHERE excluded.updated_at >= collections.updated_at
      ''',
      [
        value['id'],
        value['name'],
        value['icon'],
        value['created_at'],
        value['updated_at'],
        value['sort_order'],
      ],
    );
  }

  @override
  Future<void> renameCollection(String id, String name) async {
    if (id == ClipboardCollection.vaultId) return;
    await _db.update(
      'collections',
      {
        'name': name.trim(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteCollection(String id) async {
    if (id == ClipboardCollection.vaultId) return;
    await _db.delete(
      'clipboard_item_collections',
      where: 'collection_id = ?',
      whereArgs: [id],
    );
    await _db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> addToCollection(String itemId, String collectionId) async {
    if (collectionId == ClipboardCollection.vaultId) {
      await _moveToVault(itemId);
      return;
    }
    if (await _itemIsVault(itemId)) {
      await _restoreFromVault(itemId, collectionId: collectionId);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((transaction) async {
      await transaction.insert('clipboard_item_collections', {
        'clipboard_item_id': itemId,
        'collection_id': collectionId,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await transaction.update(
        'clipboard_items',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [itemId],
      );
    });
  }

  @override
  Future<void> removeFromCollection(String itemId, String collectionId) async {
    if (collectionId == ClipboardCollection.vaultId) {
      await _restoreFromVault(itemId);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((transaction) async {
      await transaction.delete(
        'clipboard_item_collections',
        where: 'clipboard_item_id = ? AND collection_id = ?',
        whereArgs: [itemId, collectionId],
      );
      await transaction.update(
        'clipboard_items',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [itemId],
      );
    });
  }

  @override
  Future<Set<String>> collectionIdsForItem(String itemId) async {
    final rows = await _db.query(
      'clipboard_item_collections',
      columns: ['collection_id'],
      where: 'clipboard_item_id = ?',
      whereArgs: [itemId],
    );
    return rows.map((row) => row['collection_id']! as String).toSet();
  }

  Future<bool> _itemIsVault(String itemId) async {
    final rows = await _db.query(
      'clipboard_items',
      columns: ['is_vault'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    return rows.isNotEmpty && (rows.first['is_vault'] as int? ?? 0) == 1;
  }

  Future<void> _moveToVault(String itemId) async {
    final crypto = _vaultCrypto;
    if (crypto == null || !crypto.isUnlocked) {
      throw const VaultLockedException();
    }
    final rows = await _db.query(
      'clipboard_items',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty || _isVaultRow(rows.first)) return;
    final row = rows.first;
    final imagePath = row['image_path'] as String?;
    final encryptedImagePath = imagePath == null || imagePath.isEmpty
        ? null
        : await _encryptImageFile(itemId, imagePath);
    final values = await _encryptVaultValues(
      Map<String, Object?>.fromEntries(
        _vaultEncryptedFields.map((field) => MapEntry(field, row[field])),
      ),
    );
    values
      ..['image_path'] = encryptedImagePath
      ..['contains_url'] = 0
      ..['has_ocr_text'] = 0
      ..['searchable_text'] = ''
      ..['is_vault'] = 1
      ..['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((transaction) async {
      await transaction.delete(
        'clipboard_item_collections',
        where: 'clipboard_item_id = ?',
        whereArgs: [itemId],
      );
      await transaction.update(
        'clipboard_items',
        values,
        where: 'id = ?',
        whereArgs: [itemId],
      );
      await transaction.insert('clipboard_item_collections', {
        'clipboard_item_id': itemId,
        'collection_id': ClipboardCollection.vaultId,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    if (imagePath != null && imagePath != encryptedImagePath) {
      await _deleteImage(imagePath);
    }
  }

  Future<void> _restoreFromVault(String itemId, {String? collectionId}) async {
    final crypto = _vaultCrypto;
    if (crypto == null || !crypto.isUnlocked) {
      throw const VaultLockedException();
    }
    final rows = await _db.query(
      'clipboard_items',
      where: 'id = ? AND is_vault = 1',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final clear = Map<String, Object?>.from(row);
    for (final field in _vaultEncryptedFields) {
      final value = clear[field] as String?;
      if (value != null && value.isNotEmpty) {
        clear[field] = await crypto.decryptString(value);
      }
    }
    final encryptedImagePath = row['image_path'] as String?;
    String? restoredImagePath;
    if (encryptedImagePath != null && encryptedImagePath.isNotEmpty) {
      restoredImagePath = await _decryptImageFile(
        itemId,
        clear['content_hash']! as String,
        encryptedImagePath,
      );
    }
    final contentType = ClipboardContentType.fromDatabase(
      clear['content_type']! as String,
    );
    final features = const ClipboardFeatureExtractor().extract(
      content: clear['content'] as String? ?? '',
      contentType: contentType,
      imagePath: restoredImagePath,
      metadataJson: clear['metadata_json'] as String?,
      note: clear['note'] as String?,
      sourceAppName: clear['source_app_name'] as String?,
    );
    final values = <String, Object?>{
      for (final field in _vaultEncryptedFields) field: clear[field],
      'image_path': restoredImagePath,
      ..._featureValues(features),
      'is_vault': 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((transaction) async {
      await transaction.delete(
        'clipboard_item_collections',
        where: 'clipboard_item_id = ?',
        whereArgs: [itemId],
      );
      await transaction.update(
        'clipboard_items',
        values,
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (collectionId != null) {
        await transaction.insert(
          'clipboard_item_collections',
          {
            'clipboard_item_id': itemId,
            'collection_id': collectionId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    if (encryptedImagePath != null) {
      await _deleteImage(encryptedImagePath);
    }
  }

  Future<String> _encryptImageFile(String itemId, String path) async {
    final crypto = _vaultCrypto!;
    final source = File(path);
    final encrypted = await crypto.encryptBytes(await source.readAsBytes());
    final supportPath = _appDatabase.databasePath == inMemoryDatabasePath
        ? (await getApplicationSupportDirectory()).path
        : p.dirname(_appDatabase.databasePath);
    final directory = Directory(p.join(supportPath, 'vault_files'));
    await directory.create(recursive: true);
    final target = File(p.join(directory.path, '$itemId.cfv'));
    await target.writeAsBytes(encrypted, flush: true);
    return target.path;
  }

  Future<String> _decryptImageFile(
    String itemId,
    String hash,
    String encryptedPath,
  ) async {
    final encrypted = await File(encryptedPath).readAsBytes();
    final clear = await _vaultCrypto!.decryptBytes(encrypted);
    final supportPath = _appDatabase.databasePath == inMemoryDatabasePath
        ? (await getApplicationSupportDirectory()).path
        : p.dirname(_appDatabase.databasePath);
    final directory = Directory(p.join(supportPath, 'clipboard_images'));
    await directory.create(recursive: true);
    final target = File(p.join(directory.path, '$hash-$itemId.png'));
    await target.writeAsBytes(clear, flush: true);
    return target.path;
  }

  bool _isVaultRow(Map<String, Object?> row) =>
      (row['is_vault'] as int? ?? 0) == 1;

  Future<String?> _encryptNullable(String? value) async {
    if (value == null || value.isEmpty) return value;
    final crypto = _vaultCrypto;
    if (crypto == null) throw const VaultLockedException();
    return crypto.encryptString(value);
  }

  Future<Map<String, Object?>> _encryptVaultValues(
    Map<String, Object?> values,
  ) async {
    final protected = Map<String, Object?>.from(values);
    for (final field in _vaultEncryptedFields) {
      if (!protected.containsKey(field)) continue;
      protected[field] = await _encryptNullable(protected[field] as String?);
    }
    return protected;
  }

  @override
  Future<void> clearVault() async {
    final rows = await _db.query(
      'clipboard_items',
      columns: ['image_path'],
      where: 'is_vault = 1',
    );
    await _db.delete('clipboard_items', where: 'is_vault = 1');
    for (final row in rows) {
      await _deleteImage(row['image_path'] as String?);
    }
    await clearVaultPreviews();
  }

  @override
  Future<void> disableVault() async {
    final rows = await _db.query(
      'clipboard_items',
      columns: ['id'],
      where: 'is_vault = 1',
    );
    for (final row in rows) {
      await _restoreFromVault(row['id']! as String);
    }
    await clearVaultPreviews();
  }

  @override
  Future<void> clearVaultPreviews() async {
    for (final path in _vaultPreviewPaths.toList(growable: false)) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _vaultPreviewPaths.clear();
  }

  @override
  Future<void> cleanup(AppSettings settings) async {
    final eligibility = <String>[
      'i.is_vault = 0',
      if (settings.protectPinned) 'i.is_pinned = 0',
      if (settings.protectCollections)
        '''NOT EXISTS (
          SELECT 1 FROM clipboard_item_collections ic
          WHERE ic.clipboard_item_id = i.id
        )''',
    ].join(' AND ');
    final eligibleWhere = eligibility.isEmpty ? '1 = 1' : eligibility;
    final ids = <String>[];
    if (settings.retentionDays > 0) {
      final cutoff = DateTime.now()
          .subtract(Duration(days: settings.retentionDays))
          .millisecondsSinceEpoch;
      final oldRows = await _db.rawQuery(
        '''SELECT i.id FROM clipboard_items i
           WHERE i.last_copied_at < ? AND $eligibleWhere''',
        [cutoff],
      );
      ids.addAll(oldRows.map((row) => row['id']! as String));
    }
    final overflow = await _db.rawQuery(
      '''
      SELECT i.id FROM clipboard_items i
      WHERE i.id NOT IN (
        SELECT id FROM clipboard_items ORDER BY last_copied_at DESC LIMIT ?
      ) AND $eligibleWhere
      ''',
      [settings.maxItems],
    );
    ids.addAll(overflow.map((row) => row['id']! as String));
    for (final id in ids.toSet()) {
      await deleteItem(id);
    }

    final maximumBytes = settings.maxDatabaseMb * 1024 * 1024;
    var currentBytes = await approximateStorageBytes();
    if (currentBytes <= maximumBytes) return;

    final sizeCandidates = await _db.rawQuery('''
      SELECT i.id, i.content, i.image_path
      FROM clipboard_items i
      WHERE $eligibleWhere
      ORDER BY
        ${settings.deleteImagesFirst ? 'CASE WHEN i.image_path IS NULL THEN 1 ELSE 0 END,' : ''}
        i.last_copied_at ASC
    ''');
    var removedForSize = false;
    for (final row in sizeCandidates) {
      if (currentBytes <= maximumBytes) break;
      var estimatedBytes =
          utf8.encode(row['content'] as String? ?? '').length * 2;
      final imagePath = row['image_path'] as String?;
      final resolved = await _resolveImagePath(imagePath);
      if (resolved != null) {
        final imageFile = File(resolved);
        if (await imageFile.exists()) {
          estimatedBytes += await imageFile.length();
        }
      }
      await deleteItem(row['id']! as String);
      currentBytes -= estimatedBytes.clamp(4096, currentBytes);
      removedForSize = true;
    }
    if (removedForSize && _appDatabase.databasePath != inMemoryDatabasePath) {
      await _db.execute('VACUUM');
    }
  }

  @override
  Future<int> approximateStorageBytes() async {
    var total = 0;
    if (_appDatabase.databasePath != inMemoryDatabasePath) {
      final file = File(_appDatabase.databasePath);
      if (await file.exists()) total += await file.length();
    }
    final rows = await _db.query(
      'clipboard_items',
      columns: ['image_path'],
      where: "image_path IS NOT NULL AND image_path != ''",
    );
    for (final row in rows) {
      final path = row['image_path'] as String?;
      final resolved = await _resolveImagePath(path);
      if (resolved == null) continue;
      final file = File(resolved);
      if (await file.exists()) total += await file.length();
    }
    return total;
  }

  Map<String, Object?> _featureValues(ClipboardFeatures features) => {
    'contains_url': features.containsUrl ? 1 : 0,
    'primary_url': features.primaryUrl,
    'url_host': features.urlHost,
    'url_kind': features.urlKind?.name,
    'mime_type': features.mimeType,
    'file_extension': features.fileExtension,
    'has_ocr_text': features.hasOcrText ? 1 : 0,
    'searchable_text': features.searchableText,
  };

  @override
  Future<ClipboardSearchPage> search(ClipboardSearchQuery query) async {
    final where = <String>['i.is_vault = 0'];
    final args = <Object?>[];
    var join = '';
    if (!query.includeSensitive) where.add('i.is_sensitive = 0');
    if (query.contentTypes.isNotEmpty) {
      where.add(
        'i.content_type IN (${List.filled(query.contentTypes.length, '?').join(',')})',
      );
      args.addAll(query.contentTypes.map((type) => type.name));
    }
    if (query.containsUrl != null) {
      where.add('i.contains_url = ?');
      args.add(query.containsUrl! ? 1 : 0);
    }
    if (query.urlHosts.isNotEmpty) {
      where.add(
        '(${query.urlHosts.map((_) => '(i.url_host = ? OR i.url_host LIKE ?)').join(' OR ')})',
      );
      for (final host in query.urlHosts) {
        args
          ..add(host)
          ..add('%.$host');
      }
    }
    if (query.urlKind != null && query.urlKind != ClipboardUrlKind.any) {
      where.add('i.url_kind = ?');
      args.add(query.urlKind!.name);
    }
    if (query.sourceApps.isNotEmpty) {
      where.add(
        '(${query.sourceApps.map((_) => 'LOWER(COALESCE(i.source_app_name, \'\')) LIKE ?').join(' OR ')})',
      );
      args.addAll(query.sourceApps.map((app) => '%${app.toLowerCase()}%'));
    }
    if (query.fileExtensions.isNotEmpty) {
      where.add(
        'i.file_extension IN (${List.filled(query.fileExtensions.length, '?').join(',')})',
      );
      args.addAll(query.fileExtensions);
    }
    if (query.pinned != null) {
      where.add('i.is_pinned = ?');
      args.add(query.pinned! ? 1 : 0);
    }
    if (query.collectionIds.isNotEmpty) {
      join =
          'INNER JOIN clipboard_item_collections ic ON ic.clipboard_item_id = i.id';
      where.add(
        'ic.collection_id IN (${List.filled(query.collectionIds.length, '?').join(',')})',
      );
      args.addAll(query.collectionIds);
    }
    final range = query.dateRange?.resolve(DateTime.now());
    if (range?.from != null) {
      where.add('i.created_at >= ?');
      args.add(range!.from!.millisecondsSinceEpoch);
    }
    if (range?.to != null) {
      where.add('i.created_at < ?');
      args.add(range!.to!.millisecondsSinceEpoch);
    }
    final text = query.textQuery?.trim().toLowerCase();
    if (text?.isNotEmpty == true) {
      for (final token
          in text!.split(RegExp(r'\s+')).where((value) => value.isNotEmpty)) {
        where.add('LOWER(i.searchable_text) LIKE ?');
        args.add('%$token%');
      }
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final countRows = await _db.rawQuery(
      'SELECT COUNT(DISTINCT i.id) AS total FROM clipboard_items i $join $whereSql',
      args,
    );
    final total = (countRows.firstOrNull?['total'] as int?) ?? 0;
    final orderBy = switch (query.sort) {
      ClipboardSort.oldest => 'i.created_at ASC',
      ClipboardSort.mostCopied => 'i.copy_count DESC, i.created_at DESC',
      ClipboardSort.recentlyCopied => 'i.last_copied_at DESC',
      ClipboardSort.newest => 'i.created_at DESC',
    };
    final rows = await _db.rawQuery(
      '''SELECT DISTINCT i.* FROM clipboard_items i $join $whereSql
         ORDER BY $orderBy LIMIT ? OFFSET ?''',
      [...args, query.limit, query.offset],
    );
    final items = <ClipboardItem>[];
    for (final row in rows) {
      items.add(ClipboardItem.fromMap(await _normalizeRow(row)));
    }
    return ClipboardSearchPage(
      items: items,
      total: total,
      hasMore: query.offset + items.length < total,
    );
  }

  @override
  Future<List<ClipboardItem>> getItemsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _db.query(
      'clipboard_items',
      where:
          'is_vault = 0 AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final byId = <String, ClipboardItem>{};
    for (final row in rows) {
      final item = ClipboardItem.fromMap(await _normalizeRow(row));
      byId[item.id] = item;
    }
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<void> setPinnedMany(List<String> ids, bool pinned) async {
    if (ids.isEmpty) return;
    await _db.update(
      'clipboard_items',
      {
        'is_pinned': pinned ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where:
          'is_vault = 0 AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  @override
  Future<void> deleteItems(List<String> ids) async {
    if (ids.isEmpty) return;
    final rows = await _db.query(
      'clipboard_items',
      columns: ['image_path'],
      where:
          'is_vault = 0 AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    await _db.delete(
      'clipboard_items',
      where:
          'is_vault = 0 AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    for (final row in rows) {
      await _deleteImage(row['image_path'] as String?);
    }
  }

  @override
  Future<void> addItemsToCollection(
    List<String> itemIds,
    String collectionId,
  ) async {
    if (itemIds.isEmpty) return;
    if (collectionId == ClipboardCollection.vaultId) {
      throw const VaultLockedException();
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final id in itemIds) {
        batch.insert(
          'clipboard_item_collections',
          {
            'clipboard_item_id': id,
            'collection_id': collectionId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
      await transaction.update(
        'clipboard_items',
        {'updated_at': now},
        where: 'id IN (${List.filled(itemIds.length, '?').join(',')})',
        whereArgs: itemIds,
      );
    });
  }

  @override
  Future<ClipboardCollection?> findCollectionByName(String name) async {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    // A visible name is what the user said, so it must win over an internal id
    // (seeded collections use ids such as "work" for localized names).
    final rows = await _db.rawQuery(
      '''SELECT * FROM collections
         WHERE id != ? AND (LOWER(name) = ? OR LOWER(id) = ?)
         ORDER BY CASE WHEN LOWER(name) = ? THEN 0 ELSE 1 END
         LIMIT 1''',
      [ClipboardCollection.vaultId, needle, needle, needle],
    );
    return rows.isEmpty ? null : ClipboardCollection.fromMap(rows.first);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

const _vaultEncryptedFields = <String>[
  'content',
  'normalized_content',
  'content_hash',
  'source_app_name',
  'source_app_identifier',
  'metadata_json',
  'note',
  'primary_url',
  'url_host',
  'url_kind',
  'mime_type',
  'file_extension',
];
