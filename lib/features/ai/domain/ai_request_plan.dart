import '../../../core/localization/app_translations.dart';
import 'ai_feature_action.dart';

enum AiRequestIntent {
  conversation,
  followUp,
  clipboardSearch,
  clipboardAction,
}

class AiRequestPlan {
  const AiRequestPlan({
    required this.intent,
    required this.useClipboardHistory,
    required this.useSelectedClipboard,
    required this.maxOutputTokens,
    required this.responseLanguage,
  });

  final AiRequestIntent intent;
  final bool useClipboardHistory;
  final bool useSelectedClipboard;
  final int maxOutputTokens;
  final String responseLanguage;
}

class AiRequestPlanner {
  const AiRequestPlanner();

  AiRequestPlan plan({
    required String prompt,
    required bool hasSelectedClipboard,
    required bool hasConversation,
    AiFeatureGroup? featureGroup,
  }) {
    final normalized = prompt.toLowerCase().trim();
    final words = normalized
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toSet();
    final referencesClipboard = words.any(_clipboardTerms.contains);
    final responseLanguage = _detectLanguage(normalized, words);
    final asksToFind = words.any(_searchTerms.contains);
    final asksToTransform = words.any(_actionTerms.contains);
    final referencesCurrentContent = words.any(_referenceTerms.contains);
    final isFollowUp =
        hasConversation &&
        (words.any(_followUpTerms.contains) || referencesCurrentContent);

    if (featureGroup != null) {
      final searchesHistory =
          featureGroup == AiFeatureGroup.qa && !hasSelectedClipboard;
      return AiRequestPlan(
        intent: AiRequestIntent.clipboardAction,
        useClipboardHistory: searchesHistory,
        useSelectedClipboard: hasSelectedClipboard,
        maxOutputTokens: 1536,
        responseLanguage: responseLanguage,
      );
    }

    if (referencesClipboard && asksToFind) {
      return AiRequestPlan(
        intent: AiRequestIntent.clipboardSearch,
        useClipboardHistory: true,
        useSelectedClipboard: false,
        maxOutputTokens: 1536,
        responseLanguage: responseLanguage,
      );
    }

    if (hasSelectedClipboard &&
        (referencesClipboard || referencesCurrentContent || asksToTransform)) {
      return AiRequestPlan(
        intent: AiRequestIntent.clipboardAction,
        useClipboardHistory: false,
        useSelectedClipboard: true,
        maxOutputTokens: 1200,
        responseLanguage: responseLanguage,
      );
    }

    if (isFollowUp) {
      return AiRequestPlan(
        intent: AiRequestIntent.followUp,
        useClipboardHistory: false,
        useSelectedClipboard: false,
        maxOutputTokens: 900,
        responseLanguage: responseLanguage,
      );
    }

    return AiRequestPlan(
      intent: AiRequestIntent.conversation,
      useClipboardHistory: false,
      useSelectedClipboard: false,
      maxOutputTokens: 768,
      responseLanguage: responseLanguage,
    );
  }

  String _detectLanguage(String prompt, Set<String> words) {
    final isEnMode = AppTranslations.currentLanguage == 'en';

    final hasVietnameseAccents = RegExp(
      r'[ăâđêôơưàáạảãằắặẳẵầấậẩẫèéẹẻẽềếệểễìíịỉĩòóọỏõồốộổỗờớợởỡùúụủũừứựửữỳýỵỷỹ]',
    ).hasMatch(prompt);
    final vietnameseWordCount = words.where(_vietnameseWords.contains).length;

    if (hasVietnameseAccents || vietnameseWordCount >= 1) {
      final hasEnglishWords = words.any((w) => [
            'create', 'word', 'make', 'write', 'please', 'help', 'search', 'find',
            'the', 'is', 'for', 'with', 'hello', 'hi', 'translate', 'summarize',
            'perform', 'option', 'rewrite', 'explain'
          ].contains(w));
      if (hasEnglishWords && vietnameseWordCount == 0) {
        return isEnMode ? 'English' : 'Vietnamese';
      }
      return 'Vietnamese';
    }

    if (isEnMode) {
      return 'English';
    }

    if (RegExp(r'^[\x00-\x7F]+$').hasMatch(prompt)) return 'English';
    return 'Vietnamese';
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
  static const _vietnameseWords = {
    'xin',
    'chào',
    'chao',
    'tôi',
    'toi',
    'bạn',
    'ban',
    'cho',
    'với',
    'voi',
    'không',
    'khong',
    'là',
    'la',
    'gì',
    'gi',
    'hãy',
    'hay',
    'cần',
    'can',
  };
}
