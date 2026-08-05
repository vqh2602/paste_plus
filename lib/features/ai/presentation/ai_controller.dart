import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/providers.dart';
import '../../../core/services/ai_debug_service.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../data/ai_conversation_repository.dart';
import '../domain/ai_chat_message.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_feature_request.dart';
import '../domain/ai_model_info.dart';
import '../domain/ai_performance_mode.dart';
import '../domain/ai_request_plan.dart';
import '../domain/ai_request_classification.dart';
import '../localization/ai_language_context.dart';
import '../localization/ai_language_detector.dart';
import '../localization/ai_response_locale_resolver.dart';
import '../services/ai_model_downloader_service.dart';
import '../services/ai_utility_classifier.dart';
import '../services/local_ai_engine.dart';

class PendingToolCall {
  const PendingToolCall({
    required this.toolName,
    required this.arguments,
    required this.completer,
  });

  final String toolName;
  final Map<String, dynamic> arguments;
  final Completer<bool> completer;
}

class AiState {
  const AiState({
    required this.selectedModelId,
    this.downloadStates = const {},
    this.downloadProgresses = const {},
    this.chatMessages = const [],
    this.activeClipboardContext,
    this.isGenerating = false,
    this.savedConversations = const [],
    this.temperature = 0.55,
    this.contextSize = 4096,
    this.performanceMode = AiPerformanceMode.balanced,
    this.pendingToolCall,
  });

  final String selectedModelId;
  final Map<String, DownloadState> downloadStates;
  final Map<String, ModelDownloadProgress> downloadProgresses;
  final List<AiChatMessage> chatMessages;
  final ClipboardItem? activeClipboardContext;
  final bool isGenerating;
  final List<SavedAiConversation> savedConversations;
  final double temperature;
  final int contextSize;
  final AiPerformanceMode performanceMode;
  final PendingToolCall? pendingToolCall;

  AiModelInfo get selectedModel => AiModelInfo.findById(selectedModelId);

  /// True if at least one model has been fully downloaded.
  bool get hasAnyDownloadedModel =>
      downloadStates.values.any((s) => s == DownloadState.downloaded);

  /// True when the dedicated classifier model (Qwen 0.6B) is not fully downloaded.
  bool get isClassifierModelMissing {
    const classifierId = AiUtilityClassifier.utilityModelId;
    return downloadStates[classifierId] != DownloadState.downloaded;
  }

  AiState copyWith({
    String? selectedModelId,
    Map<String, DownloadState>? downloadStates,
    Map<String, ModelDownloadProgress>? downloadProgresses,
    List<AiChatMessage>? chatMessages,
    ClipboardItem? activeClipboardContext,
    bool clearClipboardContext = false,
    bool? isGenerating,
    List<SavedAiConversation>? savedConversations,
    double? temperature,
    int? contextSize,
    AiPerformanceMode? performanceMode,
    PendingToolCall? pendingToolCall,
    bool clearPendingToolCall = false,
  }) {
    return AiState(
      selectedModelId: selectedModelId ?? this.selectedModelId,
      downloadStates: downloadStates ?? this.downloadStates,
      downloadProgresses: downloadProgresses ?? this.downloadProgresses,
      chatMessages: chatMessages ?? this.chatMessages,
      activeClipboardContext: clearClipboardContext
          ? null
          : (activeClipboardContext ?? this.activeClipboardContext),
      isGenerating: isGenerating ?? this.isGenerating,
      savedConversations: savedConversations ?? this.savedConversations,
      temperature: temperature ?? this.temperature,
      contextSize: contextSize ?? this.contextSize,
      performanceMode: performanceMode ?? this.performanceMode,
      pendingToolCall: clearPendingToolCall
          ? null
          : (pendingToolCall ?? this.pendingToolCall),
    );
  }
}

class AiController extends StateNotifier<AiState> {
  AiController(
    this._downloaderService,
    this._localEngine,
    this._conversationRepository,
    this._utilityClassifier,
    this._ref,
  ) : super(
        AiState(
          selectedModelId: _ref
              .read(settingsControllerProvider)
              .selectedAiModel,
        ),
      ) {
    _restoreFuture = _restoreConversation();
    _checkDownloadedModels();
  }

  final AiModelDownloaderService _downloaderService;
  final LocalAiEngine _localEngine;
  final AiConversationRepository _conversationRepository;
  final AiUtilityClassifier _utilityClassifier;
  final Ref _ref;
  late final Future<void> _restoreFuture;
  bool _restoreCompleted = false;
  bool _chatChangedBeforeRestore = false;
  bool _contextChangedBeforeRestore = false;
  final Map<String, StreamSubscription> _downloadSubscriptions = {};

  Future<void> _checkDownloadedModels() async {
    final newStates = Map<String, DownloadState>.from(state.downloadStates);
    for (final model in AiModelInfo.thinkingModels) {
      final downloaded = await _downloaderService.isModelDownloaded(model.id);
      if (downloaded) {
        newStates[model.id] = DownloadState.downloaded;
      } else {
        // Check if a partial download (.part file) exists
        final hasPartial = await _downloaderService.hasPartialDownload(
          model.id,
        );
        newStates[model.id] = hasPartial
            ? DownloadState.paused
            : DownloadState.notDownloaded;
      }
    }
    state = state.copyWith(downloadStates: newStates);
  }

  void selectModel(String modelId) {
    state = state.copyWith(selectedModelId: modelId);
    _ref
        .read(settingsControllerProvider.notifier)
        .update((current) => current.copyWith(selectedAiModel: modelId));
  }

  void startDownload(AiModelInfo model) {
    if (_downloadSubscriptions.containsKey(model.id)) return;

    final newStates = Map<String, DownloadState>.from(state.downloadStates);
    newStates[model.id] = DownloadState.downloading;
    state = state.copyWith(downloadStates: newStates);

    final stream = _downloaderService.downloadModel(model);
    final sub = stream.listen(
      (progress) {
        final progs = Map<String, ModelDownloadProgress>.from(
          state.downloadProgresses,
        );
        progs[model.id] = progress;

        final states = Map<String, DownloadState>.from(state.downloadStates);
        states[model.id] = progress.state;

        state = state.copyWith(
          downloadStates: states,
          downloadProgresses: progs,
        );
      },
      onDone: () {
        _downloadSubscriptions.remove(model.id);
      },
      onError: (Object err) {
        _downloadSubscriptions.remove(model.id);
      },
    );

    _downloadSubscriptions[model.id] = sub;
  }

  void cancelDownload(String modelId) {
    _downloadSubscriptions[modelId]?.cancel();
    _downloadSubscriptions.remove(modelId);
    _downloaderService.cancelDownload(modelId);

    final states = Map<String, DownloadState>.from(state.downloadStates);
    states[modelId] = DownloadState.notDownloaded;
    state = state.copyWith(downloadStates: states);
  }

  /// Resume a paused download (semantic alias for startDownload).
  void resumeDownload(AiModelInfo model) {
    startDownload(model);
  }

  Future<void> deleteModel(String modelId) async {
    cancelDownload(modelId);
    await _downloaderService.deleteModel(modelId);

    final states = Map<String, DownloadState>.from(state.downloadStates);
    states[modelId] = DownloadState.notDownloaded;
    state = state.copyWith(downloadStates: states);
  }

  /// Downloads the classifier model (Qwen 0.6B) using the unified model downloader.
  void downloadClassifierModel() {
    final classifierModel = AiModelInfo.findById(
      AiUtilityClassifier.utilityModelId,
    );
    startDownload(classifierModel);
  }

  void setClipboardContext(ClipboardItem? item) {
    if (!_restoreCompleted) _contextChangedBeforeRestore = true;
    state = state.copyWith(
      activeClipboardContext: item,
      clearClipboardContext: item == null,
    );
    unawaited(_saveAfterRestore());
  }

  void setPerformanceMode(AiPerformanceMode mode) {
    state = state.copyWith(performanceMode: mode);
  }

  void clearChat() {
    if (!_restoreCompleted) _chatChangedBeforeRestore = true;
    state = state.copyWith(chatMessages: []);
    unawaited(_saveAfterRestore());
  }

  Future<void> startNewConversation() async {
    if (state.isGenerating) stopGeneration();
    await _conversationRepository.archive(
      messages: state.chatMessages,
      clipboardContext: state.activeClipboardContext,
    );
    state = state.copyWith(chatMessages: []);
    await _saveConversation();
    await _refreshSessions();
  }

  Future<void> openConversation(SavedAiConversation conversation) async {
    if (state.chatMessages.isNotEmpty) {
      await _conversationRepository.archive(
        messages: state.chatMessages,
        clipboardContext: state.activeClipboardContext,
      );
    }
    state = state.copyWith(
      chatMessages: conversation.messages,
      activeClipboardContext: conversation.clipboardContext,
      clearClipboardContext: conversation.clipboardContext == null,
    );
    await _saveConversation();
    await _refreshSessions();
  }

  Future<void> deleteConversation(String id) async {
    await _conversationRepository.deleteSession(id);
    await _refreshSessions();
  }

  Future<void> renameConversation(String id, String title) async {
    if (title.trim().isEmpty) return;
    await _conversationRepository.renameSession(id, title.trim());
    await _refreshSessions();
  }

  Future<void> toggleConversationPinned(String id) async {
    await _conversationRepository.togglePinned(id);
    await _refreshSessions();
  }

  void stopGeneration() {
    _ref
        .read(aiDebugControllerProvider.notifier)
        .log(
          level: AiDebugLevel.warning,
          stage: 'generation',
          message: 'Người dùng yêu cầu dừng quá trình sinh',
        );
    _localEngine.cancelGeneration();
  }

  void setGenerationProfile({
    required double temperature,
    required int contextSize,
  }) {
    state = state.copyWith(
      temperature: temperature.clamp(0.0, 2.0),
      contextSize: contextSize.clamp(2048, state.selectedModel.contextWindow),
    );
  }

  Future<void> regenerateLastResponse() async {
    if (state.isGenerating) return;
    final userIndex = state.chatMessages.lastIndexWhere(
      (message) => message.role == AiMessageRole.user,
    );
    if (userIndex < 0) return;
    final message = state.chatMessages[userIndex];
    state = state.copyWith(
      chatMessages: state.chatMessages.sublist(0, userIndex),
    );
    await sendUserMessage(
      message.content,
      featureGroup: message.featureGroup,
      selectedOption: message.selectedOption,
      contextItem: message.clipboardContext,
    );
  }

  Future<void> continueLastResponse() {
    return sendUserMessage(
      'Tiếp tục câu trả lời trước, không lặp lại phần đã trình bày.',
    );
  }

  Future<bool> requestToolConfirmation(
    String toolName,
    Map<String, dynamic> arguments,
  ) {
    final completer = Completer<bool>();
    state = state.copyWith(
      pendingToolCall: PendingToolCall(
        toolName: toolName,
        arguments: arguments,
        completer: completer,
      ),
    );
    return completer.future.whenComplete(() {
      if (state.pendingToolCall?.completer == completer) {
        state = state.copyWith(clearPendingToolCall: true);
      }
    });
  }

  void approvePendingToolCall() {
    final pending = state.pendingToolCall;
    pending?.completer.complete(true);
    Future.microtask(() async {
      await _ref.read(historyControllerProvider.notifier).reload();
      await _ref.read(collectionsControllerProvider.notifier).reload();
    });
  }

  void rejectPendingToolCall() {
    state.pendingToolCall?.completer.complete(false);
  }

  Future<void> sendUserMessage(
    String userText, {
    AiFeatureGroup? featureGroup,
    AiFeatureRequest? featureRequest,
    String? selectedOption,
    ClipboardItem? contextItem,
  }) async {
    if (state.isGenerating) return;
    await _restoreFuture;

    final debug = _ref.read(aiDebugControllerProvider.notifier);
    final requestId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final stopwatch = Stopwatch()..start();

    final selectedContext = contextItem ?? state.activeClipboardContext;
    final availableConversationContext = _buildConversationContext(
      state.chatMessages,
    );
    final conversationContext = availableConversationContext;
    final conversationMessages = _recentConversationMessages(
      state.chatMessages,
    );
    var activeContext = selectedContext;

    final userMsg = AiChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      role: AiMessageRole.user,
      content: userText,
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      clipboardContext: activeContext,
    );

    final assistantMsgId = '${DateTime.now().microsecondsSinceEpoch}_ai';
    final assistantMsg = AiChatMessage(
      id: assistantMsgId,
      role: AiMessageRole.assistant,
      content: '',
      isThinking: true,
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      clipboardContext: activeContext,
    );

    final updatedMessages = [...state.chatMessages, userMsg, assistantMsg];
    state = state.copyWith(chatMessages: updatedMessages, isGenerating: true);

    final targetContext = activeContext;
    if (targetContext != null &&
        targetContext.contentType == ClipboardContentType.image) {
      final ocrTextInContent = targetContext.content.trim();
      final hasOcrText =
          ocrTextInContent.isNotEmpty && ocrTextInContent != '[Image]';
      String? extractedText;
      if (!hasOcrText && targetContext.imagePath != null) {
        try {
          final historyNotifier = _ref.read(historyControllerProvider.notifier);
          final extracted = await historyNotifier.performOcr(targetContext);
          if (extracted != null && extracted.trim().isNotEmpty) {
            extractedText = extracted.trim();
          }
        } catch (_) {
          // Ignore OCR errors gracefully
        }
      } else if (hasOcrText) {
        extractedText = ocrTextInContent;
      }

      final fileName =
          targetContext.imagePath?.split(Platform.pathSeparator).last ??
          'image.png';
      final sourceApp = targetContext.sourceAppName ?? 'Unknown App';
      final imageInfoBuffer = StringBuffer()
        ..writeln(
          '(Tệp hình ảnh được chọn làm ngữ cảnh: "$fileName", Ứng dụng nguồn: "$sourceApp")',
        );

      if (extractedText != null && extractedText.isNotEmpty) {
        imageInfoBuffer.writeln(
          '\nVăn bản nhận diện được từ OCR trong hình ảnh:\n"$extractedText"',
        );
      } else {
        imageInfoBuffer.writeln(
          '\n[Lưu ý: Hình ảnh này không chứa văn bản (OCR không tìm thấy chữ). Đây là một hình ảnh đồ họa/ảnh chụp/minh họa.]',
        );
      }

      activeContext = targetContext.copyWith(
        content: imageInfoBuffer.toString(),
        normalizedContent: imageInfoBuffer.toString(),
      );

      final currentMsgs = [...state.chatMessages];
      final userIdx = currentMsgs.indexWhere((m) => m.id == userMsg.id);
      if (userIdx != -1) {
        currentMsgs[userIdx] = currentMsgs[userIdx].copyWith(
          clipboardContext: activeContext,
        );
      }
      final aiIdx = currentMsgs.indexWhere((m) => m.id == assistantMsgId);
      if (aiIdx != -1) {
        currentMsgs[aiIdx] = currentMsgs[aiIdx].copyWith(
          clipboardContext: activeContext,
        );
      }
      state = state.copyWith(chatMessages: currentMsgs);
    }
    final clipboardHistory = _ref
        .read(historyControllerProvider)
        .items
        .where((item) => !item.isSensitive)
        .toList(growable: false);
    final settings = _ref.read(settingsControllerProvider);
    final appLanguageTag = settings.language;
    final requestModel = _modelForRequest();
    final fallback = fallbackClassification(
      prompt: userText,
      appLanguageTag: detectLanguageByScript(userText) ?? appLanguageTag,
      featureGroup: featureGroup,
      hasSelectedClipboard: activeContext != null,
    );
    final classification = canSkipUtilityClassifier(
      prompt: userText,
      featureGroup: featureGroup,
    )
        ? fallback
        : await _utilityClassifier.classify(
            prompt: userText,
            appLanguageTag: appLanguageTag,
            fallbackModel: requestModel,
            hasSelectedClipboard: activeContext != null,
          );
    final translationTargetTag = switch (featureRequest) {
      AiTranslateRequest(:final targetLocaleTag) => targetLocaleTag,
      _ when featureGroup == AiFeatureGroup.translate => selectedOption,
      _ => null,
    };
    final languageContext = AiLanguageContext(
      appLocale: Locale(settings.language),
      responseMode: AiResponseLanguageMode.matchUser,
      detectedInputTag: classification.languageTag,
      translationTargetTag: translationTargetTag,
    );
    final responseLanguageTag = const AiResponseLocaleResolver().resolve(
      languageContext,
    );
    debug.log(
      level: AiDebugLevel.info,
      stage: 'request',
      requestId: requestId,
      message: 'Nhận yêu cầu AI',
      details:
          'prompt:\n$userText\n\n'
          'feature: ${featureGroup?.name ?? 'none'}\n'
          'option: ${selectedOption ?? 'none'}\n'
          'temperature: ${state.temperature}\n'
          'configuredContextSize: ${state.contextSize}',
    );
    debug.log(
      level: AiDebugLevel.info,
      stage: 'context',
      requestId: requestId,
      message: 'Context sẽ được gửi tới AI',
      details: _debugContextDetails(
        activeContext: activeContext,
        clipboardHistory: clipboardHistory,
        conversationContext: conversationContext,
      ),
    );

    debug.log(
      level: AiDebugLevel.info,
      stage: 'model',
      requestId: requestId,
      message: 'Đã chọn model ${requestModel.name}',
      details:
          'id: ${requestModel.id}\n'
          'thinkingModel: ${requestModel.isThinkingModel}\n'
          'contextWindow: ${requestModel.contextWindow}\n'
          'effectiveContextSize: '
          '${state.contextSize.clamp(2048, requestModel.contextWindow)}',
    );
    final stream = _localEngine.processStream(
      model: requestModel,
      prompt: userText,
      clipboardContext: activeContext,
      clipboardHistory: clipboardHistory,
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      conversationContext: conversationContext,
      requestPlan: null,
      conversationMessages: conversationMessages,
      appLanguageTag: _ref.read(settingsControllerProvider).language,
      responseLanguageTag: responseLanguageTag,
      performanceMode: state.performanceMode,
      classification: classification,
      temperature: state.temperature,
      contextSize: state.contextSize.clamp(2048, requestModel.contextWindow),
      debugRequestId: requestId,
      onConfirmationRequested: requestToolConfirmation,
    );

    var eventCount = 0;
    var firstEventLogged = false;
    var finalThinking = '';
    var finalOutput = '';
    final timeoutDuration = resolveGenerationTimeout(
      intent: classification.intent,
      featureGroup: featureGroup,
    );
    final inactivityTimeout = resolveStreamInactivityTimeout(
      intent: classification.intent,
      featureGroup: featureGroup,
    );
    var generationTimedOut = false;
    final generationTimeout = Timer(timeoutDuration, () {
      generationTimedOut = true;
      _localEngine.cancelGeneration();
    });
    try {
      await for (final event in stream.timeout(inactivityTimeout)) {
        eventCount++;
        final type = event['type'] ?? '';
        final thinking = event['thinking'] ?? '';
        final output = event['output'] ?? '';
        finalThinking = thinking;
        finalOutput = output;
        if (!firstEventLogged) {
          firstEventLogged = true;
          debug.log(
            level: AiDebugLevel.info,
            stage: 'stream',
            requestId: requestId,
            message:
                'Nhận event đầu tiên sau ${stopwatch.elapsedMilliseconds} ms',
            details: 'type: $type\nchunk: ${event['chunk'] ?? ''}',
          );
        }

        final currentMsgs = [...state.chatMessages];
        final index = currentMsgs.indexWhere((m) => m.id == assistantMsgId);
        if (index != -1) {
          final target = currentMsgs[index];
          target.thinkingContent = thinking;
          target.content = output;
          target.isThinking = type == 'think';
          state = state.copyWith(chatMessages: currentMsgs);
        }
      }
      if (generationTimedOut) {
        throw TimeoutException(
          'AI generation exceeded ${timeoutDuration.inMinutes} minutes.',
        );
      }
      debug.log(
        level: AiDebugLevel.success,
        stage: 'response',
        requestId: requestId,
        message:
            'Hoàn tất phản hồi sau ${stopwatch.elapsedMilliseconds} ms '
            '($eventCount events)',
        details:
            'thinking:\n$finalThinking\n\n'
            'output:\n$finalOutput',
      );
    } catch (error, stackTrace) {
      debug.log(
        level: AiDebugLevel.error,
        stage: 'error',
        requestId: requestId,
        message: 'AI thất bại sau ${stopwatch.elapsedMilliseconds} ms: $error',
        details: 'errorType: ${error.runtimeType}\nstackTrace:\n$stackTrace',
      );
      final currentMsgs = [...state.chatMessages];
      final index = currentMsgs.indexWhere((m) => m.id == assistantMsgId);
      if (index != -1) {
        currentMsgs[index]
          ..isThinking = false
          ..thinkingContent = null
          ..content =
              'Mình chưa thể tạo câu trả lời lúc này. Hãy thử lại hoặc '
              'chọn một model khác.\n\nChi tiết: $error';
        state = state.copyWith(chatMessages: currentMsgs);
      }
    } finally {
      generationTimeout.cancel();
      stopwatch.stop();
      final currentMsgs = [...state.chatMessages];
      final index = currentMsgs.indexWhere((m) => m.id == assistantMsgId);
      if (index != -1) {
        currentMsgs[index].isThinking = false;
        state = state.copyWith(chatMessages: currentMsgs, isGenerating: false);
        await _saveConversation();
      }
    }
  }

  String _debugContextDetails({
    required ClipboardItem? activeContext,
    required List<ClipboardItem> clipboardHistory,
    required String conversationContext,
  }) {
    final buffer = StringBuffer()
      ..writeln('selectedClipboard: ${activeContext?.id ?? 'none'}')
      ..writeln('clipboardHistoryCount: ${clipboardHistory.length}')
      ..writeln('conversationLength: ${conversationContext.length}');
    if (activeContext != null) {
      final preview = activeContext.content.length > 200
          ? '${activeContext.content.substring(0, 200)}…'
          : activeContext.content;
      buffer
        ..writeln('selectedType: ${activeContext.contentType.name}')
        ..writeln('selectedSensitive: ${activeContext.isSensitive}')
        ..writeln('selectedPreview: $preview');
    }
    if (kReleaseMode) return buffer.toString();
    for (final item in clipboardHistory.take(10)) {
      final preview = item.content.length > 200
          ? '${item.content.substring(0, 200)}…'
          : item.content;
      buffer.writeln(
        'clip:${item.id} type:${item.contentType.name} preview:$preview',
      );
    }
    return buffer.toString();
  }

  Future<void> _restoreConversation() async {
    final saved = await _conversationRepository.load();
    if (!mounted) return;
    state = state.copyWith(
      chatMessages: _chatChangedBeforeRestore
          ? state.chatMessages
          : saved.messages,
      activeClipboardContext: _contextChangedBeforeRestore
          ? state.activeClipboardContext
          : saved.clipboardContext,
      clearClipboardContext:
          !_contextChangedBeforeRestore && saved.clipboardContext == null,
    );
    _restoreCompleted = true;
    await _refreshSessions();
  }

  Future<void> _refreshSessions() async {
    final sessions = await _conversationRepository.loadSessions();
    if (mounted) state = state.copyWith(savedConversations: sessions);
  }

  Future<void> _saveAfterRestore() async {
    await _restoreFuture;
    await _saveConversation();
  }

  Future<void> _saveConversation() async {
    await _conversationRepository.save(
      messages: state.chatMessages,
      clipboardContext: state.activeClipboardContext,
    );
  }

  String _buildConversationContext(List<AiChatMessage> messages) {
    const maximumCharacters = 6000;
    final completed = messages
        .where((message) => !message.isThinking && message.content.isNotEmpty)
        .toList(growable: false);
    final recent = completed.length > 10
        ? completed.sublist(completed.length - 10)
        : completed;
    final buffer = StringBuffer();
    for (final message in recent) {
      final role = message.role == AiMessageRole.user ? 'Người dùng' : 'AI';
      final entry = '$role: ${message.content.trim()}\n';
      if (buffer.length + entry.length > maximumCharacters) break;
      buffer.write(entry);
    }
    return buffer.toString().trim();
  }

  List<AiChatMessage> _recentConversationMessages(
    List<AiChatMessage> messages,
  ) {
    final completed = messages
        .where(
          (message) =>
              !message.isThinking &&
              message.content.trim().isNotEmpty &&
              message.role != AiMessageRole.system,
        )
        .toList(growable: false);
    return completed.length > 10
        ? completed.sublist(completed.length - 10)
        : completed;
  }

  AiModelInfo _modelForRequest() {
    bool downloaded(String id) =>
        state.downloadStates[id] == DownloadState.downloaded;
    if (downloaded(state.selectedModelId)) return state.selectedModel;
    if (downloaded(AiModelInfo.defaultModelId)) {
      return AiModelInfo.findById(AiModelInfo.defaultModelId);
    }
    for (final model in AiModelInfo.thinkingModels) {
      if (downloaded(model.id)) return model;
    }
    return state.selectedModel;
  }

  @override
  void dispose() {
    for (final sub in _downloadSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
