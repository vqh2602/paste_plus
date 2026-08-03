import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';

class AiMobileToolbar extends StatelessWidget {
  const AiMobileToolbar({
    super.key,
    required this.onClose,
    required this.onChooseContext,
    required this.onShowHistory,
    this.hasContext = false,
  });

  final VoidCallback onClose;
  final VoidCallback onChooseContext;
  final VoidCallback onShowHistory;
  final bool hasContext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          CupertinoIconControl(
            key: const Key('ai-mobile-close'),
            icon: CupertinoIcons.xmark,
            tooltip: context.l10n.close,
            onPressed: onClose,
          ),
          const SizedBox(width: 2),
          const Icon(
            CupertinoIcons.sparkles,
            color: CupertinoColors.activeBlue,
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              context.l10n.ai_chat_assistant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          CupertinoIconControl(
            key: const Key('ai-mobile-context'),
            icon: hasContext
                ? CupertinoIcons.doc_on_clipboard_fill
                : CupertinoIcons.doc_on_clipboard,
            size: 18,
            tooltip: context.l10n.ai_choose_context,
            onPressed: onChooseContext,
          ),
          CupertinoIconControl(
            key: const Key('ai-mobile-history'),
            icon: CupertinoIcons.clock,
            size: 18,
            tooltip: context.l10n.ai_conversation_history,
            onPressed: onShowHistory,
          ),
        ],
      ),
    );
  }
}
