import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

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
            hasQuery
                ? context.l10n.no_matching_clips
                : context.l10n.clipboard_empty,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasQuery
                ? context.l10n.try_different_search
                : context.l10n.copy_text_hint,
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
