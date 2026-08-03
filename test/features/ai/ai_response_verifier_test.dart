import 'package:clipflow/features/ai/services/ai_response_verifier.dart';
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
  const verifier = AiResponseVerifier();

  group('AiResponseVerifier', () {
    test('strips non-existent hallucinated clip_id citations', () {
      final validItem = mockItem(
        'clip_valid_123',
        'Valid clipboard text content',
      );

      const draftText = '''
Here is the result from your clipboard:
- Found item [clip:clip_valid_123] with details.
- Also found item [clip:clip_fake_999] which does not exist.
''';

      final report = verifier.verifyAndCorrect(
        draftText: draftText,
        candidates: [validItem],
        responseLanguage: 'English',
      );

      expect(report.citations, contains('clip_valid_123'));
      expect(report.citations, isNot(contains('clip_fake_999')));
      expect(report.correctedText, contains('[clip:clip_valid_123]'));
      expect(report.correctedText, isNot(contains('[clip:clip_fake_999]')));
      expect(report.issues.length, 1);
    });

    test(
      'restores truncated or mutilated URLs back to exact SQLite database content',
      () {
        final dbItem = mockItem(
          'url_clip',
          'Check out https://github.com/vqh2602/paste_plus/releases/tag/v1.0.0 for updates.',
        );

        // Model truncated the URL parameter query
        const draftWithMutilatedUrl = '''
You can download the update from https://github.com/vqh2602/paste_plus/releases.
''';

        final report = verifier.verifyAndCorrect(
          draftText: draftWithMutilatedUrl,
          candidates: [dbItem],
          responseLanguage: 'English',
        );

        expect(
          report.correctedText,
          contains('https://github.com/vqh2602/paste_plus/releases/tag/v1.0.0'),
        );
        expect(report.issues.first, contains('Phục hồi URL chính xác'));
      },
    );
  });
}
