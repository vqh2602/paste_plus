import 'dart:math';

typedef AiTokenizer = Future<List<int>> Function(String text);
typedef AiDetokenizer = Future<String> Function(List<int> tokens);

enum AiTokenTask {
  direct,
  hierarchicalSummary,
  retrievalQa,
  losslessTranslation,
  contextualRewrite,
  rollingChat,
  mapReduce,
}

class AiTokenChunk {
  const AiTokenChunk({
    required this.text,
    required this.leadingContext,
    required this.index,
    required this.total,
    required this.tokenCount,
  });

  final String text;
  final String leadingContext;
  final int index;
  final int total;
  final int tokenCount;
}

class AiTokenBudget {
  const AiTokenBudget({
    required this.contextWindow,
    required this.outputReserve,
    required this.safetyReserve,
  });

  final int contextWindow;
  final int outputReserve;
  final int safetyReserve;

  int get maximumPromptTokens =>
      max(256, contextWindow - outputReserve - safetyReserve);

  bool accepts(int promptTokens) => promptTokens <= maximumPromptTokens;
}

/// Applies the tokenizer belonging to the loaded model before any inference.
///
/// Prompt-template counting remains in [LlamaInferenceService], while this
/// class owns token-safe slicing and per-task budget policy.
class AiTokenBudgetManager {
  const AiTokenBudgetManager({
    required AiTokenizer tokenize,
    required AiDetokenizer detokenize,
  }) : _tokenize = tokenize,
       _detokenize = detokenize;

  final AiTokenizer _tokenize;
  final AiDetokenizer _detokenize;

  AiTokenBudget budgetFor({
    required int contextWindow,
    required int requestedOutputTokens,
  }) {
    final safeContext = max(1024, contextWindow);
    final output = requestedOutputTokens.clamp(128, safeContext ~/ 3);
    final safety = max(96, min(384, safeContext ~/ 16));
    return AiTokenBudget(
      contextWindow: safeContext,
      outputReserve: output,
      safetyReserve: safety,
    );
  }

  AiTokenTask taskFor({
    required String intentName,
    required String prompt,
    String? featureName,
    String? selectedOption,
  }) {
    final requestedAction = '${selectedOption ?? ''} $prompt'.toLowerCase();
    if (featureName == 'ocrRefine') {
      if (_containsAny(requestedAction, const ['tóm tắt', 'summar'])) {
        return AiTokenTask.hierarchicalSummary;
      }
      if (_containsAny(requestedAction, const ['dịch', 'translat'])) {
        return AiTokenTask.losslessTranslation;
      }
      return AiTokenTask.contextualRewrite;
    }
    if (featureName == null && intentName == 'clipboardAction') {
      if (_containsAny(requestedAction, const ['dịch', 'translat'])) {
        return AiTokenTask.losslessTranslation;
      }
      if (_containsAny(requestedAction, const ['tóm tắt', 'summar'])) {
        return AiTokenTask.hierarchicalSummary;
      }
      if (_containsAny(requestedAction, const [
        'viết lại',
        'rewrite',
        'chính tả',
        'grammar',
      ])) {
        return AiTokenTask.contextualRewrite;
      }
    }
    return switch (featureName) {
      'summary' => AiTokenTask.hierarchicalSummary,
      'translate' => AiTokenTask.losslessTranslation,
      'rewrite' || 'grammar' || 'ocrRefine' => AiTokenTask.contextualRewrite,
      'qa' || 'codeExplain' => AiTokenTask.retrievalQa,
      'extractInfo' || 'titlesTags' || 'classify' => AiTokenTask.mapReduce,
      _ when intentName == 'clipboardSearch' => AiTokenTask.retrievalQa,
      _ when intentName == 'followUp' || intentName == 'conversation' =>
        AiTokenTask.rollingChat,
      _ => AiTokenTask.mapReduce,
    };
  }

  bool _containsAny(String value, List<String> needles) =>
      needles.any(value.contains);

  Future<int> countText(String text) async => (await _tokenize(text)).length;

  Future<List<AiTokenChunk>> chunkText(
    String text, {
    required int maximumTokens,
    int overlapTokens = 0,
  }) async {
    final tokens = await _tokenize(text);
    if (tokens.isEmpty) return const [];
    final chunkSize = max(64, maximumTokens);
    final overlap = overlapTokens.clamp(0, max(0, chunkSize ~/ 4)).toInt();
    final cores = <List<int>>[];
    for (var start = 0; start < tokens.length; start += chunkSize) {
      cores.add(tokens.sublist(start, min(start + chunkSize, tokens.length)));
    }

    final chunks = <AiTokenChunk>[];
    for (var index = 0; index < cores.length; index++) {
      final core = cores[index];
      final leading = index == 0 || overlap == 0
          ? const <int>[]
          : cores[index - 1].sublist(max(0, cores[index - 1].length - overlap));
      chunks.add(
        AiTokenChunk(
          text: await _detokenize(core),
          leadingContext: leading.isEmpty ? '' : await _detokenize(leading),
          index: index,
          total: cores.length,
          tokenCount: core.length,
        ),
      );
    }
    return chunks;
  }

  Future<String> truncateToTokens(String text, int maximumTokens) async {
    final tokens = await _tokenize(text);
    if (tokens.length <= maximumTokens) return text;
    return _detokenize(tokens.take(maximumTokens).toList(growable: false));
  }
}
