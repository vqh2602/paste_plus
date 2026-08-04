import 'ai_language_context.dart';
import 'ai_locale_spec.dart';

class AiResponseLocaleResolver {
  const AiResponseLocaleResolver();

  String resolve(AiLanguageContext context) {
    final explicit = context.explicitResponseTag;
    if (explicit != null && explicit.isNotEmpty) {
      return AiLanguageRegistry.normalizeTag(explicit);
    }
    final translationTarget = context.translationTargetTag;
    if (translationTarget != null && translationTarget.isNotEmpty) {
      return AiLanguageRegistry.normalizeTag(translationTarget);
    }
    if (context.responseMode == AiResponseLanguageMode.fixed &&
        context.fixedResponseTag?.isNotEmpty == true) {
      return AiLanguageRegistry.normalizeTag(context.fixedResponseTag);
    }
    if (context.responseMode == AiResponseLanguageMode.matchUser &&
        context.detectedInputTag?.isNotEmpty == true) {
      return AiLanguageRegistry.normalizeTag(context.detectedInputTag);
    }
    return AiLanguageRegistry.normalizeTag(context.appLocale.toLanguageTag());
  }
}
