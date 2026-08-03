import 'dart:math';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database/app_database.dart';

class VectorMatch {
  const VectorMatch({
    required this.clipboardId,
    required this.score,
  });

  final String clipboardId;
  final double score;
}

/// Managing persistent vector embedding storage and SQLite vector candidate lookup.
class ClipboardVectorStore {
  ClipboardVectorStore([this._database]);

  final AppDatabase? _database;

  /// Encodes a List of doubles into Float32List bytes for SQLite BLOB storage.
  static Uint8List encodeVector(List<double> vector) {
    final floatList = Float32List.fromList(vector);
    return floatList.buffer.asUint8List();
  }

  /// Decodes SQLite BLOB bytes back into Float32List.
  static Float32List decodeVector(Uint8List blob) {
    final buffer = blob.buffer;
    return floatListFromBuffer(buffer, blob.offsetInBytes, blob.lengthInBytes ~/ 4);
  }

  static Float32List floatListFromBuffer(ByteBuffer buffer, int offset, int length) {
    return buffer.asFloat32List(offset, length);
  }

  /// Calculates cosine similarity score between two float vectors.
  static double cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (var index = 0; index < v1.length; index++) {
      final a = v1[index];
      final b = v2[index];
      dotProduct += a * b;
      normA += a * a;
      normB += b * b;
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Persists vector embedding for [clipboardId], re-using existing embeddings if [contentHash] exists.
  Future<void> storeEmbedding({
    required String clipboardId,
    required String contentHash,
    required String modelId,
    required List<double> vector,
  }) async {
    final db = _database?.database;
    if (db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if content_hash already has pre-computed vector for this model
    final existingHashRows = await db.query(
      'clipboard_embeddings',
      columns: ['vector'],
      where: 'content_hash = ? AND model_id = ?',
      whereArgs: [contentHash, modelId],
      limit: 1,
    );

    Uint8List blobBytes;
    if (existingHashRows.isNotEmpty && existingHashRows.first['vector'] is Uint8List) {
      blobBytes = existingHashRows.first['vector'] as Uint8List;
    } else {
      blobBytes = encodeVector(vector);
    }

    await db.insert(
      'clipboard_embeddings',
      {
        'clipboard_id': clipboardId,
        'content_hash': contentHash,
        'model_id': modelId,
        'vector': blobBytes,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Computes cosine distance against stored embeddings for [modelId] and returns top matches.
  Future<List<VectorMatch>> findVectorMatches({
    required List<double> queryVector,
    required String modelId,
    int limit = 30,
  }) async {
    final db = _database?.database;
    if (db == null || queryVector.isEmpty) return const [];

    final rows = await db.query(
      'clipboard_embeddings',
      columns: ['clipboard_id', 'vector'],
      where: 'model_id = ?',
      whereArgs: [modelId],
    );

    final matches = <VectorMatch>[];

    for (final row in rows) {
      final clipId = row['clipboard_id'] as String?;
      final blob = row['vector'] as Uint8List?;
      if (clipId == null || blob == null) continue;

      final storedVector = decodeVector(blob);
      final similarity = cosineSimilarity(queryVector, storedVector);
      matches.add(VectorMatch(clipboardId: clipId, score: similarity));
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(limit).toList();
  }
}
