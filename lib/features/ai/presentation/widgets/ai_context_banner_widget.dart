import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../../clipboard_history/domain/clipboard_item.dart';
import '../../../clipboard_history/domain/clipboard_content_type.dart';

class AiContextBannerWidget extends StatelessWidget {
  const AiContextBannerWidget({
    super.key,
    required this.item,
    required this.onClear,
    required this.onCopy,
  });

  final ClipboardItem item;
  final VoidCallback onClear;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final isImage = item.contentType == ClipboardContentType.image;
    final imagePath = item.imagePath;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isImage ? 10 : 8),
      color: resolveColor(context, ClipFlowColors.sidebar),
      child: Row(
        children: [
          Icon(
            isImage ? CupertinoIcons.photo : CupertinoIcons.doc_on_clipboard,
            size: 14,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.ai_context_clip,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(width: 8),
          if (isImage) ...[
            Container(
              key: const Key('ai-selected-image-preview'),
              width: 64,
              height: 48,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: resolveColor(context, ClipFlowColors.surface),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: resolveColor(context, ClipFlowColors.border),
                ),
              ),
              child: imagePath != null && File(imagePath).existsSync()
                  ? Image.file(File(imagePath), fit: BoxFit.cover)
                  : Icon(
                      CupertinoIcons.photo,
                      color: resolveColor(
                        context,
                        ClipFlowColors.secondaryText,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              isImage
                  ? [
                      'IMAGE',
                      if (item.sourceAppName?.isNotEmpty == true)
                        item.sourceAppName!,
                      if (imagePath?.isNotEmpty == true)
                        imagePath!.split(Platform.pathSeparator).last,
                    ].join(' • ')
                  : item.content,
              maxLines: isImage ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoIconControl(
            icon: CupertinoIcons.doc_on_doc,
            size: 13,
            tooltip: context.l10n.copy_clipboard_content,
            onPressed: onCopy,
          ),
          const SizedBox(width: 4),
          CupertinoPressable(
            onPressed: onClear,
            child: Text(
              context.l10n.ai_clear_context,
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
              context.l10n.ai_all_clipboard_context.replaceAll(
                '@count',
                '$itemCount',
              ),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            context.l10n.ai_select_clip_hint,
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
