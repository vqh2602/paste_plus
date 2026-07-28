import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../app/providers.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_chat_message.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_model_info.dart';
import '../services/ai_model_downloader_service.dart';
import '../services/local_ai_engine.dart';

class AiState {
  const AiState({
    required this.selectedModelId,
    this.downloadStates = const {},
    this.downloadProgresses = const {},
    this.chatMessages = const [],
    this.activeClipboardContext,
    this.isGenerating = false,
  });

  final String selectedModelId;
  final Map<String, DownloadState> downloadStates;
  final Map<String, ModelDownloadProgress> downloadProgresses;
  final List<AiChatMessage> chatMessages;
  final ClipboardItem? activeClipboardContext;
  final bool isGenerating;

  AiModelInfo get selectedModel => AiModelInfo.findById(selectedModelId);

  AiState copyWith({
    String? selectedModelId,
    Map<String, DownloadState>? downloadStates,
    Map<String, ModelDownloadProgress>? downloadProgresses,
    List<AiChatMessage>? chatMessages,
    ClipboardItem? activeClipboardContext,
    bool clearClipboardContext = false,
    bool? isGenerating,
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
    );
  }
}

class AiController extends StateNotifier<AiState> {
  AiController(
    this._downloaderService,
    this._localEngine,
    this._ref,
  ) : super(
          AiState(
            selectedModelId:
                _ref.read(settingsControllerProvider).selectedAiModel,
          ),
        ) {
    _checkDownloadedModels();
  }

  final AiModelDownloaderService _downloaderService;
  final LocalAiEngine _localEngine;
  final Ref _ref;
  final Map<String, StreamSubscription> _downloadSubscriptions = {};

  Future<void> _checkDownloadedModels() async {
    final newStates = Map<String, DownloadState>.from(state.downloadStates);
    for (final model in AiModelInfo.thinkingModels) {
      final downloaded = await _downloaderService.isModelDownloaded(model.id);
      newStates[model.id] =
          downloaded ? DownloadState.downloaded : DownloadState.notDownloaded;
    }
    state = state.copyWith(downloadStates: newStates);
  }

  void selectModel(String modelId) {
    state = state.copyWith(selectedModelId: modelId);
    _ref.read(settingsControllerProvider.notifier).update(
          (current) => current.copyWith(selectedAiModel: modelId),
        );
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

  Future<void> deleteModel(String modelId) async {
    cancelDownload(modelId);
    await _downloaderService.deleteModel(modelId);

    final states = Map<String, DownloadState>.from(state.downloadStates);
    states[modelId] = DownloadState.notDownloaded;
    state = state.copyWith(downloadStates: states);
  }

  void setClipboardContext(ClipboardItem? item) {
    state = state.copyWith(
      activeClipboardContext: item,
      clearClipboardContext: item == null,
    );
  }

  void clearChat() {
    state = state.copyWith(chatMessages: []);
  }

  Future<void> sendUserMessage(
    String userText, {
    AiFeatureGroup? featureGroup,
    String? selectedOption,
    ClipboardItem? contextItem,
  }) async {
    if (state.isGenerating) return;

    final activeContext = contextItem ?? state.activeClipboardContext;
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
    state = state.copyWith(
      chatMessages: updatedMessages,
      isGenerating: true,
    );

    final stream = _localEngine.processStream(
      model: state.selectedModel,
      prompt: userText,
      clipboardContext: activeContext,
      featureGroup: featureGroup,
      selectedOption: selectedOption,
    );

    try {
      await for (final event in stream) {
        final type = event['type'] ?? '';
        final thinking = event['thinking'] ?? '';
        final output = event['output'] ?? '';

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
    } finally {
      final currentMsgs = [...state.chatMessages];
      final index = currentMsgs.indexWhere((m) => m.id == assistantMsgId);
      if (index != -1) {
        currentMsgs[index].isThinking = false;
        state = state.copyWith(
          chatMessages: currentMsgs,
          isGenerating: false,
        );
      }
    }
  }

  @override
  void dispose() {
    for (final sub in _downloadSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }
}
