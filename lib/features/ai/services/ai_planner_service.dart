import '../domain/ai_execution_plan.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_request_plan.dart';
import '../localization/ai_locale_spec.dart';
import 'ai_plan_validator.dart';

/// Hybrid planner service combining fast rule-based paths with structured execution planning.
class AiPlannerService {
  const AiPlannerService([
    this._requestPlanner = const AiRequestPlanner(),
    this._validator = const AiPlanValidator(),
  ]);

  final AiRequestPlanner _requestPlanner;
  final AiPlanValidator _validator;

  /// Evaluates whether a prompt is complex or multi-step enough to require LLM model planning.
  bool shouldUseModelPlanner({
    required String prompt,
    required bool hasSelectedClipboard,
    AiFeatureGroup? featureGroup,
  }) {
    if (featureGroup != null || prompt.trim().isEmpty) return false;
    final lower = prompt.toLowerCase();
    final referencesClipboard = RegExp(
      r'\b(clipboard|clip|đã copy|đã sao chép|lịch sử)\b',
    ).hasMatch(lower);
    final requestsTool = RegExp(
      r'\b(tìm|search|find|xóa|delete|ghim|pin|collection|bộ sưu tập)\b',
    ).hasMatch(lower);
    final multiStep = RegExp(
      r'\b(sau đó|rồi|tiếp theo|then|after that|and then)\b',
    ).hasMatch(lower);
    return referencesClipboard || requestsTool || multiStep;
  }

  /// Creates an [AiRequestPlan] containing a validated [AiExecutionPlan].
  AiRequestPlan createPlan({
    required String prompt,
    required bool hasSelectedClipboard,
    required bool hasConversation,
    AiFeatureGroup? featureGroup,
    String? rawModelPlanJson,
    String appLanguageTag = 'vi-VN',
    String? resolvedResponseLanguageTag,
  }) {
    final legacyPlan = _requestPlanner.plan(
      prompt: prompt,
      hasSelectedClipboard: hasSelectedClipboard,
      hasConversation: hasConversation,
      featureGroup: featureGroup,
      appLanguageTag: appLanguageTag,
      resolvedResponseLanguageTag: resolvedResponseLanguageTag,
    );

    // 1. Try parsing model-generated JSON plan if available
    if (rawModelPlanJson != null && rawModelPlanJson.trim().isNotEmpty) {
      final parsedPlan = AiExecutionPlan.tryParseJson(rawModelPlanJson);
      if (parsedPlan != null && _validator.isValid(parsedPlan)) {
        return AiRequestPlan(
          intent: legacyPlan.intent,
          useClipboardHistory:
              parsedPlan.needsClipboard || legacyPlan.useClipboardHistory,
          useSelectedClipboard: legacyPlan.useSelectedClipboard,
          maxOutputTokens: legacyPlan.maxOutputTokens,
          responseLanguageTag: AiLanguageRegistry.normalizeTag(
            parsedPlan.language,
          ),
          executionPlan: parsedPlan,
        );
      }
    }

    // 2. Fast-path single-step execution plan fallback
    final defaultTool = _resolveDefaultTool(
      intent: legacyPlan.intent,
      featureGroup: featureGroup,
      hasSelectedClipboard: hasSelectedClipboard,
    );

    // Text transformations and conversational tasks are handled by the final
    // inference. They must not be represented as tools that the registry cannot run.
    if (defaultTool == null) return legacyPlan;

    final fallbackExecutionPlan = AiExecutionPlan.singleStepFallback(
      tool: defaultTool,
      language: legacyPlan.responseLanguageTag,
      arguments: {'query': prompt},
    );

    return AiRequestPlan(
      intent: legacyPlan.intent,
      useClipboardHistory: legacyPlan.useClipboardHistory,
      useSelectedClipboard: legacyPlan.useSelectedClipboard,
      maxOutputTokens: legacyPlan.maxOutputTokens,
      responseLanguageTag: legacyPlan.responseLanguageTag,
      executionPlan: fallbackExecutionPlan,
    );
  }

  String? _resolveDefaultTool({
    required AiRequestIntent intent,
    required AiFeatureGroup? featureGroup,
    required bool hasSelectedClipboard,
  }) {
    if (featureGroup != null) return null;

    return switch (intent) {
      AiRequestIntent.clipboardSearch => 'search_clipboard',
      AiRequestIntent.clipboardAction => null,
      AiRequestIntent.followUp => null,
      AiRequestIntent.conversation => null,
    };
  }
}
