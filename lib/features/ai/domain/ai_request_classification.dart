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

bool canSkipUtilityClassifier({
  required String prompt,
  required AiFeatureGroup? featureGroup,
}) {
  if (featureGroup != null) return true;
  final trimmed = prompt.trim();
  return trimmed.length < 30 &&
      !trimmed.contains('\n') &&
      !trimmed.contains('```');
}

AiRequestClassification fallbackClassification({
  required String prompt,
  required String appLanguageTag,
  AiFeatureGroup? featureGroup,
  bool hasSelectedClipboard = false,
}) {
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
