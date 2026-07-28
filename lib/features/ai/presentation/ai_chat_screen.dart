import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/ui/cupertino_components.dart';
import '../domain/ai_chat_message.dart';
import '../domain/ai_feature_action.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final historyState = ref.read(historyControllerProvider);
      if (historyState.visibleItems.isNotEmpty &&
          ref.read(aiControllerProvider).activeClipboardContext == null) {
        ref
            .read(aiControllerProvider.notifier)
            .setClipboardContext(historyState.visibleItems.first);
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

  Future<void> _openMainWindow() async {
    ref.read(aiWindowModeProvider.notifier).state = false;
    await ref.read(desktopIntegrationProvider).showMainWindow();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiControllerProvider);

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
                        color: CupertinoColors.activeGreen
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.activeGreen
                              .withValues(alpha: 0.3),
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
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: _openMainWindow,
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.sidebar_left, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Cửa sổ chính',
                            style: TextStyle(fontSize: 12),
                          ),
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

          // Active Clipboard Context Banner
          if (aiState.activeClipboardContext != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      color:
                          resolveColor(context, ClipFlowColors.secondaryText),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              children: AiFeatureGroup.values.map((group) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CupertinoPressable(
                    onPressed: () => _showFeatureOptionsPicker(group),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                            color: resolveColor(
                              context,
                              ClipFlowColors.secondaryText,
                            ),
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
                      return _AiScreenMessageTile(
                        message: msg,
                        onCopy: (content) {
                          Clipboard.setData(ClipboardData(text: content));
                          showCupertinoNotice(context, 'copied'.tr);
                        },
                        onPaste: (content) async {
                          final desktop =
                              ref.read(desktopIntegrationProvider);
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
                  onPressed:
                      aiState.isGenerating ? null : () => _submitPrompt(),
                  child: aiState.isGenerating
                      ? const CupertinoActivityIndicator(
                          radius: 9,
                          color: CupertinoColors.white,
                        )
                      : const Icon(CupertinoIcons.arrow_up, size: 20),
                ),
              ],
            ),
          ),
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
              color: CupertinoTheme.of(context)
                  .primaryColor
                  .withValues(alpha: 0.12),
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

class _AiScreenMessageTile extends StatefulWidget {
  const _AiScreenMessageTile({
    required this.message,
    required this.onCopy,
    required this.onPaste,
  });

  final AiChatMessage message;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onPaste;

  @override
  State<_AiScreenMessageTile> createState() => _AiScreenMessageTileState();
}

class _AiScreenMessageTileState extends State<_AiScreenMessageTile> {
  bool _thinkingExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == AiMessageRole.user;
    final primary = CupertinoTheme.of(context).primaryColor;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 80),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              widget.message.content,
              style:
                  const TextStyle(fontSize: 14, color: CupertinoColors.white),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 60),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: resolveColor(context, ClipFlowColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.sparkles,
                  size: 16,
                  color: CupertinoColors.activeBlue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ClipFlow AI',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (widget.message.isThinking)
                  const CupertinoActivityIndicator(radius: 7),
              ],
            ),

            // Collapsible Thinking Process Block (<think>...</think>)
            if (widget.message.thinkingContent != null &&
                widget.message.thinkingContent!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    CupertinoPressable(
                      onPressed: () =>
                          setState(() => _thinkingExpanded = !_thinkingExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Text('🧠 ', style: TextStyle(fontSize: 14)),
                            const Text(
                              'Quá trình suy luận (Thinking process)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.systemIndigo,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _thinkingExpanded
                                  ? CupertinoIcons.chevron_up
                                  : CupertinoIcons.chevron_down,
                              size: 13,
                              color: CupertinoColors.systemIndigo,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_thinkingExpanded) ...[
                      const CupertinoDivider(),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          widget.message.thinkingContent!,
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: resolveColor(
                              context,
                              ClipFlowColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Text(
              widget.message.content.isEmpty
                  ? (widget.message.isThinking ? 'Đang suy luận...' : '')
                  : widget.message.content,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),

            if (widget.message.content.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => widget.onCopy(widget.message.content),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.doc_on_doc,
                            size: 13, color: primary),
                        const SizedBox(width: 5),
                        Text(
                          'copy'.tr,
                          style: TextStyle(fontSize: 12, color: primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CupertinoButton(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: CupertinoColors.activeGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => widget.onPaste(widget.message.content),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_right_square,
                          size: 13,
                          color: CupertinoColors.activeGreen,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Dán kết quả',
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.activeGreen,
                          ),
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
