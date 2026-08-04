import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/providers.dart';
import '../../../core/ui/app_window_controls.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../domain/ai_feature_action.dart';
import '../domain/ai_feature_request.dart';
import '../data/ai_conversation_repository.dart';
import 'ai_controller.dart';
import 'widgets/ai_context_banner_widget.dart';
import 'widgets/ai_context_picker_sheet.dart';
import 'widgets/ai_conversation_history_action.dart';
import 'widgets/ai_message_tile_widget.dart';
import 'widgets/ai_mobile_toolbar.dart';
import 'widgets/ai_no_model_overlay.dart';
import 'widgets/ai_preset_pills_widget.dart';

enum _ConversationAction { rename, togglePin, delete }

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final isNearBottom = (maxScroll - currentScroll) <= 160;

      if (force || isNearBottom) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _submitPrompt([String? customText]) async {
    final text = (customText ?? _inputController.text).trim();
    if (text.isEmpty) return;
    _inputController.clear();

    await ref.read(aiControllerProvider.notifier).sendUserMessage(text);
    _scrollToBottom(force: true);
  }

  Future<void> _runFeatureAction(AiFeatureGroup group, String option) async {
    final aiState = ref.read(aiControllerProvider);
    final promptText = 'Perform "${group.title}" with option "$option".';

    var contextItem = aiState.activeClipboardContext;

    if (group == AiFeatureGroup.ocrRefine &&
        contextItem?.contentType == ClipboardContentType.image) {
      final extracted = await ref
          .read(historyControllerProvider.notifier)
          .performOcr(contextItem!);
      if (!mounted) return;
      if (extracted == null || extracted.trim().isEmpty) {
        showCupertinoNotice(context, context.l10n.ocr_empty);
        return;
      }
      contextItem = contextItem.copyWith(
        content: extracted,
        normalizedContent: extracted.trim(),
      );
    }

    await ref
        .read(aiControllerProvider.notifier)
        .sendUserMessage(
          promptText,
          featureGroup: group,
          featureRequest: group == AiFeatureGroup.translate
              ? AiTranslateRequest(targetLocaleTag: option)
              : null,
          selectedOption: option,
          contextItem: contextItem,
        );
    _scrollToBottom(force: true);
  }

  void _showFeatureOptionsPicker(AiFeatureGroup group) {
    showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(group.title),
        message: Text(group.subtitle),
        actions: group.options.map((opt) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context, opt);
            },
            child: Text(group.optionLabel(opt)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ),
    ).then((selectedOpt) {
      if (selectedOpt != null && mounted) {
        _runFeatureAction(group, selectedOpt);
      }
    });
  }

  Future<void> _openMainWindow() async {
    ref.read(aiWindowModeProvider.notifier).state = false;
    if (Platform.isIOS || Platform.isAndroid) return;
    await ref.read(desktopIntegrationProvider).showMainWindow();
  }

  Future<void> _showContextPicker() async {
    final aiState = ref.read(aiControllerProvider);
    final selected = await AiContextPickerSheet.show(
      context,
      items: ref.read(historyControllerProvider).items,
      selectedItemId: aiState.activeClipboardContext?.id,
    );
    if (selected == null || !mounted) return;
    ref.read(aiControllerProvider.notifier).setClipboardContext(selected);
  }

  Future<void> _showConversations() async {
    final conversations = ref.read(aiControllerProvider).savedConversations;
    SavedAiConversation? actionConversation;
    final selection =
        await showCupertinoModalPopup<
          ({SavedAiConversation conversation, _ConversationAction action})
        >(
          context: context,
          builder: (popupContext) => StatefulBuilder(
            builder: (context, setModalState) {
              final selected = actionConversation;
              if (selected != null) {
                return CupertinoActionSheet(
                  title: Text(selected.title),
                  message: Text(context.l10n.ai_conversation_options),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context, (
                        conversation: selected,
                        action: _ConversationAction.rename,
                      )),
                      child: Text(context.l10n.rename),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context, (
                        conversation: selected,
                        action: _ConversationAction.togglePin,
                      )),
                      child: Text(
                        selected.isPinned
                            ? context.l10n.unpin
                            : context.l10n.pin,
                      ),
                    ),
                    CupertinoActionSheetAction(
                      isDestructiveAction: true,
                      onPressed: () => Navigator.pop(context, (
                        conversation: selected,
                        action: _ConversationAction.delete,
                      )),
                      child: Text(context.l10n.delete),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () =>
                        setModalState(() => actionConversation = null),
                    child: Text(context.l10n.back),
                  ),
                );
              }

              return CupertinoActionSheet(
                title: Text(context.l10n.ai_conversation_history),
                message: Text(context.l10n.ai_history_subtitle),
                actions: [
                  CupertinoActionSheetAction(
                    isDefaultAction: true,
                    onPressed: () {
                      Navigator.pop(context);
                      ref
                          .read(aiControllerProvider.notifier)
                          .startNewConversation();
                    },
                    child: Text(context.l10n.ai_new_conversation),
                  ),

                  for (final conversation in conversations)
                    AiConversationHistoryAction(
                      conversation: conversation,
                      onOpen: () {
                        Navigator.pop(context);
                        ref
                            .read(aiControllerProvider.notifier)
                            .openConversation(conversation);
                      },
                      onMore: () => setModalState(
                        () => actionConversation = conversation,
                      ),
                    ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
              );
            },
          ),
        );
    if (selection != null && mounted) {
      await _handleConversationAction(selection.conversation, selection.action);
    }
  }

  Future<void> _handleConversationAction(
    SavedAiConversation conversation,
    _ConversationAction action,
  ) async {
    switch (action) {
      case _ConversationAction.rename:
        final controller = TextEditingController(text: conversation.title);
        final title = await showCupertinoDialog<String>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(context.l10n.ai_rename_dialog_title),
            content: CupertinoTextField(controller: controller),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(context.l10n.save),
              ),
            ],
          ),
        );
        controller.dispose();
        if (title != null && mounted) {
          await ref
              .read(aiControllerProvider.notifier)
              .renameConversation(conversation.id, title);
        }
      case _ConversationAction.togglePin:
        await ref
            .read(aiControllerProvider.notifier)
            .toggleConversationPinned(conversation.id);
      case _ConversationAction.delete:
        await ref
            .read(aiControllerProvider.notifier)
            .deleteConversation(conversation.id);
    }
  }

  void _showGenerationSettings() {
    final aiState = ref.read(aiControllerProvider);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.ai_gen_settings_title),
        message: Text(context.l10n.ai_gen_settings_sub),
        actions: [
          for (final profile in [
            (context.l10n.ai_profile_precise, 0.2, 2048),
            (context.l10n.ai_profile_balanced, 0.55, 4096),
            (context.l10n.ai_profile_creative, 0.85, 8192),
          ]) ...[
            () {
              final isSelected =
                  (aiState.temperature - profile.$2).abs() < 0.05 &&
                  aiState.contextSize == profile.$3;
              return CupertinoActionSheetAction(
                onPressed: () {
                  ref
                      .read(aiControllerProvider.notifier)
                      .setGenerationProfile(
                        temperature: profile.$2,
                        contextSize: profile.$3,
                      );
                  Navigator.pop(context);
                },
                isDefaultAction: isSelected,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          CupertinoIcons.checkmark,
                          size: 18,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    Text(
                      profile.$1,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? CupertinoColors.activeBlue : null,
                      ),
                    ),
                  ],
                ),
              );
            }(),
          ],
        ],

        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiState>(aiControllerProvider, (previous, next) {
      if (next.pendingToolCall != null &&
          previous?.pendingToolCall != next.pendingToolCall) {
        final pending = next.pendingToolCall!;
        final toolDisplayName = switch (pending.toolName) {
          'pin_clipboard' => context.l10n.pin,
          'delete_clipboard_item' => context.l10n.delete,
          'add_to_collection' => context.l10n.add_to_collection,
          _ => pending.toolName,
        };

        showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.aiTitle),
            content: Text('$toolDisplayName\n${pending.arguments}'),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(ctx, false);
                  ref
                      .read(aiControllerProvider.notifier)
                      .rejectPendingToolCall();
                },
                child: Text(context.l10n.cancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: pending.toolName.contains('delete'),
                onPressed: () {
                  Navigator.pop(ctx, true);
                  ref
                      .read(aiControllerProvider.notifier)
                      .approvePendingToolCall();
                },
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        );
      }

      final prevLen = previous?.chatMessages.length ?? 0;
      final nextLen = next.chatMessages.length;
      final prevLastContent = previous?.chatMessages.lastOrNull?.content;
      final nextLastContent = next.chatMessages.lastOrNull?.content;
      final prevThinking = previous?.chatMessages.lastOrNull?.thinkingContent;
      final nextThinking = next.chatMessages.lastOrNull?.thinkingContent;

      final isNewMessage = nextLen > prevLen;
      final isStreaming =
          prevLastContent != nextLastContent || prevThinking != nextThinking;

      if (isNewMessage) {
        _scrollToBottom(force: true);
      } else if (isStreaming || next.isGenerating) {
        _scrollToBottom(force: false);
      }
    });

    final aiState = ref.watch(aiControllerProvider);
    final historyItemCount = ref.watch(
      historyControllerProvider.select((state) => state.items.length),
    );
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // Drag-to-move Header Title Bar for standalone macOS window
            if (isDesktop)
              DragToMoveArea(
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      if (Platform.isMacOS)
                        const SizedBox(width: 80)
                      else
                        const SizedBox(width: 14),
                      const Icon(
                        CupertinoIcons.sparkles,
                        color: CupertinoColors.activeBlue,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ClipFlow Local AI Assistant',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeGreen.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.activeGreen.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: CupertinoColors.activeGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Offline • ${aiState.selectedModel.parameterSize}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.activeGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      CupertinoIconControl(
                        icon: CupertinoIcons.clock,
                        size: 16,
                        tooltip: context.l10n.ai_conversation_history,
                        onPressed: _showConversations,
                      ),
                      CupertinoIconControl(
                        icon: CupertinoIcons.slider_horizontal_3,
                        size: 16,
                        tooltip: context.l10n.ai_config,
                        onPressed: _showGenerationSettings,
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: _openMainWindow,
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.sidebar_left, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.main_window,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      CupertinoIconControl(
                        icon: CupertinoIcons.trash,
                        size: 16,
                        onPressed: () {
                          ref.read(aiControllerProvider.notifier).clearChat();
                        },
                      ),
                      if (Platform.isWindows || Platform.isLinux)
                        const AppWindowControls()
                      else
                        const SizedBox(width: 12),
                    ],
                  ),
                ),
              ),
            if (!isDesktop)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AiMobileToolbar(
                  onClose: _openMainWindow,
                  onChooseContext: _showContextPicker,
                  onShowHistory: _showConversations,
                  hasContext: aiState.activeClipboardContext != null,
                ),
              ),
            const CupertinoDivider(),

            // Show mandatory model download overlay if no model downloaded
            if (!aiState.hasAnyDownloadedModel)
              const Expanded(child: AiNoModelOverlay())
            else ...[
              // Active Clipboard Context Banner
              if (aiState.activeClipboardContext != null)
                AiContextBannerWidget(
                  item: aiState.activeClipboardContext!,
                  onCopy: () async {
                    await ref
                        .read(historyControllerProvider.notifier)
                        .copy(aiState.activeClipboardContext!);
                    if (!context.mounted) return;
                    showCupertinoNotice(context, context.l10n.copied);
                  },
                  onClear: () {
                    ref
                        .read(aiControllerProvider.notifier)
                        .setClipboardContext(null);
                  },
                ),

              if (aiState.activeClipboardContext == null)
                AiHistoryContextBannerWidget(itemCount: historyItemCount),

              const CupertinoDivider(),

              // Horizontal Preset Action Pills Bar
              AiPresetPillsWidget(
                onSelectGroup: (group) => _showFeatureOptionsPicker(group),
              ),
              const CupertinoDivider(),

              // Main Chat Message History List View
              Expanded(
                child: aiState.chatMessages.isEmpty
                    ? _AiScreenWelcomeState(
                        model: aiState.selectedModel,
                        onActionSelected: (group) =>
                            _showFeatureOptionsPicker(group),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: aiState.chatMessages.length,
                        itemBuilder: (context, index) {
                          final msg = aiState.chatMessages[index];
                          return AiMessageTileWidget(
                            message: msg,
                            onEdit: (content) {
                              _inputController.text = content;
                              _inputController.selection =
                                  TextSelection.collapsed(
                                    offset: content.length,
                                  );
                              _focusNode.requestFocus();
                            },
                            onRegenerate:
                                index == aiState.chatMessages.length - 1
                                ? () => ref
                                      .read(aiControllerProvider.notifier)
                                      .regenerateLastResponse()
                                : null,
                            onContinue: index == aiState.chatMessages.length - 1
                                ? () => ref
                                      .read(aiControllerProvider.notifier)
                                      .continueLastResponse()
                                : null,
                            onCopy: (content) {
                              Clipboard.setData(ClipboardData(text: content));
                              showCupertinoNotice(context, context.l10n.copied);
                            },
                            onPaste: (content) async {
                              final desktop = ref.read(
                                desktopIntegrationProvider,
                              );
                              await Clipboard.setData(
                                ClipboardData(text: content),
                              );
                              await desktop.pasteToPreviousApplication();
                            },
                          );
                        },
                      ),
              ),

              const CupertinoDivider(),

              // Prompt Input Field Bar
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        placeholder: context.l10n.ai_send_prompt,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: resolveColor(context, ClipFlowColors.surface),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: resolveColor(context, ClipFlowColors.border),
                          ),
                        ),
                        onSubmitted: (_) => _submitPrompt(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CupertinoButton.filled(
                      padding: const EdgeInsets.all(12),
                      borderRadius: BorderRadius.circular(16),
                      onPressed: aiState.isGenerating
                          ? () => ref
                                .read(aiControllerProvider.notifier)
                                .stopGeneration()
                          : () => _submitPrompt(),
                      child: aiState.isGenerating
                          ? const Icon(CupertinoIcons.stop_fill, size: 18)
                          : const Icon(CupertinoIcons.arrow_up, size: 20),
                    ),
                  ],
                ),
              ), // end Padding for input bar
            ], // end else hasAnyDownloadedModel
          ],
        ),
      ),
    );
  }
}

class _AiScreenWelcomeState extends StatelessWidget {
  const _AiScreenWelcomeState({
    required this.model,
    required this.onActionSelected,
  });

  final dynamic model;
  final ValueChanged<AiFeatureGroup> onActionSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoTheme.of(
                context,
              ).primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.sparkles,
              size: 48,
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ClipFlow Local AI Assistant',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Cửa sổ AI độc lập — Xử lý 100% ngoại tuyến với ${model.name}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: AiFeatureGroup.values.map((group) {
              return CupertinoPressable(
                onPressed: () => onActionSelected(group),
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: resolveColor(context, ClipFlowColors.surface),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: resolveColor(context, ClipFlowColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        group.icon,
                        size: 18,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              group.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: resolveColor(
                                  context,
                                  ClipFlowColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
