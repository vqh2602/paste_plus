import 'package:flutter/cupertino.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';

class QuickEmptyStateWidget extends StatelessWidget {
  const QuickEmptyStateWidget({super.key, required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? CupertinoIcons.search : CupertinoIcons.doc_on_clipboard,
            size: 36,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery ? 'no_matching_clips'.tr : 'clipboard_empty'.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasQuery ? 'try_different_search'.tr : 'copy_text_hint'.tr,
            style: TextStyle(
              fontSize: 12,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
