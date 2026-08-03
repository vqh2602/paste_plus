import 'dart:typed_data';

import 'package:clipflow/features/ai/services/clipboard_vector_store.dart';
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

      expect(ClipboardVectorStore.cosineSimilarity(v1, v2), closeTo(1.0, 0.0001));
      expect(ClipboardVectorStore.cosineSimilarity(v1, v3), closeTo(0.0, 0.0001));
    });
  });
}
