import 'package:clipflow/features/ai/services/structured_output_validator.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem mockItem(String id, String content) {
  final now = DateTime(2026, 8, 2);
  return ClipboardItem(
    id: id,
    content: content,
    normalizedContent: content.toLowerCase(),
    contentHash: 'hash-$id',
    contentType: ClipboardContentType.text,
    createdAt: now,
    updatedAt: now,
    lastCopiedAt: now,
    isPinned: false,
    isSensitive: false,
    copyCount: 1,
  );
}

void main() {
  const validator = StructuredOutputValidator();

  group('StructuredOutputValidator', () {
    test('extracts clean JSON from raw text and markdown fences', () {
      const markdownInput = '''
Here are the matches:
```json
{
  "matches": [
    {
      "clip_id": "clip_100",
      "value": "hallucinated value",
      "reason": "exact match"
    }
  ]
}
```
''';

      final jsonStr = validator.extractJson(markdownInput);
      expect(jsonStr, contains('"clip_id": "clip_100"'));
    });

    test(
      'validates schema, rejects unknown clip_ids, and enforces DB Ground-Truth for value',
      () {
        final dbItem = mockItem(
          'clip_100',
          'Original database exact content value',
        );

        const rawModelOutput = '''
{
  "matches": [
    {
      "clip_id": "clip_100",
      "value": "Model hallucinated text string",
      "reason": "Matched keyword endpoint"
    },
    {
      "clip_id": "fake_unknown_999",
      "value": "Fake content",
      "reason": "Fake reason"
    }
  ]
}
''';

        final response = validator.validateSearchOutput(
          rawOutput: rawModelOutput,
          databaseCandidates: [dbItem],
        );

        // Rejects unknown clip_id fake_unknown_999
        expect(response.matches.length, 1);
        expect(response.matches.first.clipId, 'clip_100');

        // Replaces model's hallucinated text with exact DB content from originalItem.content!
        expect(
          response.matches.first.value,
          equals('Original database exact content value'),
        );
        expect(
          response.matches.first.reason,
          equals('Matched keyword endpoint'),
        );
      },
    );
  });
}
