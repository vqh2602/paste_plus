import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_item.dart';
import '../domain/clipboard_payload.dart';
import '../domain/clipboard_repository.dart';
import '../domain/content_classifier.dart';

class SqliteClipboardRepository implements ClipboardRepository {
  SqliteClipboardRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  Database get _db => _appDatabase.database;

  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
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
    return rows.map(ClipboardItem.fromMap).toList(growable: false);
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

    final normalized = payload.text == null
        ? ''
        : ContentNormalizer.normalize(payload.text!);
    if (payload.imageBytes == null &&
        (normalized.length < settings.minTextLength ||
            normalized.length > settings.maxTextLength)) {
      return null;
    }
    if (payload.imageBytes != null &&
        payload.imageBytes!.length > settings.maxImageMb * 1024 * 1024) {
      return null;
    }
    if (settings.ignoreSensitive &&
        SensitiveContentDetector.isSensitive(
          normalized,
          ignoreOtp: settings.ignoreOtp,
          ignoreLongToken: settings.ignoreLongToken,
        )) {
      return null;
    }

    final contentType = payload.imageBytes == null
        ? ContentClassifier.classify(normalized)
        : ClipboardContentType.image;
    if (!settings.allowedTypes.contains(contentType.name)) return null;
    final hashBytes =
        payload.imageBytes ?? Uint8List.fromList(utf8.encode(normalized));
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
        final existing = ClipboardItem.fromMap(matches.first);
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

    final imagePath = payload.imageBytes == null
        ? null
        : await _saveImage(hash, payload.imageBytes!);
    final id = '${now.microsecondsSinceEpoch}-${hash.substring(0, 8)}';
    final item = ClipboardItem(
      id: id,
      content: payload.text ?? '',
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
    );
    await _db.insert('clipboard_items', item.toMap());
    return item;
  }

  Future<String> _saveImage(String hash, Uint8List bytes) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'clipboard_images'));
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
    await _db.update(
      'clipboard_items',
      {
        'metadata_json': metadataJson,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final rows = await _db.query(
      'clipboard_items',
      columns: ['image_path'],
      where: includePinned ? null : 'is_pinned = 0',
    );
    await _db.transaction((transaction) async {
      await transaction.delete(
        'clipboard_items',
        where: includePinned ? null : 'is_pinned = 0',
      );
    });
    for (final row in rows) {
      await _deleteImage(row['image_path'] as String?);
    }
  }

  Future<void> _deleteImage(String? path) async {
    if (path == null) return;
    final file = File(path);
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
  Future<void> renameCollection(String id, String name) async {
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
    await _db.delete(
      'clipboard_item_collections',
      where: 'collection_id = ?',
      whereArgs: [id],
    );
    await _db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> addToCollection(String itemId, String collectionId) async {
    await _db.insert('clipboard_item_collections', {
      'clipboard_item_id': itemId,
      'collection_id': collectionId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<void> removeFromCollection(String itemId, String collectionId) {
    return _db.delete(
      'clipboard_item_collections',
      where: 'clipboard_item_id = ? AND collection_id = ?',
      whereArgs: [itemId, collectionId],
    );
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

  @override
  Future<void> cleanup(AppSettings settings) async {
    final eligibility = <String>[
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
      if (imagePath != null) {
        final imageFile = File(imagePath);
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
      where: 'image_path IS NOT NULL',
    );
    for (final row in rows) {
      final path = row['image_path'] as String?;
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) total += await file.length();
    }
    return total;
  }
}
