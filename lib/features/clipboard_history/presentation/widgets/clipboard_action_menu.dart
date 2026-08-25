import 'dart:math' as math;

import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';

Future<String?> showClipboardActionMenu({
  required BuildContext context,
  required ClipboardItem item,
  String copyAction = 'copy',
  String? copyLabel,
}) {
  final isImage = item.contentType == ClipboardContentType.image;
  final openableUrl = openableClipboardUrl(item);
  final hasPlainText = item.content.trim().isNotEmpty;
  final l10n = context.l10n;

  final actions = <CompactMenuAction>[
    if (openableUrl != null)
      CompactMenuAction(
        value: 'open',
        icon: CupertinoIcons.arrow_up_right_square,
        label: l10n.open_link,
      ),
    if (hasPlainText)
      CompactMenuAction(
        value: 'paste_plain',
        icon: CupertinoIcons.text_alignleft,
        label: l10n.paste_as_plain_text,
        dividerBefore: openableUrl != null,
      ),
    CompactMenuAction(
      value: copyAction,
      icon: CupertinoIcons.doc_on_doc,
      label: copyLabel ?? l10n.copy,
      dividerBefore: !hasPlainText && openableUrl != null,
    ),
    CompactMenuAction(
      value: 'edit',
      icon: CupertinoIcons.pencil,
      label: l10n.edit_clipboard,
      dividerBefore: true,
    ),
    CompactMenuAction(
      value: 'note',
      icon: CupertinoIcons.doc_text,
      label: item.note?.isNotEmpty == true ? l10n.edit_note : l10n.add_note,
    ),
    if (isImage) ...[
      CompactMenuAction(
        value: 'ocr',
        icon: CupertinoIcons.doc_text_search,
        label: l10n.extract_ocr,
      ),
      CompactMenuAction(
        value: 'cloud_upload',
        icon: CupertinoIcons.cloud_upload,
        label: l10n.upload_cloud,
      ),
    ] else
      CompactMenuAction(
        value: 'translate',
        icon: CupertinoIcons.globe,
        label: l10n.translate_text,
      ),
    CompactMenuAction(
      value: 'ask_ai',
      icon: CupertinoIcons.sparkles,
      label: l10n.ask_ai,
    ),
    CompactMenuAction(
      value: 'pin',
      icon: CupertinoIcons.pin,
      label: item.isPinned ? l10n.unpin : l10n.pin,
      dividerBefore: true,
    ),
    CompactMenuAction(
      value: 'collection',
      icon: CupertinoIcons.folder_badge_plus,
      label: l10n.add_to_collection,
    ),
    CompactMenuAction(
      value: 'preview',
      icon: CupertinoIcons.eye,
      label: l10n.preview,
      dividerBefore: true,
    ),
    CompactMenuAction(
      value: 'share',
      icon: CupertinoIcons.share,
      label: l10n.share_clipboard,
    ),
    CompactMenuAction(
      value: 'delete',
      icon: CupertinoIcons.trash,
      label: l10n.delete,
      destructive: true,
    ),
  ];

  return showCompactActionMenu(
    context: context,
    actions: actions,
    menuKey: const Key('clipboard-action-menu'),
    itemKeyPrefix: 'clipboard-action',
  );
}

Future<String?> showCompactActionMenu({
  required BuildContext context,
  required List<CompactMenuAction> actions,
  Key? menuKey,
  String itemKeyPrefix = 'compact-action',
}) {
  final anchorBox = context.findRenderObject() as RenderBox?;
  final overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  final anchorOrigin = anchorBox != null && overlayBox != null
      ? anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox)
      : Offset.zero;
  final anchorSize = anchorBox?.size ?? Size.zero;
  final viewport = MediaQuery.sizeOf(context);
  final safePadding = MediaQuery.paddingOf(context);
  final menuWidth = math.min(238.0, math.max(1.0, viewport.width - 16));
  final dividerCount = actions.where((action) => action.dividerBefore).length;
  final estimatedHeight = actions.length * 36.0 + dividerCount * 9.0 + 14;
  final maxBottom = viewport.height - safePadding.bottom - 8;
  final availableHeight = math.min(
    390.0,
    math.min(estimatedHeight, math.max(1.0, maxBottom - safePadding.top - 8)),
  );
  final below = anchorOrigin.dy + anchorSize.height + 5;
  final minTop = safePadding.top + 8;
  final maxTop = math.max(minTop, maxBottom - availableHeight);
  final top = below + availableHeight <= maxBottom
      ? below
      : (anchorOrigin.dy - availableHeight - 5)
            .clamp(minTop, maxTop)
            .toDouble();
  final maxLeft = math.max(8.0, viewport.width - menuWidth - 8);
  final left = (anchorOrigin.dx + anchorSize.width - menuWidth)
      .clamp(8.0, maxLeft)
      .toDouble();

  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.cancel,
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 110),
    pageBuilder: (context, animation, secondaryAnimation) => Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: menuWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: availableHeight),
            child: _CompactActionMenu(
              actions: actions,
              menuKey: menuKey,
              itemKeyPrefix: itemKeyPrefix,
            ),
          ),
        ),
      ],
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

String? openableClipboardUrl(ClipboardItem item) {
  final raw = item.primaryUrl?.trim().isNotEmpty == true
      ? item.primaryUrl!.trim()
      : item.content.trim();
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.hasScheme ||
      !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty) {
    return null;
  }
  return uri.toString();
}

class CompactMenuAction {
  const CompactMenuAction({
    required this.value,
    required this.icon,
    required this.label,
    this.dividerBefore = false,
    this.destructive = false,
  });

  final String value;
  final IconData icon;
  final String label;
  final bool dividerBefore;
  final bool destructive;
}

class _CompactActionMenu extends StatelessWidget {
  const _CompactActionMenu({
    required this.actions,
    required this.menuKey,
    required this.itemKeyPrefix,
  });

  final List<CompactMenuAction> actions;
  final Key? menuKey;
  final String itemKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: menuKey,
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.elevatedSurface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolveColor(context, ClipFlowColors.border)),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final action in actions) ...[
                if (action.dividerBefore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: CupertinoDivider(indent: 38, endIndent: 8),
                  ),
                _CompactActionMenuItem(
                  action: action,
                  itemKeyPrefix: itemKeyPrefix,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactActionMenuItem extends StatefulWidget {
  const _CompactActionMenuItem({
    required this.action,
    required this.itemKeyPrefix,
  });

  final CompactMenuAction action;
  final String itemKeyPrefix;

  @override
  State<_CompactActionMenuItem> createState() => _CompactActionMenuItemState();
}

class _CompactActionMenuItemState extends State<_CompactActionMenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final foreground = action.destructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : resolveColor(context, ClipFlowColors.text);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(action.value),
        child: AnimatedContainer(
          key: Key('${widget.itemKeyPrefix}-${action.value}'),
          height: 36,
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          color: _hovered
              ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12)
              : const Color(0x00000000),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(action.icon, size: 16, color: foreground),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
