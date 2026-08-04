import 'package:clipflow/core/database/app_database.dart';
import 'package:clipflow/features/ai/services/clipboard_vector_store.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClipboardVectorStore', () {
    test('encodes and decodes Float32List vector bytes correctly', () {
      final original = [0.1, 0.25, -0.75, 1.0, 3.14159];
      final encodedBlob = ClipboardVectorStore.encodeVector(original);
      final decoded = ClipboardVectorStore.decodeVector(encodedBlob);

      expect(decoded.length, original.length);
      for (var index = 0; index < original.length; index++) {
        expect(decoded[index], closeTo(original[index], 0.0001));
      }
    });

    test('calculates cosine similarity accurately', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0];
      final v3 = [0.0, 1.0, 0.0];

      expect(
        ClipboardVectorStore.cosineSimilarity(v1, v2),
        closeTo(1.0, 0.0001),
      );
      expect(
        ClipboardVectorStore.cosineSimilarity(v1, v3),
        closeTo(0.0, 0.0001),
      );
    });

    test(
      'indexClipboardItem reuses pre-computed vector for identical content hash',
      () async {
        final db = await AppDatabase.open(inMemory: true);
        final store = ClipboardVectorStore(db);

        final item1 = ClipboardItem(
          id: 'clip_1',
          content: 'shared content text',
          normalizedContent: 'shared content text',
          contentHash: 'hash_shared_123',
          contentType: ClipboardContentType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastCopiedAt: DateTime.now(),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
        );

        await db.database.insert('clipboard_items', item1.toMap());

        var embedCallCount = 0;
        Future<List<double>> mockEmbedder(String text) async {
          embedCallCount++;
          return [0.5, 0.5, 0.5];
        }

        await store.indexClipboardItem(
          item: item1,
          modelId: 'test_model',
          embedder: mockEmbedder,
        );
        expect(embedCallCount, 1);

        final item2 = ClipboardItem(
          id: 'clip_2',
          content: 'shared content text',
          normalizedContent: 'shared content text',
          contentHash: 'hash_shared_123',
          contentType: ClipboardContentType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastCopiedAt: DateTime.now(),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
        );

        await db.database.insert('clipboard_items', item2.toMap());

        await store.indexClipboardItem(
          item: item2,
          modelId: 'test_model',
          embedder: mockEmbedder,
        );
        expect(embedCallCount, 1);

        await db.close();
      },
    );
  });
}
