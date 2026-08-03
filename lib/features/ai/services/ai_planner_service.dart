import '../domain/ai_execution_plan.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_request_plan.dart';
import 'ai_plan_validator.dart';

/// Hybrid planner service combining fast rule-based paths with structured execution planning.
class AiPlannerService {
  const AiPlannerService([
    this._requestPlanner = const AiRequestPlanner(),
    this._validator = const AiPlanValidator(),
  ]);

  final AiRequestPlanner _requestPlanner;
  final AiPlanValidator _validator;

  /// Creates an [AiRequestPlan] containing a validated [AiExecutionPlan].
  AiRequestPlan createPlan({
    required String prompt,
    required bool hasSelectedClipboard,
    required bool hasConversation,
    AiFeatureGroup? featureGroup,
    String? rawModelPlanJson,
  }) {
    final legacyPlan = _requestPlanner.plan(
      prompt: prompt,
      hasSelectedClipboard: hasSelectedClipboard,
      hasConversation: hasConversation,
      featureGroup: featureGroup,
    );

    // 1. Try parsing model-generated JSON plan if available
    if (rawModelPlanJson != null && rawModelPlanJson.trim().isNotEmpty) {
      final parsedPlan = AiExecutionPlan.tryParseJson(rawModelPlanJson);
      if (parsedPlan != null && _validator.isValid(parsedPlan)) {
        return AiRequestPlan(
          intent: legacyPlan.intent,
          useClipboardHistory: parsedPlan.needsClipboard || legacyPlan.useClipboardHistory,
          useSelectedClipboard: legacyPlan.useSelectedClipboard,
          maxOutputTokens: legacyPlan.maxOutputTokens,
          responseLanguage: parsedPlan.language,
          executionPlan: parsedPlan,
        );
      }
    }

    // 2. Multi-step heuristic detector for natural language prompts asking for sequential operations
    final multiStepPlan = _detectMultiStepHeuristics(
      prompt: prompt,
      hasSelectedClipboard: hasSelectedClipboard,
      responseLanguage: legacyPlan.responseLanguage,
    );

    if (multiStepPlan != null && _validator.isValid(multiStepPlan)) {
      return AiRequestPlan(
        intent: AiRequestIntent.clipboardAction,
        useClipboardHistory: multiStepPlan.needsClipboard,
        useSelectedClipboard: hasSelectedClipboard,
        maxOutputTokens: 1536,
        responseLanguage: legacyPlan.responseLanguage,
        executionPlan: multiStepPlan,
      );
    }

    // 3. Fast-path single-step execution plan fallback
    final defaultTool = _resolveDefaultTool(
      intent: legacyPlan.intent,
      featureGroup: featureGroup,
      hasSelectedClipboard: hasSelectedClipboard,
    );

    final fallbackExecutionPlan = AiExecutionPlan.singleStepFallback(
      tool: defaultTool,
      language: legacyPlan.responseLanguage,
      arguments: {
        if (hasSelectedClipboard) 'source': r'$selected_clipboard',
        'query': prompt,
      },
    );

    return AiRequestPlan(
      intent: legacyPlan.intent,
      useClipboardHistory: legacyPlan.useClipboardHistory,
      useSelectedClipboard: legacyPlan.useSelectedClipboard,
      maxOutputTokens: legacyPlan.maxOutputTokens,
      responseLanguage: legacyPlan.responseLanguage,
      executionPlan: fallbackExecutionPlan,
    );
  }

  AiExecutionPlan? _detectMultiStepHeuristics({
    required String prompt,
    required bool hasSelectedClipboard,
    required String responseLanguage,
  }) {
    final lower = prompt.toLowerCase();

    // Check for sequence connectives ("rồi", "sau đó", "and then", "bước 1", "lấy ... rồi giải thích")
    final hasSequenceConnective = lower.contains('rồi') ||
        lower.contains('sau đó') ||
        lower.contains('and then') ||
        lower.contains('sau đấy') ||
        lower.contains('tiếp theo');

    final asksSearch = lower.contains('tìm') || lower.contains('search') || lower.contains('find') || lower.contains('lọc');
    final asksExtract = lower.contains('trích') || lower.contains('extract') || lower.contains('lấy url') || lower.contains('lấy link');
    final asksExplain = lower.contains('giải thích') || lower.contains('explain') || lower.contains('làm gì') || lower.contains('ý nghĩa');

    // Example: "Tìm đoạn JSON API tôi copy hôm qua, lấy URL endpoint rồi giải thích API này làm gì"
    if (hasSequenceConnective && (asksSearch || hasSelectedClipboard) && (asksExtract || asksExplain)) {
      final steps = <AiExecutionStep>[];
      var stepCounter = 1;

      if (!hasSelectedClipboard && asksSearch) {
        String contentType = 'text';
        if (lower.contains('json')) contentType = 'json';
        if (lower.contains('url') || lower.contains('link')) contentType = 'url';
        if (lower.contains('code')) contentType = 'code';

        String dateRange = 'recent';
        if (lower.contains('hôm qua') || lower.contains('yesterday')) dateRange = 'yesterday';
        if (lower.contains('hôm nay') || lower.contains('today')) dateRange = 'today';

        steps.add(
          AiExecutionStep(
            stepId: stepCounter++,
            tool: 'search_clipboard',
            arguments: {
              'content_type': contentType,
              'date_range': dateRange,
              'query': prompt,
            },
          ),
        );
      }

      final sourceRef = steps.isNotEmpty ? '\$step_${steps.last.stepId}' : r'$selected_clipboard';

      if (asksExtract) {
        steps.add(
          AiExecutionStep(
            stepId: stepCounter++,
            tool: 'extract_urls',
            arguments: {'source': sourceRef},
          ),
        );
      }

      if (asksExplain) {
        steps.add(
          AiExecutionStep(
            stepId: stepCounter++,
            tool: 'explain_content',
            arguments: {'source': sourceRef},
          ),
        );
      }

      if (steps.isNotEmpty) {
        return AiExecutionPlan(
          intent: 'multi_step',
          language: responseLanguage,
          needsClipboard: !hasSelectedClipboard,
          steps: steps,
          outputFormat: 'markdown',
          confidence: 0.9,
        );
      }
    }

    return null;
  }

  String _resolveDefaultTool({
    required AiRequestIntent intent,
    required AiFeatureGroup? featureGroup,
    required bool hasSelectedClipboard,
  }) {
    if (featureGroup != null) {
      return switch (featureGroup) {
        AiFeatureGroup.rewrite => 'rewrite_content',
        AiFeatureGroup.grammar => 'rewrite_content',
        AiFeatureGroup.summary => 'summarize_text',
        AiFeatureGroup.translate => 'translate_text',
        AiFeatureGroup.smartReply => 'rewrite_content',
        AiFeatureGroup.generate => 'rewrite_content',
        AiFeatureGroup.qa => 'qa_clipboard',
        AiFeatureGroup.codeExplain => 'explain_content',
        AiFeatureGroup.extractInfo => 'extract_urls',
        AiFeatureGroup.titlesTags => 'classify_type',
        AiFeatureGroup.classify => 'classify_type',
        AiFeatureGroup.ocrRefine => 'refine_ocr',
      };
    }

    return switch (intent) {
      AiRequestIntent.clipboardSearch => 'search_clipboard',
      AiRequestIntent.clipboardAction => 'explain_content',
      AiRequestIntent.followUp => 'explain_content',
      AiRequestIntent.conversation => 'explain_content',
    };
  }
}
