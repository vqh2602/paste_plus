import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../../core/utils/color_parser.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';
import 'clipboard_preview_dialog.dart';

class QuickClipboardCardWidget extends ConsumerWidget {
  const QuickClipboardCardWidget({
    super.key,
    required this.item,
    required this.number,
    required this.selected,
    required this.onTap,
    required this.onPin,
    required this.onActions,
  });

  final ClipboardItem item;
  final int number;
  final bool selected;
  final VoidCallback onTap;
  final Future<void> Function() onPin;
  final ValueChanged<BuildContext> onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColor(item.contentType);
    final query = ref.watch(historyControllerProvider).query;
    final parsedColor = item.contentType == ClipboardContentType.color
        ? ColorParser.parse(item.content)
        : null;

    return SizedBox(
      width: 292,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? CupertinoTheme.of(context).primaryColor
                : resolveColor(context, ClipFlowColors.border),
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: CupertinoTheme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPressable(
                      onPressed: onTap,
                      child: Row(
                        children: [
                          Icon(
                            _typeIcon(item.contentType),
                            color: CupertinoColors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _typeName(context, item.contentType),
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  CupertinoIconControl(
                    icon:
                        (ref.watch(pinnedStateOverrideProvider)[item.id] ??
                            item.isPinned)
                        ? CupertinoIcons.pin_fill
                        : CupertinoIcons.pin,
                    color: CupertinoColors.white,
                    size: 16,
                    onPressed: () async {
                      final isCurrentlyPinned =
                          ref.read(pinnedStateOverrideProvider)[item.id] ??
                          item.isPinned;
                      ref
                          .read(pinnedStateOverrideProvider.notifier)
                          .setPinned(item.id, !isCurrentlyPinned);
                      await onPin();
                      // Clear optimistic override so DB value drives the UI
                      ref
                          .read(pinnedStateOverrideProvider.notifier)
                          .clearPinned(item.id);
                    },
                  ),
                  Builder(
                    builder: (menuContext) => CupertinoIconControl(
                      key: const Key('quick-item-more-button'),
                      icon: CupertinoIcons.ellipsis,
                      color: CupertinoColors.white,
                      size: 17,
                      onPressed: () => onActions(menuContext),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPressable(
                onPressed: onTap,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: item.contentType == ClipboardContentType.image
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: resolveColor(
                                          context,
                                          ClipFlowColors.surface,
                                        ),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: resolveColor(
                                            context,
                                            ClipFlowColors.border,
                                          ),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child:
                                            (item.imagePath != null &&
                                                File(
                                                  item.imagePath!,
                                                ).existsSync())
                                            ? Image.file(
                                                File(item.imagePath!),
                                                width: double.infinity,
                                                fit: BoxFit.contain,
                                              )
                                            : CachedNetworkImage(
                                                url: item.content,
                                                width: double.infinity,
                                                fit: BoxFit.contain,
                                              ),
                                      ),
                                    ),
                                  ),
                                  if (item.content.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    HighlightedText(
                                      text: item.content,
                                      query: query,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: ClipFlowColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : isImageUrl(item.content)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: resolveColor(
                                          context,
                                          ClipFlowColors.surface,
                                        ),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: resolveColor(
                                            context,
                                            ClipFlowColors.border,
                                          ),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          url: item.content,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  HighlightedText(
                                    text: item.content,
                                    query: query,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ClipFlowColors.secondaryText,
                                    ),
                                  ),
                                ],
                              )
                            : parsedColor != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: parsedColor,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: resolveColor(
                                            context,
                                            ClipFlowColors.border,
                                          ),
                                          width: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  HighlightedText(
                                    text: item.content,
                                    query: query,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: ClipFlowColors.secondaryText,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              )
                            : HighlightedText(
                                text: item.content,
                                query: query,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color:
                                      item.contentType ==
                                          ClipboardContentType.url
                                      ? CupertinoColors.activeBlue
                                      : null,
                                  decoration:
                                      item.contentType ==
                                          ClipboardContentType.url
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  decorationColor:
                                      item.contentType ==
                                          ClipboardContentType.url
                                      ? CupertinoColors.activeBlue.withValues(
                                          alpha: 0.4,
                                        )
                                      : null,
                                  fontFamily:
                                      item.contentType ==
                                              ClipboardContentType.code ||
                                          item.contentType ==
                                              ClipboardContentType.json
                                      ? 'monospace'
                                      : null,
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
                      child: Row(
                        children: [
                          Expanded(child: _SourceAndMetadata(item: item)),
                          if (number <= 9)
                            Text(
                              '${Platform.isMacOS ? '⌘' : 'Ctrl+'}$number',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  String _typeName(BuildContext context, ClipboardContentType type) =>
      switch (type) {
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

class _SourceAndMetadata extends StatelessWidget {
  const _SourceAndMetadata({required this.item});

  final ClipboardItem item;

  static const _style = TextStyle(
    fontSize: 11,
    color: ClipFlowColors.secondaryText,
  );

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            item.sourceAppName ?? context.l10n.this_device,
            key: Key('quick-card-source-${item.id}'),
            overflow: TextOverflow.ellipsis,
            style: _style,
          ),
        ),
        if (metadata != null) ...[const Text(' · ', style: _style), metadata],
      ],
    );
  }

  Widget? _metadata(BuildContext context) {
    if (item.contentType == ClipboardContentType.text) {
      return Text(
        '${item.content.runes.length} ${context.l10n.chars_unit}',
        key: Key('quick-card-text-metadata-${item.id}'),
        style: _style,
      );
    }

    if (item.contentType == ClipboardContentType.image ||
        isImageUrl(item.content)) {
      return ImageDimensionsText(
        path: item.imagePath ?? item.content,
        textKey: Key('quick-card-image-metadata-${item.id}'),
        style: _style,
      );
    }

    if (item.contentType == ClipboardContentType.color) {
      final format = ColorParser.formatName(item.content);
      if (format != null) {
        return Text(
          format,
          key: Key('quick-card-color-metadata-${item.id}'),
          style: _style,
        );
      }
    }
    return null;
  }
}
