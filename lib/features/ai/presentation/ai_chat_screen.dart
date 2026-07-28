import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../clipboard_history/domain/clipboard_content_type.dart';
import '../domain/ai_feature_action.dart';
import '../data/ai_conversation_repository.dart';
import 'widgets/ai_context_banner_widget.dart';
import 'widgets/ai_message_tile_widget.dart';
import 'widgets/ai_no_model_overlay.dart';
import 'widgets/ai_preset_pills_widget.dart';

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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
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
    _scrollToBottom();
  }

  Future<void> _runFeatureAction(AiFeatureGroup group, String option) async {
    final aiState = ref.read(aiControllerProvider);
    final promptText = 'Thực hiện "${group.title}" với tùy chọn "$option".';
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
    _scrollToBottom();
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
    await ref.read(desktopIntegrationProvider).showMainWindow();
  }

  void _showConversations() {
    final conversations = ref.read(aiControllerProvider).savedConversations;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Lịch sử hội thoại'),
        message: const Text('Tối đa 20 phiên gần nhất, lưu trên thiết bị'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              ref.read(aiControllerProvider.notifier).startNewConversation();
            },
            child: const Text('＋ Hội thoại mới'),
          ),
          for (final conversation in conversations)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                ref
                    .read(aiControllerProvider.notifier)
                    .openConversation(conversation);
              },
              child: Row(
                children: [
                  if (conversation.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(CupertinoIcons.pin_fill, size: 14),
                    ),
                  Expanded(child: Text(conversation.title)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(30, 30),
                    onPressed: () {
                      Navigator.pop(context);
                      _showConversationActions(conversation);
                    },
                    child: const Icon(CupertinoIcons.ellipsis, size: 16),
                  ),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
      ),
    );
  }

  void _showConversationActions(SavedAiConversation conversation) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(conversation.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              final controller = TextEditingController(
                text: conversation.title,
              );
              final title = await showCupertinoDialog<String>(
                context: this.context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Đổi tên hội thoại'),
                  content: CupertinoTextField(controller: controller),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel'.tr),
                    ),
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(context, controller.text),
                      child: const Text('Lưu'),
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
            },
            child: const Text('Đổi tên'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(aiControllerProvider.notifier)
                  .toggleConversationPinned(conversation.id);
            },
            child: Text(conversation.isPinned ? 'Bỏ ghim' : 'Ghim'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(aiControllerProvider.notifier)
                  .deleteConversation(conversation.id);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showGenerationSettings() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Cấu hình sinh nội dung'),
        message: const Text('Áp dụng cho các câu trả lời tiếp theo'),
        actions: [
          for (final profile in const [
            ('Chính xác · 2K', 0.2, 2048),
            ('Cân bằng · 4K', 0.55, 4096),
            ('Sáng tạo · 8K', 0.85, 8192),
          ])
            CupertinoActionSheetAction(
              onPressed: () {
                ref
                    .read(aiControllerProvider.notifier)
                    .setGenerationProfile(
                      temperature: profile.$2,
                      contextSize: profile.$3,
                    );
                Navigator.pop(context);
              },
              child: Text(profile.$1),
            ),
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
    final aiState = ref.watch(aiControllerProvider);
    final historyItemCount = ref.watch(
      historyControllerProvider.select((state) => state.items.length),
    );

    return CupertinoPageScaffold(
      child: Column(
        children: [
          // Drag-to-move Header Title Bar for standalone macOS window
          if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
            DragToMoveArea(
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 80),
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
                      tooltip: 'Lịch sử hội thoại',
                      onPressed: _showConversations,
                    ),
                    CupertinoIconControl(
                      icon: CupertinoIcons.slider_horizontal_3,
                      size: 16,
                      tooltip: 'Cấu hình AI',
                      onPressed: _showGenerationSettings,
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: _openMainWindow,
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.sidebar_left, size: 14),
                          SizedBox(width: 4),
                          Text('Cửa sổ chính', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    CupertinoIconControl(
                      icon: CupertinoIcons.trash,
                      size: 16,
                      onPressed: () {
                        ref.read(aiControllerProvider.notifier).clearChat();
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
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
                                TextSelection.collapsed(offset: content.length);
                            _focusNode.requestFocus();
                          },
                          onRegenerate: index == aiState.chatMessages.length - 1
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
