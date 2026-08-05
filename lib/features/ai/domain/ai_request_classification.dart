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
  });

  final String languageTag;
  final AiRequestIntent intent;
  final AiReasoningLevel reasoningLevel;
  final bool needsPlanner;
  final bool needsClipboard;
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
  // This is only reached when the LLM utility classifier is unavailable
  // (model not downloaded). Keep it simple and conservative.
  final hasLargeCode = prompt.contains('```') && prompt.length > 500;
  final level = featureGroup == AiFeatureGroup.codeExplain ||
          hasLargeCode ||
          prompt.length > 1500
      ? AiReasoningLevel.high
      : featureGroup == AiFeatureGroup.summary || prompt.length > 400
      ? AiReasoningLevel.medium
      : AiReasoningLevel.low;
  final intent = featureGroup != null || hasSelectedClipboard
      ? AiRequestIntent.clipboardAction
      : AiRequestIntent.conversation;
  return AiRequestClassification(
    languageTag: appLanguageTag,
    intent: intent,
    reasoningLevel: level,
    needsPlanner: false,
    needsClipboard: featureGroup == AiFeatureGroup.qa || hasSelectedClipboard,
  );
}
