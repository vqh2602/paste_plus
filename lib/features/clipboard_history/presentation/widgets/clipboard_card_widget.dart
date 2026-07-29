import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../../core/utils/color_parser.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';

class ClipboardCardWidget extends ConsumerWidget {
  const ClipboardCardWidget({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onCopy,
    required this.onDelete,
    required this.onAddToCollection,
    required this.onShowItemActions,
  });

  final ClipboardItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<ClipboardItem> onCopy;
  final ValueChanged<ClipboardItem> onDelete;
  final ValueChanged<ClipboardItem> onAddToCollection;
  final void Function(
    BuildContext context,
    WidgetRef ref,
    ClipboardItem item,
    ValueChanged<ClipboardItem> onDelete,
    ValueChanged<ClipboardItem> onAddToCollection,
  )
  onShowItemActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColor(item.contentType);
    final isImage = item.contentType == ClipboardContentType.image;
    final isOnlineImage = isImageUrl(item.content);
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final state = ref.watch(historyControllerProvider);
    final parsedColor = item.contentType == ClipboardContentType.color ? ColorParser.parse(item.content) : null;

    return CupertinoPressable(
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12)
              : resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? CupertinoTheme.of(context).primaryColor
                : resolveColor(context, ClipFlowColors.border),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _typeIcon(item.contentType),
                        size: 11,
                        color: CupertinoColors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _typeLabel(item.contentType),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.sourceAppName ?? 'unknown'.tr,
                  style: TextStyle(
                    fontSize: 11,
                    color: resolveColor(context, ClipFlowColors.secondaryText),
                  ),
                ),
                const Spacer(),
                CupertinoIconControl(
                  key: const Key('pin-button'),
                  icon: item.isPinned
                      ? CupertinoIcons.pin_fill
                      : CupertinoIcons.pin,
                  size: 15,
                  onPressed: () => historyNotifier.togglePinned(item),
                ),
                CupertinoIconControl(
                  icon: CupertinoIcons.doc_on_doc,
                  size: 15,
                  onPressed: () => onCopy(item),
                ),
                CupertinoIconControl(
                  key: const Key('item-more-button'),
                  icon: CupertinoIcons.ellipsis,
                  size: 15,
                  onPressed: () => onShowItemActions(
                    context,
                    ref,
                    item,
                    onDelete,
                    onAddToCollection,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    (item.imagePath != null &&
                        File(item.imagePath!).existsSync())
                    ? Image.file(
                        File(item.imagePath!),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : CachedNetworkImage(
                        url: item.content,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              if (item.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                HighlightedText(
                  text: item.content,
                  query: state.query,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: resolveColor(context, ClipFlowColors.secondaryText),
                  ),
                ),
              ],
            ] else if (isOnlineImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  url: item.content,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
              HighlightedText(
                text: item.content,
                query: state.query,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: resolveColor(context, ClipFlowColors.secondaryText),
                ),
              ),
            ] else if (parsedColor != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: parsedColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: resolveColor(context, ClipFlowColors.border),
                        width: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HighlightedText(
                      text: item.content,
                      query: state.query,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              HighlightedText(
                text: item.content,
                query: state.query,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: item.contentType == ClipboardContentType.url
                      ? CupertinoColors.activeBlue
                      : null,
                  decoration: item.contentType == ClipboardContentType.url
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  fontFamily:
                      item.contentType == ClipboardContentType.code ||
                          item.contentType == ClipboardContentType.json
                      ? 'monospace'
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _typeColor(ClipboardContentType type) => switch (type) {
    ClipboardContentType.text => const Color(0xFF007AFF),
    ClipboardContentType.url => const Color(0xFF34C759),
    ClipboardContentType.email => const Color(0xFF5856D6),
    ClipboardContentType.phone => const Color(0xFFFF9500),
    ClipboardContentType.code => const Color(0xFFAF52DE),
    ClipboardContentType.color => const Color(0xFFFF2D55),
    ClipboardContentType.json => const Color(0xFF00C7BE),
    ClipboardContentType.file => const Color(0xFFA28B55),
    ClipboardContentType.image => const Color(0xFFFF3B30),
  };

  IconData _typeIcon(ClipboardContentType type) => switch (type) {
    ClipboardContentType.text => CupertinoIcons.doc_text,
    ClipboardContentType.url => CupertinoIcons.link,
    ClipboardContentType.email => CupertinoIcons.mail,
    ClipboardContentType.phone => CupertinoIcons.phone,
    ClipboardContentType.code =>
      CupertinoIcons.chevron_left_slash_chevron_right,
    ClipboardContentType.color => CupertinoIcons.color_filter,
    ClipboardContentType.json =>
      CupertinoIcons.chevron_left_slash_chevron_right,
    ClipboardContentType.file => CupertinoIcons.folder,
    ClipboardContentType.image => CupertinoIcons.photo,
  };

  String _typeLabel(ClipboardContentType type) => switch (type) {
    ClipboardContentType.text => 'TEXT',
    ClipboardContentType.url => 'LINK',
    ClipboardContentType.email => 'EMAIL',
    ClipboardContentType.phone => 'PHONE',
    ClipboardContentType.code => 'CODE',
    ClipboardContentType.color => 'COLOR',
    ClipboardContentType.json => 'JSON',
    ClipboardContentType.file => 'FILE',
    ClipboardContentType.image => 'IMAGE',
  };
}
