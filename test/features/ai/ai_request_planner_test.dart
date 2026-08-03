import 'package:clipflow/core/localization/app_translations.dart';
import 'package:clipflow/features/ai/domain/ai_feature_action.dart';
import 'package:clipflow/features/ai/domain/ai_request_plan.dart';
import 'package:clipflow/features/ai/services/ai_prompts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = AiRequestPlanner();

  tearDown(() {
    AppTranslations.currentLanguage = 'vi';
  });

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

  test('English mode defaults to English response for English prompts or prompts with typo accents', () {
    AppTranslations.currentLanguage = 'en';

    final planNormal = planner.plan(
      prompt: 'create word 120',
      hasSelectedClipboard: false,
      hasConversation: false,
    );
    expect(planNormal.responseLanguage, 'English');

    final planTypo = planner.plan(
      prompt: 'create wòd 120',
      hasSelectedClipboard: false,
      hasConversation: false,
    );
    expect(planTypo.responseLanguage, 'English');
  });

  test('English mode localized AiFeatureGroup titles and options', () {
    AppTranslations.currentLanguage = 'en';

    expect(AiFeatureGroup.rewrite.title, 'Rewrite Content');
    expect(AiFeatureGroup.rewrite.options.first, 'More natural');

    AppTranslations.currentLanguage = 'vi';

    expect(AiFeatureGroup.rewrite.title, 'Viết lại nội dung');
    expect(AiFeatureGroup.rewrite.options.first, 'Tự nhiên hơn');
  });

  test('AiPrompts.buildSystemPrompt honors responseLanguage over UI language', () {
    AppTranslations.currentLanguage = 'vi';

    final promptEn = AiPrompts.buildSystemPrompt(
      featureGroup: null,
      selectedOption: null,
      intent: AiRequestIntent.conversation,
      responseLanguage: 'English',
    );
    expect(promptEn, contains('You must reply in English.'));

    final promptVi = AiPrompts.buildSystemPrompt(
      featureGroup: null,
      selectedOption: null,
      intent: AiRequestIntent.conversation,
      responseLanguage: 'Vietnamese',
    );
    expect(promptVi, contains('Bạn phải trả lời bằng Tiếng Việt.'));
  });
}

