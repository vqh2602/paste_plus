import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_chat_message.dart';
import '../domain/ai_feature_action.dart';

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

                // Active Clipboard Context Banner
                if (aiState.activeClipboardContext != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: resolveColor(context, ClipFlowColors.sidebar),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.doc_on_clipboard,
                          size: 14,
                          color: resolveColor(context, ClipFlowColors.secondaryText),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ai_context_clip'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: resolveColor(context, ClipFlowColors.secondaryText),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            aiState.activeClipboardContext?.content ?? 'Image/Data',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        CupertinoPressable(
                          onPressed: () {
                            ref
                                .read(aiControllerProvider.notifier)
                                .setClipboardContext(null);
                          },
                          child: Text(
                            'ai_clear_context'.tr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.systemRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (aiState.activeClipboardContext != null) const CupertinoDivider(),

                // Horizontal Preset Action Pills Bar
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: AiFeatureGroup.values.map((group) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: CupertinoPressable(
                          onPressed: () => _showFeatureOptionsPicker(group),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: resolveColor(context, ClipFlowColors.surface),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: resolveColor(context, ClipFlowColors.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  group.icon,
                                  size: 13,
                                  color: CupertinoTheme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  group.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 10,
                                  color: resolveColor(context, ClipFlowColors.secondaryText),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                            return _AiMessageTile(
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

class _AiMessageTile extends StatefulWidget {
  const _AiMessageTile({
    required this.message,
    required this.onCopy,
    required this.onPaste,
  });

  final AiChatMessage message;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onPaste;

  @override
  State<_AiMessageTile> createState() => _AiMessageTileState();
}

class _AiMessageTileState extends State<_AiMessageTile> {
  bool _thinkingExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == AiMessageRole.user;
    final primary = CupertinoTheme.of(context).primaryColor;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14, left: 60),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.message.content,
              style: const TextStyle(fontSize: 14, color: CupertinoColors.white),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 40),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: resolveColor(context, ClipFlowColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.sparkles, size: 15, color: CupertinoColors.activeBlue),
                const SizedBox(width: 6),
                const Text(
                  'ClipFlow AI',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (widget.message.isThinking)
                  const CupertinoActivityIndicator(radius: 6),
              ],
            ),

            // Collapsible Thinking Process Block (<think>...</think>)
            if (widget.message.thinkingContent != null &&
                widget.message.thinkingContent!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    CupertinoPressable(
                      onPressed: () => setState(() => _thinkingExpanded = !_thinkingExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            const Text('🧠 ', style: TextStyle(fontSize: 13)),
                            const Text(
                              'Quá trình suy luận (Thinking process)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemIndigo,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _thinkingExpanded
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 12,
                              color: CupertinoColors.systemIndigo,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_thinkingExpanded) ...[
                      const CupertinoDivider(),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          widget.message.thinkingContent!,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: resolveColor(context, ClipFlowColors.secondaryText),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            Text(
              widget.message.content.isEmpty
                  ? (widget.message.isThinking ? 'Đang suy luận...' : '')
                  : widget.message.content,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),

            if (widget.message.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => widget.onCopy(widget.message.content),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.doc_on_doc, size: 12, color: primary),
                        const SizedBox(width: 4),
                        Text(
                          'copy'.tr,
                          style: TextStyle(fontSize: 12, color: primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    color: CupertinoColors.activeGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => widget.onPaste(widget.message.content),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.arrow_right_square, size: 12, color: CupertinoColors.activeGreen),
                        SizedBox(width: 4),
                        Text(
                          'Dán kết quả',
                          style: TextStyle(fontSize: 12, color: CupertinoColors.activeGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
