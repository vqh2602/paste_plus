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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
