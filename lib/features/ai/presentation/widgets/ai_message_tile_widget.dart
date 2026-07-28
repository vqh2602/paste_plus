import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/ai_chat_message.dart';

class AiMessageTileWidget extends StatefulWidget {
  const AiMessageTileWidget({
    super.key,
    required this.message,
    required this.onCopy,
    required this.onPaste,
  });

  final AiChatMessage message;
  final ValueChanged<String> onCopy;
  final ValueChanged<String> onPaste;

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
                      onPressed: () =>
                          setState(() => _thinkingExpanded = !_thinkingExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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
                        Icon(CupertinoIcons.doc_on_doc,
                            size: 12, color: primary),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    color: CupertinoColors.activeGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => widget.onPaste(widget.message.content),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.arrow_right_square,
                          size: 12,
                          color: CupertinoColors.activeGreen,
                        ),
                        SizedBox(width: 4),
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
