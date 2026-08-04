import 'package:clipflow/features/ai/localization/ai_language_context.dart';
import 'package:clipflow/features/ai/localization/ai_locale_spec.dart';
import 'package:clipflow/features/ai/localization/ai_response_locale_resolver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = AiResponseLocaleResolver();

  test(
    'response locale priority is explicit, translation, fixed, input, app',
    () {
      const context = AiLanguageContext(
        appLocale: Locale('vi'),
        responseMode: AiResponseLanguageMode.fixed,
        detectedInputTag: 'ja-JP',
        explicitResponseTag: 'de-DE',
        translationTargetTag: 'ko-KR',
        fixedResponseTag: 'en-US',
      );
      expect(resolver.resolve(context), 'de-DE');

      expect(
        resolver.resolve(
          const AiLanguageContext(
            appLocale: Locale('vi'),
            responseMode: AiResponseLanguageMode.matchUser,
            detectedInputTag: 'ja-JP',
          ),
        ),
        'ja-JP',
      );
    },
  );

  test('language registry normalizes legacy values and parses script tags', () {
    expect(AiLanguageRegistry.normalizeTag('Vietnamese'), 'vi-VN');
    final locale = AiLanguageRegistry.resolve('zh-Hans-CN').locale;
    expect(locale.languageCode, 'zh');
    expect(locale.scriptCode, 'Hans');
    expect(locale.countryCode, 'CN');
  });
}
