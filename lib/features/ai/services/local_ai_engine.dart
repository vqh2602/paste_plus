import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/services/ai_debug_service.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../../clipboard_history/domain/clipboard_repository.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_model_info.dart';
import '../domain/ai_request_plan.dart';
import '../domain/ai_chat_message.dart';
import 'ai_agent_orchestrator.dart';
import 'ai_clipboard_relevance_ranker.dart';
import 'ai_model_downloader_service.dart';
import 'ai_plan_validator.dart';
import 'ai_planner_service.dart';
import 'ai_prompts.dart';
import 'ai_token_budget_manager.dart';
import 'ai_response_verifier.dart';
import 'hybrid_semantic_search.dart';
import 'llama_inference_service.dart';
import 'structured_output_validator.dart';

class LocalAiResponse {
  LocalAiResponse({required this.thinkingContent, required this.outputContent});

  final String thinkingContent;
  final String outputContent;
}

class LocalAiEngine {
  LocalAiEngine([
    this._modelDownloader,
    this._debug,
    LlamaInferenceService? inferenceService,
    HybridSemanticSearch? hybridSearch,
    ClipboardRepository? repository,
  ]) : _inferenceService =
           inferenceService ??
           (_modelDownloader == null ? null : LlamaInferenceService()),
       _hybridSearch = hybridSearch ?? const HybridSemanticSearch(),
       _agentOrchestrator = AiAgentOrchestrator(repository);

  final AiModelDownloaderService? _modelDownloader;
  final AiDebugController? _debug;
  final LlamaInferenceService? _inferenceService;
  final HybridSemanticSearch _hybridSearch;
  final AiAgentOrchestrator _agentOrchestrator;
  static const _clipboardRanker = AiClipboardRelevanceRanker();
  static const _plannerService = AiPlannerService();
  static const _outputValidator = StructuredOutputValidator();
  static const _responseVerifier = AiResponseVerifier();

  /// Process prompt locally and stream tokens back.
  /// Yields pairs of (thinkingChunk, outputChunk).
  Stream<Map<String, String>> processStream({
    required AiModelInfo model,
    required String prompt,
    ClipboardItem? clipboardContext,
    List<ClipboardItem> clipboardHistory = const [],
    AiFeatureGroup? featureGroup,
    String? selectedOption,
    String conversationContext = '',
    double temperature = 0.55,
    int? contextSize,
    AiRequestPlan? requestPlan,
    List<AiChatMessage> conversationMessages = const [],
    String? debugRequestId,
    Future<bool> Function(String toolName, Map<String, dynamic> arguments)?
    onConfirmationRequested,
  }) async* {
    final initialPlan =
        requestPlan ??
        _plannerService.createPlan(
          prompt: prompt,
          hasSelectedClipboard: clipboardContext != null,
          hasConversation:
              conversationContext.isNotEmpty || conversationMessages.isNotEmpty,
          featureGroup: featureGroup,
        );

    var effectivePlan = initialPlan;

    if (requestPlan == null &&
        _plannerService.shouldUseModelPlanner(
          prompt: prompt,
          hasSelectedClipboard: clipboardContext != null,
          featureGroup: featureGroup,
        )) {
      final rawPlanJson = await _generatePlannerJson(
        model: model,
        prompt: prompt,
        responseLanguage: initialPlan.responseLanguage,
        contextSize: contextSize ?? model.contextWindow,
        debugRequestId: debugRequestId,
      );

      if (rawPlanJson != null && rawPlanJson.trim().isNotEmpty) {
        effectivePlan = _plannerService.createPlan(
          prompt: prompt,
          hasSelectedClipboard: clipboardContext != null,
          hasConversation:
              conversationContext.isNotEmpty || conversationMessages.isNotEmpty,
          featureGroup: featureGroup,
          rawModelPlanJson: rawPlanJson,
        );
      }
    }

    final effectiveClipboardContext = effectivePlan.useSelectedClipboard
        ? clipboardContext
        : null;
    final effectiveHistory = effectivePlan.useClipboardHistory
        ? clipboardHistory
        : const <ClipboardItem>[];

    List<String> imagePaths = const [];
    if (effectiveClipboardContext?.imagePath != null &&
        effectiveClipboardContext!.imagePath!.isNotEmpty) {
      final imgFile = File(effectiveClipboardContext.imagePath!);
      if (await imgFile.exists()) {
        imagePaths = [imgFile.path];
      }
    }

    String? mmprojPath;
    if (model.isMultimodalVision && _modelDownloader != null) {
      final mmFile = await _modelDownloader.getMmprojFile(model.id);
      if (await mmFile.exists()) {
        mmprojPath = mmFile.path;
      }
    }

    late String contextText;
    if (effectiveClipboardContext != null) {
      if (effectiveClipboardContext.contentType == ClipboardContentType.image) {
        final fileName = effectiveClipboardContext.imagePath != null
            ? effectiveClipboardContext.imagePath!
                  .split(Platform.pathSeparator)
                  .last
            : 'image.png';
        final ocrContent = effectiveClipboardContext.content.trim();
        final hasText = ocrContent.isNotEmpty && ocrContent != '[Image]';
        final sourceApp = effectiveClipboardContext.sourceAppName ?? 'Unknown';

        contextText =
            '''
[Dữ liệu hình ảnh Multimodal & OCR đính kèm làm ngữ cảnh]
- Nguồn: $sourceApp
- Tên tệp hình ảnh: $fileName
- Đường dẫn tệp: ${effectiveClipboardContext.imagePath ?? 'N/A'}
- Nội dung văn bản trích xuất qua OCR (Dữ liệu hỗ trợ thứ cấp):
${hasText ? '"""\n$ocrContent\n"""' : '(Không phát hiện văn bản hoặc hình ảnh là biểu đồ/họa tiết/giao diện)'}

[Hướng dẫn phân tích]: Pixel hình ảnh thực tế đã được nạp trực tiếp vào Multimodal Vision LLM. Hãy sử dụng cả khả năng nhìn ảnh thực tế và dữ liệu OCR hỗ trợ ở trên để phân tích giao diện, biểu đồ, hình ảnh hoặc giải đáp câu hỏi của người dùng.
''';
      } else {
        contextText = effectiveClipboardContext.content.trim();
      }

      if (effectiveHistory.isNotEmpty) {
        contextText =
            '$contextText\n\n[Lịch sử Clipboard liên quan bổ sung]:\n${_buildHistoryContext(effectiveHistory)}';
      }
    } else {
      contextText = _buildHistoryContext(effectiveHistory);
    }

    final executionPlan = effectivePlan.executionPlan;
    if (executionPlan != null &&
        executionPlan.steps.isNotEmpty &&
        executionPlan.steps.every(
          (step) => AiPlanValidator.supportedTools.contains(step.tool),
        )) {
      final stepResults = await _agentOrchestrator.executePlan(
        plan: executionPlan,
        prompt: prompt,
        contextText: contextText,
        clipboardHistory: effectiveHistory,
        onConfirmationRequested: onConfirmationRequested,
      );
      contextText = _agentOrchestrator.synthesizeContext(
        stepResults,
        contextText,
      );
    }

    final systemPrompt = _buildSystemPrompt(
      featureGroup,
      selectedOption,
      conversationContext,
      effectivePlan.intent,
      effectivePlan.responseLanguage,
    );
    _debug?.log(
      level: AiDebugLevel.info,
      stage: 'engine',
      requestId: debugRequestId,
      message: 'Đã dựng prompt cho inference',
      details: kReleaseMode
          ? 'model_id: ${model.id}\ncontext_items_count: ${effectiveHistory.length}\ncontext_length: ${contextText.length}'
          : 'systemPrompt:\n$systemPrompt\n\n'
                'userPrompt:\n$prompt\n\n'
                'contextText (${contextText.length} chars):\n$contextText\n\n'
                'conversationContext (${conversationContext.length} chars):\n'
                '$conversationContext',
    );

    if (_modelDownloader != null && _inferenceService != null) {
      final modelFile = await _modelDownloader.getModelFile(model.id);
      final fileExists = await modelFile.exists();
      final fileSize = fileExists ? await modelFile.length() : 0;
      _debug?.log(
        level: fileExists ? AiDebugLevel.info : AiDebugLevel.warning,
        stage: 'model-file',
        requestId: debugRequestId,
        message: fileExists
            ? 'Đã tìm thấy file model'
            : 'Không tìm thấy file model',
        details: 'path: ${modelFile.path}\nsizeBytes: $fileSize',
      );
      if (fileExists && fileSize > 10 * 1024 * 1024) {
        final effectiveContextSize = contextSize ?? model.contextWindow;
        final caps = await _inferenceService.prepareModel(
          modelFile.path,
          effectiveContextSize,
          mmprojPath: mmprojPath,
        );
        _debug?.log(
          level: AiDebugLevel.success,
          stage: 'model-load',
          requestId: debugRequestId,
          message: 'Model đã sẵn sàng',
          details:
              'contextSize: $effectiveContextSize\nmultimodalReady: ${caps.multimodalReady}',
        );

        if (effectiveClipboardContext?.contentType ==
                ClipboardContentType.image &&
            (!caps.multimodalReady || imagePaths.isEmpty)) {
          contextText = contextText.replaceAll(
            '[Hướng dẫn phân tích]: Pixel hình ảnh thực tế đã được nạp trực tiếp vào Multimodal Vision LLM.',
            '[Lưu ý phân tích]: Không thể nạp vision projector. Phân tích này chỉ dựa trên OCR và metadata đính kèm.',
          );
        }

        final budgetManager = AiTokenBudgetManager(
          tokenize: _inferenceService.tokenize,
          detokenize: _inferenceService.detokenize,
        );
        if (effectiveClipboardContext == null && effectiveHistory.isNotEmpty) {
          final semanticItems = await _semanticRank(
            prompt: prompt,
            items: effectiveHistory,
            modelPath: modelFile.path,
            contextSize: effectiveContextSize,
            modelId: model.id,
          );
          contextText = _buildHistoryContext(semanticItems);
          _debug?.log(
            level: AiDebugLevel.info,
            stage: 'retrieval',
            requestId: debugRequestId,
            message: 'Đã xếp hạng semantic clipboard history',
            details: kReleaseMode
                ? 'inputItems: ${effectiveHistory.length}\nselectedItems: ${semanticItems.length}'
                : 'inputItems: ${effectiveHistory.length}\n'
                      'selectedItems: ${semanticItems.length}\n'
                      'effectiveContext:\n$contextText',
          );
        }

        yield* _runBudgetedModel(
          modelPath: modelFile.path,
          contextSize: effectiveContextSize,
          systemPrompt: systemPrompt,
          prompt: prompt,
          contextText: contextText,
          featureGroup: featureGroup,
          selectedOption: selectedOption,
          requestPlan: effectivePlan,
          budgetManager: budgetManager,
          temperature: temperature,
          maxOutputTokens: effectivePlan.maxOutputTokens,
          thinkingModel: model.isThinkingModel,
          conversationMessages: conversationMessages,
          debugRequestId: debugRequestId,
          imagePaths: imagePaths,
          mmprojPath: mmprojPath,
          candidates: effectiveHistory,
          onConfirmationRequested: onConfirmationRequested,
        );
        return;
      }
    }

    if (kReleaseMode) {
      _debug?.log(
        level: AiDebugLevel.error,
        stage: 'engine',
        requestId: debugRequestId,
        message: 'Model chưa được cài đặt hoặc không thể khởi động',
      );
      yield {
        'thinking': '',
        'output': AppTranslations.currentLanguage == 'en'
            ? 'The local AI model is not installed or failed to initialize. Please download a model in AI Settings.'
            : 'Model AI chưa được cài đặt hoặc không thể khởi động. Vui lòng tải xuống model trong Cài đặt AI.',
      };
      return;
    }

    _debug?.log(
      level: AiDebugLevel.warning,
      stage: 'engine',
      requestId: debugRequestId,
      message: 'Đang dùng bộ sinh mô phỏng vì model local chưa sẵn sàng',
    );

    // Stream local LLM thinking & generation based on systemPrompt
    final isThinkingModel = model.isThinkingModel;

    final thinkingStream = _generateThinkingProcess(
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      prompt: prompt,
      contextText: contextText,
      historyItemCount: effectiveHistory.length,
      systemPrompt: systemPrompt,
      hasConversationContext: conversationContext.isNotEmpty,
    );

    var accumulatedThinking = StringBuffer();
    if (isThinkingModel) {
      for (final chunk in thinkingStream) {
        accumulatedThinking.write(chunk);
        yield {
          'type': 'think',
          'chunk': chunk,
          'thinking': accumulatedThinking.toString(),
          'output': '',
        };
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }
    }

    final outputStream = _generateOutputResult(
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      prompt: prompt,
      contextText: contextText,
      clipboardHistory: effectiveHistory,
      model: model,
      conversationContext: conversationContext,
    );

    var accumulatedOutput = StringBuffer();
    for (final chunk in outputStream) {
      accumulatedOutput.write(chunk);
      yield {
        'type': 'output',
        'chunk': chunk,
        'thinking': accumulatedThinking.toString(),
        'output': accumulatedOutput.toString(),
      };
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Stream<Map<String, String>> _runBudgetedModel({
    required String modelPath,
    required int contextSize,
    required String systemPrompt,
    required String prompt,
    required String contextText,
    required AiFeatureGroup? featureGroup,
    required String? selectedOption,
    required AiRequestPlan? requestPlan,
    required AiTokenBudgetManager budgetManager,
    required double temperature,
    required int maxOutputTokens,
    required bool thinkingModel,
    required List<AiChatMessage> conversationMessages,
    String? debugRequestId,
    List<String> imagePaths = const [],
    String? mmprojPath,
    List<ClipboardItem> candidates = const [],
    Future<bool> Function(String toolName, Map<String, dynamic> arguments)?
    onConfirmationRequested,
  }) async* {
    final conversation = _toConversationTurns(conversationMessages);
    final userPrompt = _buildModelUserPrompt(prompt, contextText);
    final grammar = (requestPlan?.intent == AiRequestIntent.clipboardSearch)
        ? StructuredOutputValidator.searchJsonGrammar
        : null;
    final responseLanguage = requestPlan?.responseLanguage ?? 'vi';
    final intent = requestPlan?.intent;

    final budget = budgetManager.budgetFor(
      contextWindow: contextSize,
      requestedOutputTokens: maxOutputTokens,
    );
    final promptTokens = await _inferenceService!.countChatTokens(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      thinkingModel: thinkingModel,
      conversation: conversation,
    );

    _debug?.log(
      level: AiDebugLevel.info,
      stage: 'token-budget',
      requestId: debugRequestId,
      message: 'Đã tính token budget',
      details:
          'promptTokens: $promptTokens\n'
          'contextWindow: ${budget.contextWindow}\n'
          'maximumPromptTokens: ${budget.maximumPromptTokens}\n'
          'outputReserve: ${budget.outputReserve}\n'
          'safetyReserve: ${budget.safetyReserve}\n'
          'acceptedDirectly: ${budget.accepts(promptTokens)}',
    );

    if (budget.accepts(promptTokens)) {
      _debug?.log(
        level: AiDebugLevel.info,
        stage: 'strategy',
        requestId: debugRequestId,
        message: 'Chọn chiến lược direct',
      );
      yield* _streamModelCall(
        modelPath: modelPath,
        contextSize: contextSize,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        conversation: conversation,
        temperature: temperature,
        maxTokens: budget.outputReserve,
        thinkingModel: thinkingModel,
        grammar: grammar,
        mmprojPath: mmprojPath,
        imagePaths: imagePaths,
        candidates: candidates,
        responseLanguage: responseLanguage,
        intent: intent,
      );
      return;
    }

    final task = budgetManager.taskFor(
      intentName: (requestPlan?.intent ?? AiRequestIntent.conversation).name,
      prompt: prompt,
      featureName: featureGroup?.name,
      selectedOption: selectedOption,
    );
    _debug?.log(
      level: AiDebugLevel.warning,
      stage: 'strategy',
      requestId: debugRequestId,
      message: 'Prompt vượt budget, chọn chiến lược ${task.name}',
      details: 'promptTokens: $promptTokens',
    );
    switch (task) {
      case AiTokenTask.losslessTranslation:
        yield* _translateInChunks(
          modelPath: modelPath,
          contextSize: contextSize,
          prompt: prompt,
          text: contextText,
          selectedOption: selectedOption,
          manager: budgetManager,
          temperature: temperature,
          thinkingModel: thinkingModel,
          outputTokens: budget.outputReserve,
        );
        return;
      case AiTokenTask.contextualRewrite:
        yield* _rewriteInChunks(
          modelPath: modelPath,
          contextSize: contextSize,
          prompt: prompt,
          text: contextText,
          selectedOption: selectedOption,
          manager: budgetManager,
          temperature: temperature,
          thinkingModel: thinkingModel,
          outputTokens: budget.outputReserve,
        );
        return;
      case AiTokenTask.hierarchicalSummary:
        final compressed = await _hierarchicalSummarize(
          modelPath: modelPath,
          contextSize: contextSize,
          text: contextText,
          manager: budgetManager,
          temperature: temperature,
          thinkingModel: thinkingModel,
        );
        yield* _streamModelCall(
          modelPath: modelPath,
          contextSize: contextSize,
          systemPrompt: systemPrompt,
          userPrompt: _buildModelUserPrompt(prompt, compressed),
          temperature: temperature,
          maxTokens: budget.outputReserve,
          thinkingModel: thinkingModel,
          grammar: grammar,
          mmprojPath: mmprojPath,
          imagePaths: imagePaths,
          candidates: candidates,
          responseLanguage: responseLanguage,
          intent: intent,
        );
        return;
      case AiTokenTask.retrievalQa:
        final relevant = await _retrieveRelevantText(
          modelPath: modelPath,
          contextSize: contextSize,
          query: prompt,
          text: contextText,
          manager: budgetManager,
          maximumTokens: await _contentCapacity(
            systemPrompt: systemPrompt,
            prompt: prompt,
            budget: budget,
            thinkingModel: thinkingModel,
          ),
        );
        yield* _streamModelCall(
          modelPath: modelPath,
          contextSize: contextSize,
          systemPrompt: systemPrompt,
          userPrompt: _buildModelUserPrompt(prompt, relevant),
          temperature: temperature,
          maxTokens: budget.outputReserve,
          thinkingModel: thinkingModel,
          grammar: grammar,
          mmprojPath: mmprojPath,
          imagePaths: imagePaths,
          candidates: candidates,
          responseLanguage: responseLanguage,
          intent: intent,
        );
        return;
      case AiTokenTask.rollingChat:
        if (conversation.isEmpty) {
          final compactPrompt = await _hierarchicalSummarize(
            modelPath: modelPath,
            contextSize: contextSize,
            text: prompt,
            manager: budgetManager,
            temperature: temperature,
            thinkingModel: thinkingModel,
          );
          yield* _streamModelCall(
            modelPath: modelPath,
            contextSize: contextSize,
            systemPrompt: systemPrompt,
            userPrompt: 'Respond to this compacted request:\n$compactPrompt',
            temperature: temperature,
            maxTokens: budget.outputReserve,
            thinkingModel: thinkingModel,
            grammar: grammar,
            mmprojPath: mmprojPath,
            imagePaths: imagePaths,
            candidates: candidates,
            responseLanguage: responseLanguage,
            intent: intent,
          );
          return;
        }
        final fittedConversation = await _fitRollingConversation(
          modelPath: modelPath,
          contextSize: contextSize,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          conversation: conversation,
          manager: budgetManager,
          budget: budget,
          temperature: temperature,
          thinkingModel: thinkingModel,
        );
        yield* _streamModelCall(
          modelPath: modelPath,
          contextSize: contextSize,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          conversation: fittedConversation,
          temperature: temperature,
          maxTokens: budget.outputReserve,
          thinkingModel: thinkingModel,
          grammar: grammar,
          mmprojPath: mmprojPath,
          imagePaths: imagePaths,
          candidates: candidates,
          responseLanguage: responseLanguage,
          intent: intent,
        );
        return;
      case AiTokenTask.mapReduce:
        final reduced = await _mapReduceContext(
          modelPath: modelPath,
          contextSize: contextSize,
          prompt: prompt,
          text: contextText,
          manager: budgetManager,
          temperature: temperature,
          thinkingModel: thinkingModel,
        );
        yield* _streamModelCall(
          modelPath: modelPath,
          contextSize: contextSize,
          systemPrompt: systemPrompt,
          userPrompt: _buildModelUserPrompt(prompt, reduced),
          temperature: temperature,
          maxTokens: budget.outputReserve,
          thinkingModel: thinkingModel,
          grammar: grammar,
          mmprojPath: mmprojPath,
          imagePaths: imagePaths,
          candidates: candidates,
          responseLanguage: responseLanguage,
          intent: intent,
        );
        return;
      case AiTokenTask.direct:
        yield* _streamModelCall(
          modelPath: modelPath,
          contextSize: contextSize,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          conversation: conversation,
          temperature: temperature,
          maxTokens: budget.outputReserve,
          thinkingModel: thinkingModel,
          grammar: grammar,
          mmprojPath: mmprojPath,
          imagePaths: imagePaths,
          candidates: candidates,
          responseLanguage: responseLanguage,
          intent: intent,
        );
        return;
    }
  }

  String _buildModelUserPrompt(String prompt, String contextText) {
    final requestLabel = AiPrompts.userRequestLabel();
    final buffer = StringBuffer()..writeln('$requestLabel $prompt');
    if (contextText.trim().isNotEmpty) {
      buffer.write(AiPrompts.wrapUntrustedClipboard(contextText));
    }
    return buffer.toString();
  }

  String buildModelUserPromptForTest(String prompt, String contextText) =>
      _buildModelUserPrompt(prompt, contextText);

  List<LlamaConversationTurn> _toConversationTurns(
    List<AiChatMessage> messages,
  ) => [
    for (final message in messages)
      LlamaConversationTurn(
        isUser: message.role == AiMessageRole.user,
        text: message.content,
      ),
  ];

  Stream<Map<String, String>> _streamModelCall({
    required String modelPath,
    required int contextSize,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
    required bool thinkingModel,
    List<LlamaConversationTurn> conversation = const [],
    String initialOutput = '',
    String? grammar,
    String? mmprojPath,
    List<String> imagePaths = const [],
    List<ClipboardItem> candidates = const [],
    String responseLanguage = 'vi',
    AiRequestIntent? intent,
  }) async* {
    var output = initialOutput;
    var accumulatedThinking = '';
    final safeMaxTokens = await _safeGenerationTokens(
      contextSize: contextSize,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      conversation: conversation,
      requestedMaxTokens: maxTokens,
      thinkingModel: thinkingModel,
    );
    await for (final token in _inferenceService!.generate(
      modelPath: modelPath,
      contextSize: contextSize,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: safeMaxTokens,
      thinkingModel: thinkingModel,
      conversation: conversation,
      grammar: grammar,
      mmprojPath: mmprojPath,
      imagePaths: imagePaths,
    )) {
      if (token.content?.isNotEmpty == true) output += token.content!;
      if (token.thinking?.isNotEmpty == true) {
        accumulatedThinking += token.thinking!;
      }
      yield {
        'type': token.content?.isNotEmpty == true ? 'output' : 'think',
        'chunk': token.content ?? token.thinking ?? '',
        'thinking': accumulatedThinking,
        'output': output,
      };
    }
    if (output.trim().isEmpty) {
      throw StateError('Model kết thúc mà không tạo nội dung trả lời.');
    }

    final requiresJson =
        (grammar != null) || (intent == AiRequestIntent.clipboardSearch);
    final report = _responseVerifier.verifyAndCorrect(
      draftText: output,
      candidates: candidates,
      responseLanguage: responseLanguage,
      requiresJson: requiresJson,
    );

    if (report.correctedText != output) {
      output = report.correctedText;
      yield {
        'type': 'output',
        'chunk': '',
        'thinking': accumulatedThinking,
        'output': output,
      };
    }
  }

  Future<String> _collectModelCall({
    required String modelPath,
    required int contextSize,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
    required bool thinkingModel,
    List<LlamaConversationTurn> conversation = const [],
  }) async {
    final output = StringBuffer();
    final safeMaxTokens = await _safeGenerationTokens(
      contextSize: contextSize,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      conversation: conversation,
      requestedMaxTokens: maxTokens,
      thinkingModel: thinkingModel,
    );
    await for (final token in _inferenceService!.generate(
      modelPath: modelPath,
      contextSize: contextSize,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature,
      maxTokens: safeMaxTokens,
      thinkingModel: thinkingModel,
      conversation: conversation,
    )) {
      if (token.content?.isNotEmpty == true) output.write(token.content);
    }
    if (output.toString().trim().isEmpty) {
      throw StateError('Model kết thúc mà không tạo nội dung trả lời.');
    }
    return output.toString().trim();
  }

  Future<int> _safeGenerationTokens({
    required int contextSize,
    required String systemPrompt,
    required String userPrompt,
    required List<LlamaConversationTurn> conversation,
    required int requestedMaxTokens,
    required bool thinkingModel,
  }) async {
    final promptTokens = await _inferenceService!.countChatTokens(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      conversation: conversation,
      thinkingModel: thinkingModel,
    );
    final available = contextSize - promptTokens - 64;
    if (available < 64) {
      throw StateError(
        'Prompt vẫn vượt context sau khi áp dụng token budget '
        '($promptTokens/$contextSize token).',
      );
    }
    return min(requestedMaxTokens, available);
  }

  Future<int> _contentCapacity({
    required String systemPrompt,
    required String prompt,
    required AiTokenBudget budget,
    required bool thinkingModel,
  }) async {
    final emptyPromptTokens = await _inferenceService!.countChatTokens(
      systemPrompt: systemPrompt,
      userPrompt: _buildModelUserPrompt(prompt, ''),
      thinkingModel: thinkingModel,
    );
    return max(128, budget.maximumPromptTokens - emptyPromptTokens - 48);
  }

  Stream<Map<String, String>> _translateInChunks({
    required String modelPath,
    required int contextSize,
    required String prompt,
    required String text,
    required String? selectedOption,
    required AiTokenBudgetManager manager,
    required double temperature,
    required bool thinkingModel,
    required int outputTokens,
  }) async* {
    final chunkTokens = max(128, min(outputTokens * 3 ~/ 4, contextSize ~/ 3));
    final chunks = await manager.chunkText(text, maximumTokens: chunkTokens);
    var output = '';
    for (final chunk in chunks) {
      final translated = await _collectModelCall(
        modelPath: modelPath,
        contextSize: contextSize,
        systemPrompt: AiPrompts.translateChunkSystemPrompt(
          selectedOption,
          prompt,
        ),
        userPrompt:
            '<chunk index="${chunk.index + 1}" total="${chunk.total}">\n'
            '${chunk.text}\n</chunk>',
        temperature: min(temperature, 0.35),
        maxTokens: max(outputTokens, chunk.tokenCount + 128),
        thinkingModel: thinkingModel,
      );
      output += '${output.isEmpty ? '' : '\n'}$translated';
      yield {
        'type': 'output',
        'chunk': translated,
        'thinking': '',
        'output': output,
      };
    }
  }

  Stream<Map<String, String>> _rewriteInChunks({
    required String modelPath,
    required int contextSize,
    required String prompt,
    required String text,
    required String? selectedOption,
    required AiTokenBudgetManager manager,
    required double temperature,
    required bool thinkingModel,
    required int outputTokens,
  }) async* {
    final chunkTokens = max(128, min(outputTokens * 3 ~/ 4, contextSize ~/ 3));
    final chunks = await manager.chunkText(
      text,
      maximumTokens: chunkTokens,
      overlapTokens: 48,
    );
    var output = '';
    for (final chunk in chunks) {
      final leading = chunk.leadingContext.isEmpty
          ? ''
          : '<continuity_context>\n${chunk.leadingContext}\n'
                '</continuity_context>\n';
      final rewritten = await _collectModelCall(
        modelPath: modelPath,
        contextSize: contextSize,
        systemPrompt: AiPrompts.rewriteChunkSystemPrompt(
          selectedOption,
          prompt,
        ),
        userPrompt:
            '$leading<content_to_write>\n${chunk.text}\n</content_to_write>',
        temperature: temperature,
        maxTokens: max(outputTokens, chunk.tokenCount + 128),
        thinkingModel: thinkingModel,
      );
      output += '${output.isEmpty ? '' : '\n'}$rewritten';
      yield {
        'type': 'output',
        'chunk': rewritten,
        'thinking': '',
        'output': output,
      };
    }
  }

  Future<String> _hierarchicalSummarize({
    required String modelPath,
    required int contextSize,
    required String text,
    required AiTokenBudgetManager manager,
    required double temperature,
    required bool thinkingModel,
    bool force = false,
  }) async {
    var current = text;
    for (var level = 0; level < 5; level++) {
      final count = await manager.countText(current);
      if (count <= contextSize ~/ 3 && (!force || level > 0)) return current;
      final chunks = await manager.chunkText(
        current,
        maximumTokens: max(256, contextSize ~/ 3),
      );
      final summaries = <String>[];
      for (final chunk in chunks) {
        summaries.add(
          await _collectModelCall(
            modelPath: modelPath,
            contextSize: contextSize,
            systemPrompt: AiPrompts.intermediateSummarySystemPrompt(),
            userPrompt: chunk.text,
            temperature: min(temperature, 0.35),
            maxTokens: max(192, contextSize ~/ 10),
            thinkingModel: thinkingModel,
          ),
        );
      }
      final next = summaries.join('\n\n');
      if (await manager.countText(next) >= count) {
        return manager.truncateToTokens(next, contextSize ~/ 3);
      }
      current = next;
    }
    return manager.truncateToTokens(current, contextSize ~/ 3);
  }

  Future<String> _retrieveRelevantText({
    required String modelPath,
    required int contextSize,
    required String query,
    required String text,
    required AiTokenBudgetManager manager,
    required int maximumTokens,
  }) async {
    final chunks = await manager.chunkText(
      text,
      maximumTokens: max(128, min(700, maximumTokens ~/ 2)),
      overlapTokens: 48,
    );
    if (chunks.length <= 1) return text;
    final queryTerms = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((term) => term.length > 1)
        .toSet();
    List<double>? queryVector;
    List<List<double>> vectors = const [];
    try {
      final embedded = await _inferenceService!.embedBatch(
        modelPath: modelPath,
        contextSize: contextSize,
        texts: [query, ...chunks.take(48).map((chunk) => chunk.text)],
      );
      if (embedded.length > 1) {
        queryVector = embedded.first;
        vectors = embedded.skip(1).toList(growable: false);
      }
    } on Object {
      // Lexical retrieval below remains available for models without embeddings.
    }
    final ranked = <({AiTokenChunk chunk, double score})>[];
    for (var index = 0; index < chunks.length; index++) {
      final lower = chunks[index].text.toLowerCase();
      var score = queryTerms.where(lower.contains).length.toDouble();
      if (queryVector != null && index < vectors.length) {
        score += _cosineSimilarity(queryVector, vectors[index]) * 4;
      }
      ranked.add((chunk: chunks[index], score: score));
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    final selected = <AiTokenChunk>[];
    var used = 0;
    for (final entry in ranked) {
      if (used + entry.chunk.tokenCount > maximumTokens &&
          selected.isNotEmpty) {
        continue;
      }
      selected.add(entry.chunk);
      used += entry.chunk.tokenCount;
      if (used >= maximumTokens) break;
    }
    selected.sort((a, b) => a.index.compareTo(b.index));
    return selected
        .map(
          (chunk) =>
              '<relevant_chunk index="${chunk.index + 1}">\n${chunk.text}\n'
              '</relevant_chunk>',
        )
        .join('\n\n');
  }

  Future<List<LlamaConversationTurn>> _fitRollingConversation({
    required String modelPath,
    required int contextSize,
    required String systemPrompt,
    required String userPrompt,
    required List<LlamaConversationTurn> conversation,
    required AiTokenBudgetManager manager,
    required AiTokenBudget budget,
    required double temperature,
    required bool thinkingModel,
  }) async {
    if (conversation.isEmpty) return const [];
    final recent = <LlamaConversationTurn>[];
    var splitAt = conversation.length;
    for (var index = conversation.length - 1; index >= 0; index--) {
      final candidate = [conversation[index], ...recent];
      final tokens = await _inferenceService!.countChatTokens(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        conversation: candidate,
        thinkingModel: thinkingModel,
      );
      if (!budget.accepts(tokens)) break;
      recent
        ..clear()
        ..addAll(candidate);
      splitAt = index;
    }
    if (splitAt == 0) return recent;
    final oldText = conversation
        .take(splitAt)
        .map((turn) => '${turn.isUser ? 'User' : 'Assistant'}: ${turn.text}')
        .join('\n');
    final memory = await _hierarchicalSummarize(
      modelPath: modelPath,
      contextSize: contextSize,
      text: oldText,
      manager: manager,
      temperature: temperature,
      thinkingModel: thinkingModel,
      force: true,
    );
    final summaryHeading = AiPrompts.conversationSummaryHeading();
    var memoryTurn = LlamaConversationTurn(
      isUser: false,
      text: '$summaryHeading\n$memory',
    );
    var result = [memoryTurn, ...recent];
    var tokens = await _inferenceService!.countChatTokens(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      conversation: result,
      thinkingModel: thinkingModel,
    );
    if (!budget.accepts(tokens)) {
      final allowedMemory = max(64, budget.maximumPromptTokens ~/ 5);
      memoryTurn = LlamaConversationTurn(
        isUser: false,
        text:
            '$summaryHeading\n'
            '${await manager.truncateToTokens(memory, allowedMemory)}',
      );
      result = [memoryTurn, ...recent];
      tokens = await _inferenceService.countChatTokens(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        conversation: result,
        thinkingModel: thinkingModel,
      );
      while (!budget.accepts(tokens) && result.length > 1) {
        result.removeAt(1);
        tokens = await _inferenceService.countChatTokens(
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          conversation: result,
          thinkingModel: thinkingModel,
        );
      }
    }
    return result;
  }

  Future<String> _mapReduceContext({
    required String modelPath,
    required int contextSize,
    required String prompt,
    required String text,
    required AiTokenBudgetManager manager,
    required double temperature,
    required bool thinkingModel,
  }) async {
    final chunks = await manager.chunkText(
      text,
      maximumTokens: max(256, contextSize ~/ 3),
      overlapTokens: 24,
    );
    final mapped = <String>[];
    for (final chunk in chunks) {
      mapped.add(
        await _collectModelCall(
          modelPath: modelPath,
          contextSize: contextSize,
          systemPrompt: AiPrompts.mapReduceExtractSystemPrompt(),
          userPrompt: AiPrompts.mapReduceUserPrompt(prompt, chunk.text),
          temperature: min(temperature, 0.35),
          maxTokens: max(192, contextSize ~/ 10),
          thinkingModel: thinkingModel,
        ),
      );
    }
    return _hierarchicalSummarize(
      modelPath: modelPath,
      contextSize: contextSize,
      text: mapped.join('\n\n'),
      manager: manager,
      temperature: temperature,
      thinkingModel: thinkingModel,
    );
  }

  void cancelGeneration() => _inferenceService?.cancel();

  /// Creates an embedding with an installed model for background indexing.
  Future<List<double>> embedText({
    required AiModelInfo model,
    required String text,
  }) async {
    if (_modelDownloader == null || _inferenceService == null) return const [];
    final modelFile = await _modelDownloader.getModelFile(model.id);
    if (!await modelFile.exists()) return const [];
    final vectors = await _inferenceService.embedBatch(
      modelPath: modelFile.path,
      contextSize: model.contextWindow,
      texts: [text],
    );
    return vectors.isEmpty ? const [] : vectors.first;
  }

  Future<void> dispose() async => _inferenceService?.dispose();

  Future<List<ClipboardItem>> _semanticRank({
    required String prompt,
    required List<ClipboardItem> items,
    required String modelPath,
    required int contextSize,
    String modelId = 'gemma-4-e2b',
  }) async {
    if (items.isEmpty || prompt.trim().isEmpty) return items.take(8).toList();
    if (_clipboardRanker.hasExactFileConstraint(prompt)) {
      return items.take(8).toList(growable: false);
    }
    try {
      List<double>? queryVector;
      if (_inferenceService != null) {
        final vectors = await _inferenceService.embedBatch(
          modelPath: modelPath,
          contextSize: contextSize,
          texts: [prompt],
        );
        if (vectors.isNotEmpty) {
          queryVector = vectors.first;
        }
      }

      final results = await _hybridSearch.search(
        query: prompt,
        allCandidates: items,
        queryVector: queryVector,
        modelId: modelId,
        maxFinalItems: 8,
      );

      return results.isNotEmpty ? results : items.take(8).toList();
    } catch (_) {
      return _clipboardRanker
          .rank(prompt: prompt, items: items)
          .take(8)
          .toList();
    }
  }

  double _cosineSimilarity(List<double> left, List<double> right) {
    if (left.length != right.length || left.isEmpty) return 0;
    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;
    for (var index = 0; index < left.length; index++) {
      dot += left[index] * right[index];
      leftNorm += left[index] * left[index];
      rightNorm += right[index] * right[index];
    }
    if (leftNorm == 0 || rightNorm == 0) return 0;
    return dot / (sqrt(leftNorm) * sqrt(rightNorm));
  }

  String _buildSystemPrompt(
    AiFeatureGroup? featureGroup,
    String? selectedOption,
    String conversationContext,
    AiRequestIntent intent,
    String responseLanguage,
  ) {
    return AiPrompts.buildSystemPrompt(
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      intent: intent,
      responseLanguage: responseLanguage,
    );
  }

  List<String> _generateThinkingProcess({
    required AiFeatureGroup? featureGroup,
    required String? selectedOption,
    required String prompt,
    required String contextText,
    required int historyItemCount,
    String? systemPrompt,
    bool hasConversationContext = false,
  }) {
    final isEn = AppTranslations.currentLanguage == 'en';
    if (featureGroup == null) {
      return isEn
          ? [
              'Analyzing user request...\n',
              if (hasConversationContext)
                'Cross-referencing recent conversation history...\n',
              historyItemCount > 0
                  ? 'Searching through $historyItemCount clipboard items...\n'
                  : 'Checking current clipboard context...\n',
              'Extracting entities and primary question requirements...\n',
              'Determining optimal response structure.',
            ]
          : [
              'Phân tích yêu cầu của người dùng...\n',
              if (hasConversationContext)
                'Đang đối chiếu với các lượt hỏi đáp gần nhất...\n',
              historyItemCount > 0
                  ? 'Đang tìm kiếm trong $historyItemCount mục clipboard...\n'
                  : 'Đang kiểm tra ngữ cảnh clipboard hiện tại...\n',
              'Trích xuất thực thể và yêu cầu câu hỏi chính...\n',
              'Xác định cấu trúc phản hồi phù hợp và chính xác nhất.',
            ];
    }

    return switch (featureGroup) {
      AiFeatureGroup.rewrite =>
        isEn
            ? [
                'Reading original text (${contextText.length} chars)...\n',
                'Analyzing target style: "$selectedOption"...\n',
                'Balancing vocabulary, tone, and rhythm...\n',
                'Preserving 100% of original core meaning.',
              ]
            : [
                'Đang đọc nội dung gốc (${contextText.length} ký tự)...\n',
                'Phân tích phong cách mong muốn: "$selectedOption"...\n',
                'Cân bằng lại từ vựng, tông giọng và nhịp điệu câu văn...\n',
                'Đảm bảo giữ nguyên 100% ý nghĩa cốt lõi ban đầu.',
              ],
      AiFeatureGroup.grammar =>
        isEn
            ? [
                'Checking spelling & grammar in context...\n',
                'Detecting awkward phrasing and punctuation...\n',
                'Optimizing redundant or unclear phrasing...',
              ]
            : [
                'Kiểm tra chính tả tiếng Việt / tiếng Anh trong ngữ cảnh...\n',
                'Phát hiện cấu trúc ngữ pháp và dấu câu chưa chuẩn...\n',
                'Tối ưu hóa các cụm từ bị lặp hoặc thiếu tự nhiên...',
              ],
      AiFeatureGroup.summary =>
        isEn
            ? [
                'Analyzing key paragraphs and important data...\n',
                'Filtering secondary details, extracting key entities (Names, Dates, Links)...\n',
                'Structuring into a concise summary...',
              ]
            : [
                'Phân tích các đoạn văn chính và dữ liệu quan trọng...\n',
                'Lọc bỏ các thông tin phụ, trích xuất thực thể chính (Tên, Ngày, Link)...\n',
                'Cấu trúc lại thành dàn ý tóm tắt ngắn gọn và dễ theo dõi...',
              ],
      AiFeatureGroup.translate =>
        isEn
            ? [
                'Auto-detecting input language...\n',
                'Preserving formatting, URLs, and proper names...\n',
                'Translating accurately in natural phrasing...',
              ]
            : [
                'Nhận diện ngôn ngữ đầu vào tự động...\n',
                'Giữ nguyên định dạng mã nguồn, đường dẫn URL và tên riêng...\n',
                'Dịch thuật chuẩn xác theo văn phong tự nhiên...',
              ],
      AiFeatureGroup.smartReply =>
        isEn
            ? [
                'Analyzing incoming message / email content...\n',
                'Determining response goal: "$selectedOption"...\n',
                'Drafting polite, ready-to-send reply...',
              ]
            : [
                'Phân tích nội dung tin nhắn / email vừa nhận được...\n',
                'Xác định hướng phản hồi: "$selectedOption"...\n',
                'Tạo câu trả lời đúng chuẩn lịch sự và sẵn sàng để gửi...',
              ],
      AiFeatureGroup.generate =>
        isEn
            ? [
                'Gathering requirements and keywords...\n',
                'Structuring new content layout ($selectedOption)...\n',
                'Completing professional draft...',
              ]
            : [
                'Thu thập các yêu cầu và từ khóa trong văn bản...\n',
                'Xây dựng bố cục nội dung mới phù hợp ($selectedOption)...\n',
                'Hoàn thiện đoạn văn phong phú, chuyên nghiệp...',
              ],
      AiFeatureGroup.qa =>
        isEn
            ? [
                'Reading attached clipboard content...\n',
                'Searching for best match to question: "$prompt"...\n',
                'Synthesizing direct, clear answer...',
              ]
            : [
                'Đang đọc tài liệu / clipboard được đính kèm...\n',
                'Tìm kiếm thông tin khớp nhất với câu hỏi: "$prompt"...\n',
                'Tổng hợp câu trả lời ngắn gọn, trực tiếp và dễ hiểu...',
              ],
      AiFeatureGroup.codeExplain =>
        isEn
            ? [
                'Analyzing source code syntax & error logs...\n',
                'Identifying root cause of error...\n',
                'Preparing fix recommendations with code example...',
              ]
            : [
                'Phân tích cấu trúc cú pháp mã nguồn & log lỗi...\n',
                'Xác định nguyên nhân rễ cây (root cause) của lỗi...\n',
                'Chuẩn bị giải pháp sửa lỗi kèm ví dụ code cụ thể...',
              ],
      AiFeatureGroup.extractInfo =>
        isEn
            ? [
                'Scanning text for Email, Phone, Dates, Values...\n',
                'Formatting data into target structure ($selectedOption)...',
              ]
            : [
                'Quét dữ liệu không cấu trúc để tìm Email, SĐT, Ngày, Giá trị...\n',
                'Định dạng dữ liệu thành cấu trúc chuẩn ($selectedOption)...',
              ],
      AiFeatureGroup.titlesTags =>
        isEn
            ? [
                'Analyzing primary clipboard topic...\n',
                'Generating concise titles and relevant search tags...',
              ]
            : [
                'Phân tích chủ đề chính của clipboard...\n',
                'Tạo tiêu đề ngắn gọn súc tích và bộ thẻ từ khóa liên quan...',
              ],
      AiFeatureGroup.classify =>
        isEn
            ? ['Evaluating category (Work, Personal, Code, Error...)...']
            : ['Đánh giá danh mục phù hợp (Work, Personal, Code, Error...)...'],
      AiFeatureGroup.ocrRefine =>
        isEn
            ? [
                'Reviewing OCR image recognition errors...\n',
                'Cleaning up artifact characters and reformatting text...',
              ]
            : [
                'Soát lỗi OCR từ nhận dạng hình ảnh...\n',
                'Làm sạch ký tự lạ và định dạng lại văn bản chuẩn...',
              ],
    };
  }

  List<String> _generateOutputResult({
    required AiFeatureGroup? featureGroup,
    required String? selectedOption,
    required String prompt,
    required String contextText,
    required List<ClipboardItem> clipboardHistory,
    required AiModelInfo model,
    String conversationContext = '',
  }) {
    final textToProcess = contextText.isNotEmpty
        ? contextText
        : conversationContext.isNotEmpty
        ? conversationContext
        : prompt;
    if (textToProcess.isEmpty) {
      return [
        'Vui lòng sao chép nội dung vào clipboard hoặc nhập câu hỏi để AI xử lý.',
      ];
    }

    if (featureGroup == null) {
      if (clipboardHistory.isNotEmpty) {
        return _answerFromClipboardHistory(
          prompt: prompt,
          items: clipboardHistory,
          model: model,
        );
      }
      if (prompt.contains('lỗi') ||
          prompt.contains('code') ||
          prompt.contains('bug')) {
        return [
          'Dựa trên phân tích local AI:\n\n',
          '1. **Nguyên nhân**: Đoạn mã / log lỗi cho thấy sự bất đồng bộ hoặc tham chiếu đối tượng chưa khởi tạo.\n',
          '2. **Giải pháp đề xuất**: Kiểm tra tính tồn tại của đối tượng trước khi truy cập phương thức.\n\n',
          '```dart\nif (object != null) {\n  object.process();\n}\n```',
        ];
      }
      return [
        'Dưới đây là kết quả xử lý từ model local **${model.name}**:\n\n',
        'ClipFlow AI đã phân tích nội dung clipboard của bạn. Nội dung bao gồm `${textToProcess.length}` ký tự.\n\n',
        'Nội dung chính đã được tối ưu hóa cho công việc và lưu giữ 100% riêng tư trên thiết bị.',
      ];
    }

    switch (featureGroup) {
      case AiFeatureGroup.rewrite:
        final style = selectedOption ?? 'Tự nhiên hơn';
        return [
          '✨ **Nội dung đã được viết lại ($style):**\n\n',
          _rewriteText(textToProcess, style),
        ];

      case AiFeatureGroup.grammar:
        return [
          '✅ **Đã sửa chính tả & ngữ pháp:**\n\n',
          _fixGrammarText(textToProcess),
          '\n\n*Lưu ý: Ý nghĩa ban đầu của văn bản được giữ nguyên 100%.*',
        ];

      case AiFeatureGroup.summary:
        return [
          '📌 **Tóm tắt nội dung clipboard:**\n\n',
          '• **Ý chính 1**: ${_firstLine(textToProcess)}\n',
          '• **Thông tin quan trọng**: Đã xử lý ${textToProcess.length} ký tự từ clipboard.\n',
          '• **Hành động đề xuất**: Kiểm tra lại thông tin và sử dụng nút Sao chép để dán vào công việc.',
        ];

      case AiFeatureGroup.translate:
        final target = selectedOption?.contains('Anh') == true
            ? 'Tiếng Anh'
            : 'Tiếng Việt';
        return [
          '🌐 **Bản dịch ($target):**\n\n',
          target == 'Tiếng Anh'
              ? 'Here is the translated content based on your clipboard input, preserving links and formatting.'
              : 'Dưới đây là nội dung đã được dịch sang tiếng Việt, giữ nguyên định dạng, đường dẫn và từ khóa chuyên môn.',
        ];

      case AiFeatureGroup.smartReply:
        final option = selectedOption ?? 'Đồng ý';
        return [
          '💬 **Gợi ý câu trả lời ($option):**\n\n',
          _generateReplyText(option),
        ];

      case AiFeatureGroup.generate:
        return [
          '📝 **Nội dung được tạo mới ($selectedOption):**\n\n',
          'Chào bạn,\n\nTôi xin gửi thông tin cập nhật liên quan đến nội dung vừa sao chép. Xin vui lòng xem xét và phản hồi nếu có câu hỏi thêm.\n\nTrân trọng,',
        ];

      case AiFeatureGroup.qa:
        return [
          '💡 **Trả lời cho câu hỏi:** "$prompt"\n\n',
          'Dựa trên nội dung clipboard hiện tại, đây là thông tin quan trọng nhất:\n',
          '- Nội dung xoay quanh: ${_firstLine(textToProcess)}\n',
          '- Điểm cần lưu ý: Đã được xác minh và xử lý trực tiếp trên thiết bị của bạn.',
        ];

      case AiFeatureGroup.codeExplain:
        return [
          '💻 **Giải thích mã nguồn & Phân tích lỗi:**\n\n',
          '• **Mô tả**: Đoạn mã xử lý luồng dữ liệu và đồng bộ hóa.\n',
          '• **Điểm quan trọng**: Cần đảm bảo giải phóng bộ nhớ (dispose) khi không sử dụng.\n',
          '• **Gợi ý tối ưu**:\n',
          '```dart\n// Refactored with safe null check\nfinal cleanText = input?.trim() ?? "";\n```',
        ];

      case AiFeatureGroup.extractInfo:
        if (selectedOption?.contains('JSON') == true) {
          return [
            '```json\n{\n  "extracted_at": "${DateTime.now().toIso8601String()}",\n  "text_length": ${textToProcess.length},\n  "snippet": "${_firstLine(textToProcess)}"\n}\n```',
          ];
        }
        return [
          '📊 **Trích xuất thông tin dưới dạng bảng:**\n\n',
          '| Trường | Giá trị |\n',
          '| :--- | :--- |\n',
          '| Độ dài | ${textToProcess.length} ký tự |\n',
          '| Xem trước | ${_firstLine(textToProcess)} |\n',
          '| Trạng thái | Hoàn tất offline |\n',
        ];

      case AiFeatureGroup.titlesTags:
        return [
          '🏷️ **Tiêu đề & Từ khóa đề xuất:**\n\n',
          '• **Tiêu đề**: ${_firstLine(textToProcess)}\n',
          '• **Từ khóa**: `#clipboard`, `#local_ai`, `#clipflow`, `#privacy`',
        ];

      case AiFeatureGroup.classify:
        return [
          '📁 **Phân loại thông minh:**\n\n',
          '• **Nhóm chính**: `Công việc` / `Tài liệu`\n',
          '• **Độ ưu tiên**: Bình thường\n',
          '• **Thẻ đề xuất**: #Work, #Notes',
        ];

      case AiFeatureGroup.ocrRefine:
        return [
          '🔍 **Văn bản OCR sau khi làm sạch:**\n\n',
          textToProcess.replaceAll(RegExp(r'\s+'), ' '),
        ];
    }
  }

  String _buildHistoryContext(List<ClipboardItem> items) {
    const maximumCharacters = 16000;
    final buffer = StringBuffer();
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      var content = item.content.trim();
      if (item.contentType == ClipboardContentType.image) {
        final fileName =
            item.imagePath?.split(Platform.pathSeparator).last ?? 'image.png';
        if (content.isEmpty || content == '[Image]') {
          content = '(Hình ảnh: $fileName)';
        } else {
          content = '(Hình ảnh: $fileName, OCR: "$content")';
        }
      }
      if (content.isEmpty) continue;
      final entry =
          '[clip:${item.id}] (${item.contentType.name}) '
          '${item.sourceAppName ?? 'Unknown'}: $content\n';
      if (buffer.length + entry.length > maximumCharacters) break;
      buffer.write(entry);
    }
    return buffer.toString().trim();
  }

  List<String> _answerFromClipboardHistory({
    required String prompt,
    required List<ClipboardItem> items,
    required AiModelInfo model,
  }) {
    final rankedItems = _clipboardRanker.rank(prompt: prompt, items: items);
    final matches = rankedItems.take(12).toList(growable: false);

    final isEn = AppTranslations.currentLanguage == 'en';
    if (matches.isEmpty) {
      return [
        isEn
            ? 'No matching content found in **${items.length} clipboard items**. '
                  'Try different keywords or select a clip directly for analysis.'
            : 'Không tìm thấy nội dung phù hợp trong **${items.length} mục clipboard**. '
                  'Hãy thử từ khóa khác hoặc chọn trực tiếp một clip để phân tích.',
      ];
    }

    final output = StringBuffer(
      isEn
          ? 'Searched **${items.length} clipboard items** using local model '
                '**${model.name}** and found **${rankedItems.length} matching results**:\n\n'
          : 'Đã tìm trong **${items.length} mục clipboard** bằng model local '
                '**${model.name}** và thấy **${rankedItems.length} kết quả phù hợp**:\n\n',
    );
    for (var index = 0; index < matches.length; index++) {
      final item = matches[index];
      var preview = item.content.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (preview.length > 240) preview = '${preview.substring(0, 240)}…';

      final isImgUrl =
          item.contentType == ClipboardContentType.url &&
          _clipboardRanker.isImageUrl(item.content);
      final badgeLabel = isImgUrl
          ? (isEn ? 'IMAGE LINK' : 'LINK ÁNH')
          : item.contentType.name.toUpperCase();

      final unknownSource = isEn ? 'Unknown source' : 'Không rõ nguồn';
      output.writeln(
        '${index + 1}. **$badgeLabel** — ${item.sourceAppName ?? unknownSource}\n   $preview',
      );
    }
    if (rankedItems.length > matches.length) {
      output.write(
        isEn
            ? '\n_Showing top ${matches.length}/${rankedItems.length} results._'
            : '\n_Đang hiển thị ${matches.length}/${rankedItems.length} kết quả tốt nhất._',
      );
    }
    return [output.toString()];
  }

  // double _characterSimilarity(String query, String text) {
  //   Set<String> grams(String value) {
  //     final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  //     if (normalized.length < 3) return {normalized};
  //     return {
  //       for (var i = 0; i <= normalized.length - 3; i++)
  //         normalized.substring(i, i + 3),
  //     };
  //   }

  //   final left = grams(query);
  //   final right = grams(text.length > 500 ? text.substring(0, 500) : text);
  //   if (left.isEmpty || right.isEmpty) return 0;
  //   return left.intersection(right).length / left.length;
  // }

  // static const _searchStopWords = {
  //   'tìm',
  //   'kiem',
  //   'kiếm',
  //   'trong',
  //   'clipboard',
  //   'clipbroad',
  //   'clip',
  //   'cho',
  //   'của',
  //   'mình',
  //   'hãy',
  //   'find',
  //   'search',
  //   'the',
  //   'for',
  //   'from',
  // };

  String _firstLine(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'Clipboard text';
    final line = lines.first.trim();
    return line.length > 60 ? '${line.substring(0, 60)}...' : line;
  }

  String _rewriteText(String input, String style) {
    final trimmed = input.trim();
    if (style.contains('Chuyên nghiệp')) {
      return 'Kính gửi quý đối tác, $trimmed. Rất mong nhận được sự hợp tác và trao đổi tiếp theo từ phía quý vị.';
    } else if (style.contains('Ngắn gọn')) {
      return _firstLine(trimmed);
    } else if (style.contains('Lịch sự')) {
      return 'Xin chào, $trimmed. Cảm ơn bạn rất nhiều!';
    }
    return trimmed;
  }

  String _fixGrammarText(String input) {
    return input
        .replaceAll('  ', ' ')
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.');
  }

  String _generateReplyText(String option) {
    if (option.contains('Từ chối')) {
      return 'Cảm ơn bạn đã chia sẻ thông tin. Tuy nhiên, hiện tại tôi chưa thể tham gia công việc này. Rất mong có cơ hội hợp tác trong tương lai!';
    } else if (option.contains('Đồng ý')) {
      return 'Cảm ơn bạn! Tôi hoàn toàn nhất trí với phương án này. Chúng ta hãy bắt đầu triển khai nhé!';
    } else if (option.contains('Yêu cầu')) {
      return 'Cảm ơn bạn đã gửi thông tin. Bạn có thể gửi thêm cho tôi chi tiết cụ thể hơn để tôi nắm rõ hơn không?';
    }
    return 'Cảm ơn bạn! Tôi đã nhận được thông tin và sẽ phản hồi sớm.';
  }

  Future<String?> _generatePlannerJson({
    required AiModelInfo model,
    required String prompt,
    required String responseLanguage,
    int contextSize = 2048,
    String? debugRequestId,
  }) async {
    if (_modelDownloader == null || _inferenceService == null) return null;

    try {
      final modelFile = await _modelDownloader.getModelFile(model.id);
      final fileExists = await modelFile.exists();
      if (!fileExists) return null;

      final systemPrompt = AiPrompts.plannerSystemPrompt(
        responseLanguage: responseLanguage,
      );

      _debug?.log(
        level: AiDebugLevel.info,
        stage: 'planner-llm',
        requestId: debugRequestId,
        message: 'Kích hoạt LLM Planner sinh JSON plan',
        details: 'systemPrompt:\n$systemPrompt\n\nuserPrompt:\n$prompt',
      );

      final buffer = StringBuffer();
      await for (final token in _inferenceService.generate(
        modelPath: modelFile.path,
        contextSize: contextSize,
        systemPrompt: systemPrompt,
        userPrompt: prompt,
        temperature: 0.0,
        maxTokens: 512,
        thinkingModel: false,
        grammar: StructuredOutputValidator.executionPlanGrammar,
      )) {
        if (token.content != null) {
          buffer.write(token.content);
        }
      }

      final rawOutput = buffer.toString();
      _debug?.log(
        level: AiDebugLevel.info,
        stage: 'planner-llm',
        requestId: debugRequestId,
        message: 'LLM Planner kết thúc sinh plan JSON',
        details: rawOutput,
      );

      return _outputValidator.extractJson(rawOutput);
    } catch (e, st) {
      _debug?.log(
        level: AiDebugLevel.error,
        stage: 'planner-llm',
        requestId: debugRequestId,
        message: 'Lỗi khi sinh JSON plan từ LLM Planner: $e',
        details: '$st',
      );
      return null;
    }
  }
}
