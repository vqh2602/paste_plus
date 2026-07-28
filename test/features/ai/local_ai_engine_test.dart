import 'package:clipflow/features/ai/domain/ai_model_info.dart';
import 'package:clipflow/features/ai/services/local_ai_engine.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem item({
  required String id,
  required String content,
  required ClipboardContentType type,
  bool sensitive = false,
}) {
  final timestamp = DateTime(2026, 7, 28);
  return ClipboardItem(
    id: id,
    content: content,
    normalizedContent: content.toLowerCase(),
    contentHash: 'hash-$id',
    contentType: type,
    createdAt: timestamp,
    updatedAt: timestamp,
    lastCopiedAt: timestamp,
    sourceAppName: 'Test App',
    isPinned: false,
    isSensitive: sensitive,
    copyCount: 1,
  );
}

void main() {
  test(
    'searches all clipboard items for URLs when no clip is selected',
    () async {
      final engine = LocalAiEngine();
      final events = await engine
          .processStream(
            model: AiModelInfo.thinkingModels.first,
            prompt: 'tìm clipboard url',
            clipboardHistory: [
              item(
                id: 'url',
                content: 'https://flutter.dev',
                type: ClipboardContentType.url,
              ),
              item(
                id: 'text',
                content: 'Ghi chú cuộc họp',
                type: ClipboardContentType.text,
              ),
            ],
          )
          .toList();

      final output = events.last['output']!;
      expect(output, contains('2 mục clipboard'));
      expect(output, contains('https://flutter.dev'));
    },
  );

  test('a selected clip takes priority over the full history', () async {
    final engine = LocalAiEngine();
    final selected = item(
      id: 'selected',
      content: 'Nội dung được chọn',
      type: ClipboardContentType.text,
    );
    final events = await engine
        .processStream(
          model: AiModelInfo.thinkingModels.first,
          prompt: 'phân tích nội dung',
          clipboardContext: selected,
          clipboardHistory: [
            item(
              id: 'url',
              content: 'https://should-not-be-used.example',
              type: ClipboardContentType.url,
            ),
          ],
        )
        .toList();

    final output = events.last['output']!;
    expect(output, contains('${selected.content.length}'));
    expect(output, isNot(contains('should-not-be-used')));
  });

  test('uses recent conversation context for a follow-up request', () async {
    final engine = LocalAiEngine();
    const recentConversation =
        'Người dùng: Tóm tắt ghi chú cuộc họp\n'
        'AI: Cuộc họp thống nhất phát hành vào thứ Sáu.';

    final events = await engine
        .processStream(
          model: AiModelInfo.thinkingModels.first,
          prompt: 'Hãy giải thích rõ hơn kết quả vừa rồi',
          conversationContext: recentConversation,
        )
        .toList();

    expect(events.last['thinking'], contains('các lượt hỏi đáp gần nhất'));
    expect(events.last['output'], contains('${recentConversation.length}'));
  });
}
