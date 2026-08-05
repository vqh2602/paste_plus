import '../domain/ai_execution_plan.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_request_classification.dart';
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
    final containsKnownSyntax = RegExp(
      r'\b(type|app|is|before|after):',
      caseSensitive: false,
    ).hasMatch(prompt);
    final containsMultipleClauses =
        RegExp(r'[,;\n]|→|->').hasMatch(prompt) ||
        RegExp(
          r'\b(sau đó|rồi|tiếp theo|then|after that|and then|danach)\b',
        ).hasMatch(lower);
    final longInstruction = prompt.length >= 100;
    final selectedAction = hasSelectedClipboard && _looksLikeAction(lower);
    return containsKnownSyntax ||
        containsMultipleClauses ||
        longInstruction ||
        selectedAction ||
        _containsKnownToolTerm(lower);
  }

  bool _looksLikeAction(String prompt) => _actionTerms.any(prompt.contains);

  bool _containsKnownToolTerm(String prompt) => _toolTerms.any(prompt.contains);

  static const _actionTerms = <String>{
    'search',
    'find',
    'delete',
    'pin',
    'collection',
    'tìm',
    'xóa',
    'ghim',
    'bộ sưu tập',
    '検索',
    '削除',
    'ピン留め',
    'コレクション',
    'suche',
    'finde',
    'lösche',
    'hefte',
    'sammlung',
  };

  static const _toolTerms = <String>{
    ..._actionTerms,
    'clipboard',
    'clip',
    'lịch sử',
    'コピー',
    'zwischenablage',
    'kopiert',
  };

  /// Creates an [AiRequestPlan] containing a validated [AiExecutionPlan].
  AiRequestPlan createPlan({
    required String prompt,
    required bool hasSelectedClipboard,
    required bool hasConversation,
    AiFeatureGroup? featureGroup,
    String? rawModelPlanJson,
    String appLanguageTag = 'vi-VN',
    String? resolvedResponseLanguageTag,
    AiRequestClassification? classification,
  }) {
    final legacyPlan = _requestPlanner.plan(
      prompt: prompt,
      hasSelectedClipboard: hasSelectedClipboard,
      hasConversation: hasConversation,
      featureGroup: featureGroup,
      appLanguageTag: appLanguageTag,
      resolvedResponseLanguageTag: resolvedResponseLanguageTag,
    );

    final intent = classification?.intent ?? legacyPlan.intent;
    final useHistory = classification != null
        ? (classification.needsClipboard && !hasSelectedClipboard)
        : legacyPlan.useClipboardHistory;
    final useSelected = classification != null
        ? (classification.needsClipboard && hasSelectedClipboard)
        : legacyPlan.useSelectedClipboard;
    final responseLang = resolvedResponseLanguageTag ??
        classification?.languageTag ??
        legacyPlan.responseLanguageTag;

    // 1. Try parsing model-generated JSON plan if available
    if (rawModelPlanJson != null && rawModelPlanJson.trim().isNotEmpty) {
      final parsedPlan = AiExecutionPlan.tryParseJson(rawModelPlanJson);
      if (parsedPlan != null && _validator.isValid(parsedPlan)) {
        return AiRequestPlan(
          intent: intent,
          useClipboardHistory:
              parsedPlan.needsClipboard || useHistory,
          useSelectedClipboard: useSelected,
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
      intent: intent,
      featureGroup: featureGroup,
      hasSelectedClipboard: hasSelectedClipboard,
      prompt: prompt,
    );

    if (defaultTool == null) {
      return AiRequestPlan(
        intent: intent,
        useClipboardHistory: useHistory,
        useSelectedClipboard: useSelected,
        maxOutputTokens: legacyPlan.maxOutputTokens,
        responseLanguageTag: responseLang,
      );
    }

    final toolArgs = <String, dynamic>{'query': prompt};
    if (classification?.preferImageUrls == true ||
        prompt.toLowerCase().contains('link') ||
        prompt.toLowerCase().contains('url')) {
      toolArgs['content_type'] = 'url';
    }

    final fallbackExecutionPlan = AiExecutionPlan.singleStepFallback(
      tool: defaultTool,
      language: responseLang,
      arguments: toolArgs,
    );

    return AiRequestPlan(
      intent: intent,
      useClipboardHistory: useHistory,
      useSelectedClipboard: useSelected,
      maxOutputTokens: legacyPlan.maxOutputTokens,
      responseLanguageTag: responseLang,
      executionPlan: fallbackExecutionPlan,
    );
  }

  String? _resolveDefaultTool({
    required AiRequestIntent intent,
    required AiFeatureGroup? featureGroup,
    required bool hasSelectedClipboard,
    required String prompt,
  }) {
    if (featureGroup != null) return null;

    final lower = prompt.toLowerCase();
    if (RegExp(r'\b(ghim|pin|unpin)\b', caseSensitive: false).hasMatch(lower)) {
      return 'pin_clipboard';
    }
    if (RegExp(r'\b(xóa|delete|remove)\b', caseSensitive: false).hasMatch(lower)) {
      return 'delete_clipboard_item';
    }
    if (RegExp(r'\b(bộ sưu tập|collection)\b', caseSensitive: false).hasMatch(lower)) {
      return 'list_collections';
    }
    if (RegExp(r'\b(trích xuất url|extract url|trích xuất link)\b', caseSensitive: false).hasMatch(lower)) {
      return 'extract_urls';
    }

    return switch (intent) {
      AiRequestIntent.clipboardSearch => 'search_clipboard',
      AiRequestIntent.clipboardAction => hasSelectedClipboard ? null : 'search_clipboard',
      AiRequestIntent.followUp => null,
      AiRequestIntent.conversation => null,
    };
  }
}
