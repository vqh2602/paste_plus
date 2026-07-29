import 'package:clipflow/core/localization/app_translations.dart';
import 'package:clipflow/features/ai/domain/ai_model_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppTranslations.currentLanguage = 'vi';
  });

  test('catalog includes the newly supported local models', () {
    expect(AiModelInfo.defaultModelId, 'gemma-4-e2b');

    final gemmaE2b = AiModelInfo.findById('gemma-4-e2b');
    final gemmaE4b = AiModelInfo.findById('gemma-4-e4b');
    final qwen3 = AiModelInfo.findById('qwen3-0.6b');

    expect(gemmaE2b.name, contains('Gemma 4 E2B'));
    expect(gemmaE2b.downloadUrl, endsWith('gemma-4-E2B_q4_0-it.gguf'));
    expect(gemmaE4b.name, contains('Gemma 4 E4B'));
    expect(gemmaE4b.downloadUrl, endsWith('gemma-4-E4B_q4_0-it.gguf'));
    expect(qwen3.name, 'Qwen3 0.6B');
    expect(qwen3.downloadUrl, endsWith('Qwen3-0.6B-Q8_0.gguf'));
  });

  test('unknown model IDs fall back to Gemma 4 E2B', () {
    expect(AiModelInfo.findById('not-supported').id, 'gemma-4-e2b');
  });

  test('localizes model description and recommendations based on app language', () {
    final gemma = AiModelInfo.findById('gemma-4-e2b');

    AppTranslations.currentLanguage = 'vi';
    expect(gemma.description, contains('Model đa ngôn ngữ'));
    expect(gemma.recommendedFor, contains('Chat hằng ngày'));

    AppTranslations.currentLanguage = 'en';
    expect(gemma.description, contains("Google's next-gen multilingual model"));
    expect(gemma.recommendedFor, contains('Daily chat'));
  });
}

