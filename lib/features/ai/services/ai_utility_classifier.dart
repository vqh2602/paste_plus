import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/ai_model_info.dart';
import '../domain/ai_request_classification.dart';
import '../domain/ai_request_intent.dart';
import '../localization/ai_locale_spec.dart';
import 'ai_model_downloader_service.dart';
import 'llama_inference_service.dart';

class AiUtilityClassifier {
  AiUtilityClassifier(this._downloader, this._inference);

  final AiModelDownloaderService _downloader;
  final LlamaInferenceService _inference;
  final Map<String, _CachedClassification> _cache = {};

  /// The dedicated lightweight model used exclusively for request classification.
  /// Kept separate from the user's chosen answer model.
  static const utilityModelId = 'qwen3-0.6b';
  static const _cacheLifetime = Duration(minutes: 10);

  Future<AiRequestClassification> classify({
    required String prompt,
    required String appLanguageTag,
    required AiModelInfo fallbackModel,
    bool hasSelectedClipboard = false,
  }) async {
    final key = sha256
        .convert(
          utf8.encode('$appLanguageTag\n$hasSelectedClipboard\n${prompt.trim()}'),
        )
        .toString();
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheLifetime) {
      return cached.value;
    }

    final fallback = fallbackClassification(
      prompt: prompt,
      appLanguageTag: appLanguageTag,
      hasSelectedClipboard: hasSelectedClipboard,
    );
    final utilityModel = AiModelInfo.findById(utilityModelId);
    final isUtilityDownloaded = await _downloader.isModelDownloaded(
      utilityModel.id,
    );
    final isFallbackDownloaded = await _downloader.isModelDownloaded(
      fallbackModel.id,
    );
    final model = isUtilityDownloaded
        ? utilityModel
        : (isFallbackDownloaded ? fallbackModel : null);
    if (model == null) return fallback;

    final modelFile = await _downloader.getModelFile(model.id);
    if (!await modelFile.exists()) return fallback;
    final buffer = StringBuffer();
    try {
      await for (final token in _inference
          .generate(
            modelPath: modelFile.path,
            contextSize: 1024,
            systemPrompt: _systemPrompt,
            userPrompt: prompt,
            temperature: 0,
            maxTokens: 64,
            thinkingModel: false,
            grammar: _grammar,
          )
          .timeout(const Duration(seconds: 2))) {
        buffer.write(token.content ?? '');
      }
      final parsed = _parse(buffer.toString(), fallback);
      _cache[key] = _CachedClassification(DateTime.now(), parsed);
      return parsed;
    } on Object {
      return fallback;
    }
  }

  AiRequestClassification _parse(
    String source,
    AiRequestClassification fallback,
  ) {
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    final intent = switch (decoded['intent']) {
      'follow_up' => AiRequestIntent.followUp,
      'clipboard_search' => AiRequestIntent.clipboardSearch,
      'clipboard_action' => AiRequestIntent.clipboardAction,
      _ => AiRequestIntent.conversation,
    };
    final reasoning = switch (decoded['reasoning_level']) {
      'medium' => AiReasoningLevel.medium,
      'high' => AiReasoningLevel.high,
      _ => AiReasoningLevel.low,
    };
    return AiRequestClassification(
      languageTag: AiLanguageRegistry.normalizeTag(
        decoded['language'] as String? ?? fallback.languageTag,
      ),
      intent: intent,
      reasoningLevel: reasoning,
      needsPlanner: decoded['needs_planner'] == true,
      needsClipboard: decoded['needs_clipboard'] == true,
      preferImageUrls: decoded['prefer_image_urls'] == true,
    );
  }

  static const _systemPrompt = '''Classify the user request. Return JSON only.
Fields: language (BCP-47), intent (conversation, follow_up, clipboard_search, clipboard_action), reasoning_level (low, medium, high), needs_planner, needs_clipboard, prefer_image_urls.
needs_planner is true for tools, dependent multi-step work, or clipboard operations.
needs_clipboard is true when the user wants to find, filter, list, count, or analyse clipboard items — even if no specific clipboard item is currently selected.
prefer_image_urls is true when user asks for image links, image URLs, or clipboards containing images/photos (e.g. "tìm clipboard có link ảnh", "find clips with image links").
Use intent=clipboard_search when user asks to filter/find across all clipboard history. Examples: "find clips with image links", "which clipboard has an API key", "clipboard longer than 10 chars", "list all image clipboards", "tìm clipboard có link ảnh", "clipboard nào dài hơn 10 ký tự", "clipboard chứa api key".
Use intent=clipboard_action when user wants to transform a selected clipboard item.
Use intent=conversation for general questions not related to clipboard history.
Do not answer the user.''';

  static const _grammar = r'''
root ::= "{" ws "\"language\"" ws ":" ws string ws "," ws "\"intent\"" ws ":" ws intent ws "," ws "\"reasoning_level\"" ws ":" ws reasoning ws "," ws "\"needs_planner\"" ws ":" ws boolean ws "," ws "\"needs_clipboard\"" ws ":" ws boolean ws "," ws "\"prefer_image_urls\"" ws ":" ws boolean ws "}"
intent ::= "\"conversation\"" | "\"follow_up\"" | "\"clipboard_search\"" | "\"clipboard_action\""
reasoning ::= "\"low\"" | "\"medium\"" | "\"high\""
boolean ::= "true" | "false"
string ::= "\"" chars "\""
chars ::= ([^"\\] | "\\" ["\\/bfnrt])*
ws ::= [ \t\n\r]*
''';
}

class _CachedClassification {
  const _CachedClassification(this.createdAt, this.value);
  final DateTime createdAt;
  final AiRequestClassification value;
}
