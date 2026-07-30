import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/ui/app_window_controls.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../domain/ai_feature_action.dart';
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
    final isEn = AppTranslations.currentLanguage == 'en';
    final promptText = isEn
        ? 'Perform "${group.title}" with option "$option".'
        : 'Thực hiện "${group.title}" với tùy chọn "$option".';

    var contextItem = aiState.activeClipboardContext;

    if (group == AiFeatureGroup.ocrRefine &&
        contextItem?.contentType == ClipboardContentType.image) {
      final extracted = await ref
          .read(historyControllerProvider.notifier)
          .performOcr(contextItem!);
      if (!mounted) return;
      if (extracted == null || extracted.trim().isEmpty) {
        showCupertinoNotice(context, 'ocr_empty'.tr);
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
            child: Text(opt),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
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
                  message: Text('ai_conversation_options'.tr),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context, (
                        conversation: selected,
                        action: _ConversationAction.rename,
                      )),
                      child: Text('rename'.tr),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context, (
                        conversation: selected,
                        action: _ConversationAction.togglePin,
                      )),
                      child: Text(selected.isPinned ? 'unpin'.tr : 'pin'.tr),
                    ),
                    CupertinoActionSheetAction(
                      isDestructiveAction: true,
                      onPressed: () => Navigator.pop(context, (
                        conversation: selected,
                        action: _ConversationAction.delete,
                      )),
                      child: Text('delete'.tr),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () =>
                        setModalState(() => actionConversation = null),
                    child: Text('back'.tr),
                  ),
                );
              }

              return CupertinoActionSheet(
                title: Text('ai_conversation_history'.tr),
                message: Text('ai_history_subtitle'.tr),
                actions: [
                  CupertinoActionSheetAction(
                    isDefaultAction: true,
                    onPressed: () {
                      Navigator.pop(context);
                      ref
                          .read(aiControllerProvider.notifier)
                          .startNewConversation();
                    },
                    child: Text('ai_new_conversation'.tr),
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
                  child: Text('cancel'.tr),
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
            title: Text('ai_rename_dialog_title'.tr),
            content: CupertinoTextField(controller: controller),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text('save'.tr),
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
        title: Text('ai_gen_settings_title'.tr),
        message: Text('ai_gen_settings_sub'.tr),
        actions: [
          for (final profile in [
            ('ai_profile_precise'.tr, 0.2, 2048),
            ('ai_profile_balanced'.tr, 0.55, 4096),
            ('ai_profile_creative'.tr, 0.85, 8192),
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
          child: Text('cancel'.tr),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AiState>(aiControllerProvider, (previous, next) {
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
                        tooltip: 'ai_conversation_history'.tr,
                        onPressed: _showConversations,
                      ),
                      CupertinoIconControl(
                        icon: CupertinoIcons.slider_horizontal_3,
                        size: 16,
                        tooltip: 'ai_config'.tr,
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
                              'main_window'.tr,
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
                    showCupertinoNotice(context, 'copied'.tr);
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
                              showCupertinoNotice(context, 'copied'.tr);
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
                        placeholder: 'ai_send_prompt'.tr,
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
