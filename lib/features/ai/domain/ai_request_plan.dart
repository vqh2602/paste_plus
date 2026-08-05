import 'ai_execution_plan.dart';
import 'ai_feature_action.dart';
import 'ai_request_classification.dart';
import 'ai_request_intent.dart';
import '../localization/ai_locale_spec.dart';

export 'ai_request_intent.dart';

int resolveOutputTokens({
  required AiRequestIntent intent,
  required String prompt,
  required AiFeatureGroup? featureGroup,
}) {
  if (featureGroup == AiFeatureGroup.translate) return 2048;
  if (featureGroup == AiFeatureGroup.codeExplain) return 2048;
  if (prompt.contains('```') || prompt.length > 800) return 2048;
  return switch (intent) {
    AiRequestIntent.conversation => 1024,
    AiRequestIntent.followUp => 1024,
    AiRequestIntent.clipboardSearch => 1536,
    AiRequestIntent.clipboardAction => 1536,
  };
}

int resolveClassifiedOutputTokens({
  required AiRequestClassification classification,
  required String prompt,
  required AiFeatureGroup? featureGroup,
}) {
  if (featureGroup == AiFeatureGroup.translate) return 2048;
  if (featureGroup == AiFeatureGroup.codeExplain ||
      prompt.contains('```') ||
      prompt.length > 800) {
    return 2048;
  }
  return switch (classification.reasoningLevel) {
    AiReasoningLevel.low => 1024,
    AiReasoningLevel.medium => 1536,
    AiReasoningLevel.high => 2048,
  };
}

int resolveClassifiedContextSize(AiRequestClassification classification) {
  if (classification.needsClipboard) return 8192;
  return switch (classification.reasoningLevel) {
    AiReasoningLevel.low => 4096,
    AiReasoningLevel.medium => 8192,
    AiReasoningLevel.high => 16384,
  };
}

Duration resolveGenerationTimeout({
  required AiRequestIntent intent,
  required AiFeatureGroup? featureGroup,
}) {
  if (featureGroup == AiFeatureGroup.translate ||
      featureGroup == AiFeatureGroup.summary ||
      featureGroup == AiFeatureGroup.codeExplain) {
    return const Duration(minutes: 5);
  }
  if (intent == AiRequestIntent.clipboardAction) {
    return const Duration(minutes: 3);
  }
  return const Duration(minutes: 2);
}

Duration resolveStreamInactivityTimeout({
  required AiRequestIntent intent,
  required AiFeatureGroup? featureGroup,
}) {
  if (featureGroup == AiFeatureGroup.translate ||
      featureGroup == AiFeatureGroup.summary ||
      featureGroup == AiFeatureGroup.codeExplain) {
    return const Duration(seconds: 90);
  }
  if (intent == AiRequestIntent.clipboardAction) {
    return const Duration(seconds: 60);
  }
  return const Duration(seconds: 45);
}

class AiRequestPlan {
  const AiRequestPlan({
    required this.intent,
    required this.useClipboardHistory,
    required this.useSelectedClipboard,
    required this.maxOutputTokens,
    required this.responseLanguageTag,
    this.executionPlan,
  });

  final AiRequestIntent intent;
  final bool useClipboardHistory;
  final bool useSelectedClipboard;
  final int maxOutputTokens;
  final String responseLanguageTag;

  @Deprecated('Use responseLanguageTag.')
  String get responseLanguage => responseLanguageTag;
  final AiExecutionPlan? executionPlan;
}

class AiRequestPlanner {
  const AiRequestPlanner();

  AiRequestPlan plan({
    required String prompt,
    required bool hasSelectedClipboard,
    required bool hasConversation,
    AiFeatureGroup? featureGroup,
    String appLanguageTag = 'vi-VN',
    String? resolvedResponseLanguageTag,
  }) {
    final normalized = prompt.toLowerCase().trim();
    final words = normalized
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toSet();
    final referencesClipboard = words.any(_clipboardTerms.contains);
    final responseLanguageTag =
        resolvedResponseLanguageTag ??
        _detectLanguageTag(normalized) ??
        AiLanguageRegistry.normalizeTag(appLanguageTag);
    final asksToFind = words.any(_searchTerms.contains);
    final asksToTransform = words.any(_actionTerms.contains);
    final referencesCurrentContent = words.any(_referenceTerms.contains);
    final isFollowUp =
        hasConversation &&
        (words.any(_followUpTerms.contains) ||
            referencesCurrentContent ||
            asksToTransform);

    if (featureGroup != null) {
      final searchesHistory =
          featureGroup == AiFeatureGroup.qa && !hasSelectedClipboard;
      return AiRequestPlan(
        intent: AiRequestIntent.clipboardAction,
        useClipboardHistory: searchesHistory,
        useSelectedClipboard: hasSelectedClipboard,
        maxOutputTokens: resolveOutputTokens(
          intent: AiRequestIntent.clipboardAction,
          prompt: prompt,
          featureGroup: featureGroup,
        ),
        responseLanguageTag: responseLanguageTag,
      );
    }

    if (referencesClipboard && asksToFind) {
      return AiRequestPlan(
        intent: AiRequestIntent.clipboardSearch,
        useClipboardHistory: true,
        useSelectedClipboard: false,
        maxOutputTokens: resolveOutputTokens(
          intent: AiRequestIntent.clipboardSearch,
          prompt: prompt,
          featureGroup: featureGroup,
        ),
        responseLanguageTag: responseLanguageTag,
      );
    }

    if (hasSelectedClipboard && !(referencesClipboard && asksToFind)) {
      return AiRequestPlan(
        intent: AiRequestIntent.clipboardAction,
        useClipboardHistory: false,
        useSelectedClipboard: true,
        maxOutputTokens: resolveOutputTokens(
          intent: AiRequestIntent.clipboardAction,
          prompt: prompt,
          featureGroup: featureGroup,
        ),
        responseLanguageTag: responseLanguageTag,
      );
    }

    if (isFollowUp) {
      return AiRequestPlan(
        intent: AiRequestIntent.followUp,
        useClipboardHistory: false,
        useSelectedClipboard: false,
        maxOutputTokens: resolveOutputTokens(
          intent: AiRequestIntent.followUp,
          prompt: prompt,
          featureGroup: featureGroup,
        ),
        responseLanguageTag: responseLanguageTag,
      );
    }

    return AiRequestPlan(
      intent: AiRequestIntent.conversation,
      useClipboardHistory: false,
      useSelectedClipboard: false,
      maxOutputTokens: resolveOutputTokens(
        intent: AiRequestIntent.conversation,
        prompt: prompt,
        featureGroup: featureGroup,
      ),
      responseLanguageTag: responseLanguageTag,
    );
  }

  String? _detectLanguageTag(String prompt) {
    final lower = prompt.toLowerCase();
    const explicitTags = <String, List<String>>{
      'vi-VN': ['tiếng việt', 'vietnamese'],
      'en-US': ['tiếng anh', 'english'],
      'ja-JP': ['tiếng nhật', 'japanese', '日本語'],
      'ko-KR': ['tiếng hàn', 'korean', '한국어'],
      'de-DE': ['tiếng đức', 'german', 'deutsch'],
      'zh-Hans-CN': ['tiếng trung', 'chinese', '中文'],
    };
    for (final entry in explicitTags.entries) {
      if (entry.value.any(lower.contains)) return entry.key;
    }
    if (RegExp(r'[\u3040-\u30ff]').hasMatch(prompt)) return 'ja-JP';
    if (RegExp(r'[\uac00-\ud7af]').hasMatch(prompt)) return 'ko-KR';
    if (RegExp(r'[\u0600-\u06ff]').hasMatch(prompt)) return 'ar-SA';
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(prompt)) return 'zh-Hans-CN';
    return null;
  }

  static const _clipboardTerms = {
    'clipboard',
    'clipbroad',
    'clip',
    'bản',
    'sao',
    'đã',
    'chép',
  };
  static const _searchTerms = {
    'tìm',
    'kiếm',
    'find',
    'search',
    'lọc',
    'liệt',
    'kê',
    'đâu',
    'link',
    'url',
  };
  static const _referenceTerms = {
    'này',
    'đó',
    'trên',
    'vừa',
    'rồi',
    'nó',
    'this',
    'that',
    'above',
    'it',
    'ảnh',
    'hình',
    'photo',
    'image',
    'picture',
    'png',
    'jpg',
    'jpeg',
    'screenshot',
    'tệp',
    'file',
  };
  static const _actionTerms = {
    'dịch',
    'translate',
    'tóm',
    'tắt',
    'summarize',
    'viết',
    'rewrite',
    'sửa',
    'fix',
    'giải',
    'thích',
    'explain',
    'phân',
    'tích',
    'analyze',
    'trích',
    'extract',
  };
  static const _followUpTerms = {
    'tiếp',
    'thêm',
    'rõ',
    'hơn',
    'tại',
    'sao',
    'vậy',
    'còn',
    'why',
    'then',
    'also',
    'else',
    'continue',
    'more',
    'explain',
  };
}
