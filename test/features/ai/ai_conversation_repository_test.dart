import 'package:clipflow/features/ai/data/ai_conversation_repository.dart';
import 'package:clipflow/features/ai/domain/ai_chat_message.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists recent AI messages and active clipboard context', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = AiConversationRepository();
    final now = DateTime(2026, 7, 28);
    final context = ClipboardItem(
      id: 'clip-1',
      content: 'Nội dung cần hỏi tiếp',
      normalizedContent: 'Nội dung cần hỏi tiếp',
      contentHash: 'hash',
      contentType: ClipboardContentType.text,
      createdAt: now,
      updatedAt: now,
      lastCopiedAt: now,
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
    );

    await repository.save(
      messages: [
        AiChatMessage(
          id: 'user-1',
          role: AiMessageRole.user,
          content: 'Tóm tắt đoạn này',
          clipboardContext: context,
        ),
        AiChatMessage(
          id: 'ai-1',
          role: AiMessageRole.assistant,
          content: 'Đây là bản tóm tắt.',
          clipboardContext: context,
        ),
      ],
      clipboardContext: context,
    );

    final restored = await repository.load();

    expect(restored.messages, hasLength(2));
    expect(restored.messages.last.content, 'Đây là bản tóm tắt.');
    expect(restored.clipboardContext?.id, 'clip-1');
    expect(restored.clipboardContext?.content, 'Nội dung cần hỏi tiếp');
  });

  test('keeps only the latest completed messages', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = AiConversationRepository();
    final messages = List.generate(
      AiConversationRepository.maxStoredMessages + 5,
      (index) => AiChatMessage(
        id: '$index',
        role: AiMessageRole.user,
        content: 'message $index',
      ),
    );

    await repository.save(messages: messages, clipboardContext: null);
    final restored = await repository.load();

    expect(
      restored.messages,
      hasLength(AiConversationRepository.maxStoredMessages),
    );
    expect(restored.messages.first.content, 'message 5');
  });
}
