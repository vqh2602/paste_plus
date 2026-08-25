import 'dart:math' as math;

import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../../core/utils/color_parser.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';
import 'detail_pane_widget.dart';

Future<void> showClipboardPreviewDialog({
  required BuildContext context,
  required ClipboardItem item,
  required VoidCallback onCopy,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.cancel,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _ClipboardPreviewDialog(item: item, onCopy: onCopy),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ClipboardPreviewDialog extends StatelessWidget {
  const _ClipboardPreviewDialog({required this.item, required this.onCopy});

  final ClipboardItem item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final content = item.content;
    final characterCount = content.runes.length;
    final wordCount = content.trim().isEmpty
        ? 0
        : content.trim().split(RegExp(r'\s+')).length;
    final lineCount = content.isEmpty ? 0 : '\n'.allMatches(content).length + 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Container(
              key: const Key('clipboard-preview-dialog'),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: resolveColor(context, ClipFlowColors.border),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _PreviewHeader(item: item, onCopy: onCopy),
                  const CupertinoDivider(),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: resolveColor(context, ClipFlowColors.surface),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: resolveColor(context, ClipFlowColors.border),
                        ),
                      ),
                      child: _PreviewContent(item: item),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
                    child: Row(
                      children: [
                        _PreviewStat(
                          value: characterCount,
                          label: context.l10n.characters,
                        ),
                        const _PreviewStatDivider(),
                        _PreviewStat(
                          value: wordCount,
                          label: context.l10n.words,
                        ),
                        const _PreviewStatDivider(),
                        _PreviewStat(
                          value: lineCount,
                          label: context.l10n.lines,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.item, required this.onCopy});

  final ClipboardItem item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            CupertinoIconControl(
              key: const Key('clipboard-preview-close'),
              icon: CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: resolveColor(context, ClipFlowColors.secondaryText),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            Icon(_typeIcon(item.contentType), size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _typeLabel(context, item),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            CupertinoIconControl(
              key: const Key('clipboard-preview-copy'),
              icon: CupertinoIcons.doc_on_doc,
              size: 18,
              tooltip: context.l10n.copy,
              onPressed: () {
                onCopy();
                showCupertinoNotice(context, context.l10n.copied);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.item});

  final ClipboardItem item;

  @override
  Widget build(BuildContext context) {
    final isImage = item.contentType == ClipboardContentType.image;
    final isOnlineImage = isImageUrl(item.content);
    final parsedColor = item.contentType == ClipboardContentType.color
        ? ColorParser.parse(item.content)
        : null;

    if (isImage || isOnlineImage) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipboardImagePreviewWidget(
                path: item.imagePath ?? item.content,
                height: math.max(
                  180,
                  math.min(360, constraints.maxHeight - 50),
                ),
                item: item,
              ),
              if (item.content.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  item.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: resolveColor(context, ClipFlowColors.secondaryText),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (parsedColor != null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: parsedColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: resolveColor(context, ClipFlowColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              item.content,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
            ),
          ],
        ),
      );
    }

    return CupertinoScrollbar(
      child: SingleChildScrollView(
        primary: true,
        child: SelectableText(
          item.content.isEmpty ? context.l10n.clipboard_empty : item.content,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: item.contentType == ClipboardContentType.url
                ? CupertinoColors.activeBlue
                : resolveColor(context, ClipFlowColors.text),
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
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        '$value $label',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: resolveColor(context, ClipFlowColors.secondaryText),
        ),
      ),
    );
  }
}

class _PreviewStatDivider extends StatelessWidget {
  const _PreviewStatDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '·',
        style: TextStyle(
          color: resolveColor(context, ClipFlowColors.secondaryText),
        ),
      ),
    );
  }
}

IconData _typeIcon(ClipboardContentType type) => switch (type) {
  ClipboardContentType.text => CupertinoIcons.doc_text,
  ClipboardContentType.url => CupertinoIcons.link,
  ClipboardContentType.email => CupertinoIcons.mail,
  ClipboardContentType.phone => CupertinoIcons.phone,
  ClipboardContentType.code => CupertinoIcons.chevron_left_slash_chevron_right,
  ClipboardContentType.color => CupertinoIcons.color_filter,
  ClipboardContentType.json => CupertinoIcons.chevron_left_slash_chevron_right,
  ClipboardContentType.file => CupertinoIcons.folder,
  ClipboardContentType.image => CupertinoIcons.photo,
};

String _typeLabel(BuildContext context, ClipboardItem item) {
  if (isImageUrl(item.content)) return context.l10n.image_link;
  return switch (item.contentType) {
    ClipboardContentType.text => context.l10n.text,
    ClipboardContentType.url => context.l10n.url,
    ClipboardContentType.email => context.l10n.email,
    ClipboardContentType.phone => context.l10n.phone,
    ClipboardContentType.code => context.l10n.code,
    ClipboardContentType.color => context.l10n.color,
    ClipboardContentType.json => context.l10n.json,
    ClipboardContentType.file => context.l10n.file,
    ClipboardContentType.image => context.l10n.image,
  };
}
