import 'ai_feature_action.dart';
import 'ai_request_intent.dart';

enum AiReasoningLevel { low, medium, high }

class AiRequestClassification {
  const AiRequestClassification({
    required this.languageTag,
    required this.intent,
    required this.reasoningLevel,
    required this.needsPlanner,
    required this.needsClipboard,
    this.preferImageUrls = false,
  });

  final String languageTag;
  final AiRequestIntent intent;
  final AiReasoningLevel reasoningLevel;
  final bool needsPlanner;
  final bool needsClipboard;
  final bool preferImageUrls;
}

/// Returns true only when the utility classifier (small LLM) can safely be
/// skipped — i.e. the feature group already determines intent unambiguously.
/// We intentionally do NOT skip based on prompt length: a short prompt like
/// "tìm clipboard có link" must still go through the LLM classifier so it can
/// correctly resolve intent, needsClipboard, and routing.
bool canSkipUtilityClassifier({
  required String prompt,
  required AiFeatureGroup? featureGroup,
}) {
  // When a feature group is explicitly set (Translate, Summarize, etc.),
  // the intent is already known — no need to classify.
  return featureGroup != null;
}

AiRequestClassification fallbackClassification({
  required String prompt,
  required String appLanguageTag,
  AiFeatureGroup? featureGroup,
  bool hasSelectedClipboard = false,
}) {
  // Simple heuristic fallback used ONLY when local Qwen 0.6B classifier model is not yet downloaded.
  final normalized = prompt.toLowerCase();
  final hasImageKeywords = normalized.contains('image') ||
      normalized.contains('photo') ||
      normalized.contains('picture') ||
      normalized.contains('ảnh') ||
      normalized.contains('hình');
  final hasLinkKeywords = normalized.contains('link') ||
      normalized.contains('url') ||
      normalized.contains('http') ||
      normalized.contains('liên kết');
  final preferImageUrls = hasImageKeywords && hasLinkKeywords;

  final isClipboardQuery =
      hasImageKeywords ||
      hasLinkKeywords ||
      normalized.contains('clipboard') ||
      normalized.contains('clipbroad') ||
      normalized.contains('bộ nhớ') ||
      normalized.contains('lịch sử') ||
      hasSelectedClipboard;

  final intent = featureGroup != null
      ? AiRequestIntent.clipboardAction
      : (hasSelectedClipboard
          ? AiRequestIntent.clipboardAction
          : (isClipboardQuery
              ? AiRequestIntent.clipboardSearch
              : AiRequestIntent.conversation));

  final needsClipboard =
      featureGroup == AiFeatureGroup.qa ||
      hasSelectedClipboard ||
      isClipboardQuery;

  final hasLargeCode = prompt.contains('```') && prompt.length > 500;
  final level = featureGroup == AiFeatureGroup.codeExplain ||
          hasLargeCode ||
          prompt.length > 1500
      ? AiReasoningLevel.high
      : featureGroup == AiFeatureGroup.summary || prompt.length > 400
      ? AiReasoningLevel.medium
      : AiReasoningLevel.low;

  return AiRequestClassification(
    languageTag: appLanguageTag,
    intent: intent,
    reasoningLevel: level,
    needsPlanner: isClipboardQuery,
    needsClipboard: needsClipboard,
    preferImageUrls: preferImageUrls,
  );
}
