import 'package:clipflow/features/ai/services/ai_clipboard_relevance_ranker.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem _item(String id, String content, ClipboardContentType type) {
  final timestamp = DateTime.now();
  return ClipboardItem(
    id: id,
    content: content,
    normalizedContent: content.toLowerCase(),
    contentHash: 'hash-$id',
    contentType: type,
    createdAt: timestamp,
    updatedAt: timestamp,
    lastCopiedAt: timestamp,
    isPinned: false,
    isSensitive: false,
    copyCount: 1,
  );
}

void main() {
  const ranker = AiClipboardRelevanceRanker();

  test('ranks a PNG URL above semantically similar unrelated text', () {
    const prompt = 'tìm cho tôi các bản ghi về link ảnh png';
    final results = ranker.rank(
      prompt: prompt,
      items: [
        _item('echo', prompt, ClipboardContentType.text),
        _item(
          'unrelated',
          'Tài liệu nói về tìm kiếm clipboard thông minh',
          ClipboardContentType.text,
        ),
        _item('png', 'https://iili.io/CvFsdVS.png', ClipboardContentType.url),
      ],
      semanticScores: const {'unrelated': 0.99, 'png': 0.05},
    );

    expect(results.first.id, 'png');
    expect(results.map((item) => item.id), isNot(contains('echo')));
  });

  test('honors the requested image extension', () {
    final results = ranker.rank(
      prompt: 'find image webp links',
      items: [
        _item('png', 'https://example.com/image.png', ClipboardContentType.url),
        _item(
          'webp',
          'https://example.com/image.webp',
          ClipboardContentType.url,
        ),
      ],
    );

    expect(results.first.id, 'webp');
    expect(ranker.hasExactFileConstraint('find image webp links'), isTrue);
    expect(ranker.hasExactFileConstraint('find an image link'), isFalse);
  });
}
