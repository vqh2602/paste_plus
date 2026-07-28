import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_feature_action.dart';
import 'widgets/ai_context_banner_widget.dart';
import 'widgets/ai_message_tile_widget.dart';
import 'widgets/ai_no_model_overlay.dart';
import 'widgets/ai_preset_pills_widget.dart';

class AiChatDialog extends ConsumerStatefulWidget {
  const AiChatDialog({
    super.key,
    this.initialContextItem,
  });

  final ClipboardItem? initialContextItem;

  static Future<void> show(BuildContext context, {ClipboardItem? contextItem}) async {
    await showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AiChatDialog(initialContextItem: contextItem),
    );
  }

  @override
  ConsumerState<AiChatDialog> createState() => _AiChatDialogState();
}

class _AiChatDialogState extends ConsumerState<AiChatDialog> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialContextItem != null) {
        ref.read(aiControllerProvider.notifier).setClipboardContext(widget.initialContextItem);
      } else {
        final historyState = ref.read(historyControllerProvider);
        if (historyState.visibleItems.isNotEmpty) {
          ref.read(aiControllerProvider.notifier).setClipboardContext(historyState.visibleItems.first);
        }
      }
    });
  }

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

    await ref.read(aiControllerProvider.notifier).sendUserMessage(
          promptText,
          featureGroup: group,
          selectedOption: option,
          contextItem: aiState.activeClipboardContext,
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

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 760;

    return Center(
      child: Padding(
        padding: compact ? EdgeInsets.zero : const EdgeInsets.all(24),
        child: CupertinoSurface(
          borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(22),
          child: SizedBox(
            width: compact ? size.width : 880,
            height: compact ? size.height : size.height.clamp(600, 720),
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.sparkles,
                        color: CupertinoColors.activeBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ai_chat_assistant'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.activeGreen.withValues(alpha: 0.3),
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
                            const Text(
                              'Offline • Local AI',
                              style: TextStyle(
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
                        icon: CupertinoIcons.trash,
                        size: 16,
                        onPressed: () {
                          ref.read(aiControllerProvider.notifier).clearChat();
                        },
                      ),
                      const SizedBox(width: 4),
                      CupertinoIconControl(
                        icon: CupertinoIcons.xmark,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
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
                    onClear: () {
                      ref
                          .read(aiControllerProvider.notifier)
                          .setClipboardContext(null);
                    },
                  ),

                if (aiState.activeClipboardContext != null) const CupertinoDivider(),

                // Horizontal Preset Action Pills Bar
                AiPresetPillsWidget(
                  onSelectGroup: (group) => _showFeatureOptionsPicker(group),
                ),
                const CupertinoDivider(),

                // Chat History Messages List
                Expanded(
                  child: aiState.chatMessages.isEmpty
                      ? _AiWelcomeState(
                          model: aiState.selectedModel,
                          onActionSelected: (group) => _showFeatureOptionsPicker(group),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: aiState.chatMessages.length,
                          itemBuilder: (context, index) {
                            final msg = aiState.chatMessages[index];
                            return AiMessageTileWidget(
                              message: msg,
                              onCopy: (content) {
                                Clipboard.setData(ClipboardData(text: content));
                                showCupertinoNotice(context, 'copied'.tr);
                              },
                              onPaste: (content) async {
                                final desktop = ref.read(desktopIntegrationProvider);
                                await Clipboard.setData(ClipboardData(text: content));
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                await desktop.hideQuickPanel();
                                await desktop.pasteToPreviousApplication();
                              },
                            );
                          },
                        ),
                ),

                const CupertinoDivider(),

                // Input Bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          placeholder: 'ai_send_prompt'.tr,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: resolveColor(context, ClipFlowColors.surface),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: resolveColor(context, ClipFlowColors.border),
                            ),
                          ),
                          onSubmitted: (_) => _submitPrompt(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CupertinoButton.filled(
                        padding: const EdgeInsets.all(10),
                        borderRadius: BorderRadius.circular(14),
                        onPressed: aiState.isGenerating ? null : () => _submitPrompt(),
                        child: aiState.isGenerating
                            ? const CupertinoActivityIndicator(radius: 8, color: CupertinoColors.white)
                            : const Icon(CupertinoIcons.arrow_up, size: 18),
                      ),
                    ],
                  ),
                ),
                ], // end else hasAnyDownloadedModel
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiWelcomeState extends StatelessWidget {
  const _AiWelcomeState({
    required this.model,
    required this.onActionSelected,
  });

  final dynamic model;
  final ValueChanged<AiFeatureGroup> onActionSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.sparkles,
              size: 38,
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'ClipFlow Local AI Assistant',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Xử lý 100% ngoại tuyến trên thiết bị với ${model.name}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: AiFeatureGroup.values.take(6).map((group) {
              return CupertinoPressable(
                onPressed: () => onActionSelected(group),
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: resolveColor(context, ClipFlowColors.surface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: resolveColor(context, ClipFlowColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(group.icon, size: 16, color: CupertinoTheme.of(context).primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.title,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              group.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: resolveColor(context, ClipFlowColors.secondaryText),
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
