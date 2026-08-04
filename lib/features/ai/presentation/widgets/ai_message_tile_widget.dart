import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/ai_chat_message.dart';
import 'ai_markdown_content_widget.dart';

class AiMessageTileWidget extends StatefulWidget {
  const AiMessageTileWidget({
    super.key,
    required this.message,
    required this.onCopy,
    required this.onPaste,
    this.onEdit,
    this.onRegenerate,
    this.onContinue,
  });

  final AiChatMessage message;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onPaste;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onContinue;

  @override
  State<AiMessageTileWidget> createState() => _AiMessageTileWidgetState();
}

class _AiMessageTileWidgetState extends State<AiMessageTileWidget> {
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.message.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                if (widget.onEdit != null) ...[
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    onPressed: () => widget.onEdit!(widget.message.content),
                    child: const Icon(
                      CupertinoIcons.pencil,
                      size: 13,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ],
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
                const Icon(
                  CupertinoIcons.sparkles,
                  size: 15,
                  color: CupertinoColors.activeBlue,
                ),
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
                      onPressed: () => setState(
                        () => _thinkingExpanded = !_thinkingExpanded,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Text('🧠 ', style: TextStyle(fontSize: 13)),
                            Text(
                              context.l10n.ai_processing,
                              style: const TextStyle(
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

            const SizedBox(height: 10),
            if (widget.message.content.isEmpty)
              Text(widget.message.isThinking ? context.l10n.ai_processing : '')
            else
              AiMarkdownContentWidget(
                content: widget.message.content,
                onCopy: widget.onCopy,
              ),

            if (widget.message.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => widget.onCopy(widget.message.content),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.doc_on_doc,
                          size: 12,
                          color: primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.copy_all,
                          style: TextStyle(fontSize: 12, color: primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    color: CupertinoColors.activeGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => widget.onPaste(widget.message.content),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_right_square,
                          size: 12,
                          color: CupertinoColors.activeGreen,
                        ),
                        SizedBox(width: 4),
                        Text(
                          context.l10n.paste_all,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.activeGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onRegenerate != null) ...[
                    const SizedBox(width: 8),
                    CupertinoIconControl(
                      icon: CupertinoIcons.refresh,
                      size: 13,
                      tooltip: context.l10n.ai_regenerate,
                      onPressed: widget.onRegenerate!,
                    ),
                  ],
                  if (widget.onContinue != null) ...[
                    const SizedBox(width: 4),
                    CupertinoIconControl(
                      icon: CupertinoIcons.ellipsis_circle,
                      size: 13,
                      tooltip: context.l10n.ai_continue,
                      onPressed: widget.onContinue!,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
