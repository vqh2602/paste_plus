import '../localization/ai_locale_spec.dart';

String buildAiLanguageDirective(String languageTag) {
  final locale = AiLanguageRegistry.resolve(languageTag);
  return '''
OUTPUT LANGUAGE
- BCP-47 language tag: ${locale.tag}
- Write naturally in ${locale.englishName} (${locale.nativeName}).
- Do not translate code, URLs, file names, identifiers, or placeholders.
'''
      .trim();
}
