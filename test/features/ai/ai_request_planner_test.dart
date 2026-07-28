import 'package:clipflow/features/ai/domain/ai_request_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = AiRequestPlanner();

  test('casual conversation does not attach clipboard history', () {
    final plan = planner.plan(
      prompt: 'hi',
      hasSelectedClipboard: false,
      hasConversation: false,
    );

    expect(plan.intent, AiRequestIntent.conversation);
    expect(plan.useClipboardHistory, isFalse);
    expect(plan.useSelectedClipboard, isFalse);
    expect(plan.maxOutputTokens, lessThan(1000));
    expect(plan.responseLanguage, 'English');
  });

  test('explicit clipboard search enables RAG', () {
    final plan = planner.plan(
      prompt: 'tìm cho tôi clipboard link ảnh png',
      hasSelectedClipboard: false,
      hasConversation: true,
    );

    expect(plan.intent, AiRequestIntent.clipboardSearch);
    expect(plan.useClipboardHistory, isTrue);
    expect(plan.responseLanguage, 'Vietnamese');
  });

  test('transformation uses selected clip without all history', () {
    final plan = planner.plan(
      prompt: 'dịch sang tiếng Anh',
      hasSelectedClipboard: true,
      hasConversation: true,
    );

    expect(plan.intent, AiRequestIntent.clipboardAction);
    expect(plan.useSelectedClipboard, isTrue);
    expect(plan.useClipboardHistory, isFalse);
  });

  test('follow-up uses conversation without injecting clipboard', () {
    final plan = planner.plan(
      prompt: 'giải thích rõ hơn ý vừa rồi',
      hasSelectedClipboard: false,
      hasConversation: true,
    );

    expect(plan.intent, AiRequestIntent.followUp);
    expect(plan.useClipboardHistory, isFalse);
  });
}
