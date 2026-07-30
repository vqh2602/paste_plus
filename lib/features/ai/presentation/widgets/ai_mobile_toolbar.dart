import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
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
            tooltip: 'close'.tr,
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
              'ai_chat_assistant'.tr,
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
            tooltip: 'ai_choose_context'.tr,
            onPressed: onChooseContext,
          ),
          CupertinoIconControl(
            key: const Key('ai-mobile-history'),
            icon: CupertinoIcons.clock,
            size: 18,
            tooltip: 'ai_conversation_history'.tr,
            onPressed: onShowHistory,
          ),
        ],
      ),
    );
  }
}
