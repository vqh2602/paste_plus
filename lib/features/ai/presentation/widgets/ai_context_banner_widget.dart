import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../clipboard_history/domain/clipboard_item.dart';

class AiContextBannerWidget extends StatelessWidget {
  const AiContextBannerWidget({
    super.key,
    required this.item,
    required this.onClear,
  });

  final ClipboardItem item;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              item.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoPressable(
            onPressed: onClear,
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
    );
  }
}

class AiHistoryContextBannerWidget extends StatelessWidget {
  const AiHistoryContextBannerWidget({super.key, required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: CupertinoColors.activeBlue.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.tray_full,
            size: 15,
            color: CupertinoColors.activeBlue,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'ai_all_clipboard_context'.tr.replaceAll('@count', '$itemCount'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'ai_select_clip_hint'.tr,
            style: TextStyle(
              fontSize: 11,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
