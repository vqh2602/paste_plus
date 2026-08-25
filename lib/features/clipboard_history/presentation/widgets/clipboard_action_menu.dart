import 'dart:math' as math;

import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';
import '../../domain/smart_text_tools.dart';

Future<String?> showClipboardActionMenu({
  required BuildContext context,
  required ClipboardItem item,
  String copyAction = 'copy',
  String? copyLabel,
  bool protectVaultContent = false,
}) {
  final isImage = item.contentType == ClipboardContentType.image;
  final openableUrl = openableClipboardUrl(item);
  final hasPlainText = item.content.trim().isNotEmpty;
  final canTransformText =
      hasPlainText &&
      item.contentType != ClipboardContentType.image &&
      item.contentType != ClipboardContentType.file;
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
    if (!protectVaultContent && canTransformText)
      CompactMenuAction(
        value: 'text_transform',
        icon: CupertinoIcons.arrow_2_squarepath,
        label: l10n.text_transform,
        trailingIcon: CupertinoIcons.chevron_right,
        dividerBefore: true,
      ),
    if (!protectVaultContent && item.contentType == ClipboardContentType.url)
      CompactMenuAction(
        value: 'link_cleaner',
        icon: CupertinoIcons.wand_stars,
        label: l10n.link_cleaner,
      ),
    CompactMenuAction(
      value: 'edit',
      icon: CupertinoIcons.pencil,
      label: l10n.edit_clipboard,
      dividerBefore: protectVaultContent || !canTransformText,
    ),
    CompactMenuAction(
      value: 'note',
      icon: CupertinoIcons.doc_text,
      label: item.note?.isNotEmpty == true ? l10n.edit_note : l10n.add_note,
    ),
    if (!protectVaultContent && isImage) ...[
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
    ] else if (!protectVaultContent)
      CompactMenuAction(
        value: 'translate',
        icon: CupertinoIcons.globe,
        label: l10n.translate_text,
      ),
    if (!protectVaultContent)
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

Future<TextTransform?> showTextTransformMenu({
  required BuildContext context,
}) async {
  final l10n = context.l10n;
  final action = await showCompactActionMenu(
    context: context,
    menuKey: const Key('text-transform-menu'),
    itemKeyPrefix: 'text-transform',
    actions: [
      CompactMenuAction(
        value: TextTransform.formatJson.name,
        icon: CupertinoIcons.text_badge_checkmark,
        label: l10n.format_json,
      ),
      CompactMenuAction(
        value: TextTransform.minifyJson.name,
        icon: CupertinoIcons.arrow_down_right_arrow_up_left,
        label: l10n.minify_json,
      ),
      CompactMenuAction(
        value: TextTransform.base64Encode.name,
        icon: CupertinoIcons.lock,
        label: l10n.encode_base64,
        dividerBefore: true,
      ),
      CompactMenuAction(
        value: TextTransform.base64Decode.name,
        icon: CupertinoIcons.lock_open,
        label: l10n.decode_base64,
      ),
      CompactMenuAction(
        value: TextTransform.urlEncode.name,
        icon: CupertinoIcons.link,
        label: l10n.encode_url,
      ),
      CompactMenuAction(
        value: TextTransform.urlDecode.name,
        icon: CupertinoIcons.link,
        label: l10n.decode_url,
      ),
      CompactMenuAction(
        value: TextTransform.uppercase.name,
        icon: CupertinoIcons.textformat_size,
        label: l10n.uppercase,
        dividerBefore: true,
      ),
      CompactMenuAction(
        value: TextTransform.lowercase.name,
        icon: CupertinoIcons.textformat,
        label: l10n.lowercase,
      ),
      CompactMenuAction(
        value: TextTransform.titleCase.name,
        icon: CupertinoIcons.textformat_abc,
        label: l10n.title_case,
      ),
      CompactMenuAction(
        value: TextTransform.parseTimestamp.name,
        icon: CupertinoIcons.time,
        label: l10n.parse_timestamp,
        dividerBefore: true,
      ),
      CompactMenuAction(
        value: TextTransform.md5Hash.name,
        icon: CupertinoIcons.number,
        label: l10n.md5_hash,
      ),
      CompactMenuAction(
        value: TextTransform.sortLines.name,
        icon: CupertinoIcons.sort_down,
        label: l10n.sort_lines,
      ),
      CompactMenuAction(
        value: TextTransform.uniqueLines.name,
        icon: CupertinoIcons.square_stack_3d_down_right,
        label: l10n.remove_duplicate_lines,
      ),
    ],
  );
  if (action == null) return null;
  return TextTransform.values.firstWhere((item) => item.name == action);
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
    this.trailingIcon,
  });

  final String value;
  final IconData icon;
  final String label;
  final bool dividerBefore;
  final bool destructive;
  final IconData? trailingIcon;
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
              if (action.trailingIcon != null)
                Icon(action.trailingIcon, size: 12, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
