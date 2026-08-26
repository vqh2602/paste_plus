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
import '../../domain/smart_text_tools.dart';
import 'calculation_result_line.dart';

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
    final parsedColor = item.contentType == ClipboardContentType.color
        ? ColorParser.parse(item.content)
        : null;
    final codeLanguage = item.contentType == ClipboardContentType.code
        ? SmartTextTools.programmingLanguage(item.content)
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
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
        // Stretch the body pressable across the card so short clipboard
        // content does not leave a non-clickable empty area on the right.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPressable(
                    onPressed: onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                        Flexible(
                          child: Text(
                            [
                              item.sourceAppName ?? context.l10n.unknown,
                              ?codeLanguage,
                            ].join(' · '),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: resolveColor(
                                context,
                                ClipFlowColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CupertinoIconControl(
                  key: const Key('pin-button'),
                  icon:
                      (ref.watch(pinnedStateOverrideProvider)[item.id] ??
                          item.isPinned)
                      ? CupertinoIcons.pin_fill
                      : CupertinoIcons.pin,
                  size: 15,
                  onPressed: () async {
                    final isCurrentlyPinned =
                        ref.read(pinnedStateOverrideProvider)[item.id] ??
                        item.isPinned;
                    final nextPinned = !isCurrentlyPinned;
                    ref
                        .read(pinnedStateOverrideProvider.notifier)
                        .setPinned(item.id, nextPinned);
                    await historyNotifier.togglePinned(item);
                    // Clear optimistic override so DB value drives the UI
                    ref
                        .read(pinnedStateOverrideProvider.notifier)
                        .clearPinned(item.id);
                    if (context.mounted) {
                      showCupertinoNotice(
                        context,
                        nextPinned ? context.l10n.pinned : context.l10n.unpin,
                      );
                    }
                  },
                ),
                CupertinoIconControl(
                  icon: CupertinoIcons.doc_on_doc,
                  size: 15,
                  onPressed: () => onCopy(item),
                ),
                Builder(
                  builder: (menuContext) => CupertinoIconControl(
                    key: const Key('item-more-button'),
                    icon: CupertinoIcons.ellipsis,
                    size: 15,
                    onPressed: () => onShowItemActions(
                      menuContext,
                      ref,
                      item,
                      onDelete,
                      onAddToCollection,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CupertinoPressable(
            onPressed: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isImage) ...[
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: resolveColor(context, ClipFlowColors.surface),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: resolveColor(context, ClipFlowColors.border),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child:
                            (item.imagePath != null &&
                                File(item.imagePath!).existsSync())
                            ? Image.file(
                                File(item.imagePath!),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              )
                            : CachedNetworkImage(
                                url: item.content,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.contain,
                              ),
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
                          color: resolveColor(
                            context,
                            ClipFlowColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ] else if (isOnlineImage) ...[
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: resolveColor(context, ClipFlowColors.surface),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: resolveColor(context, ClipFlowColors.border),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: CachedNetworkImage(
                          url: item.content,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
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
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                      ),
                    ),
                  ] else if (parsedColor != null) ...[
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: parsedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: resolveColor(context, ClipFlowColors.border),
                          width: 1.0,
                        ),
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
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                        fontFamily: 'monospace',
                      ),
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
                    CalculationResultLine(
                      content: item.content,
                      enabled: item.contentType == ClipboardContentType.text,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
    ClipboardContentType.jwt => const Color(0xFFFF6B35),
    ClipboardContentType.emoji => const Color(0xFFFFCC00),
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
    ClipboardContentType.jwt => CupertinoIcons.lock,
    ClipboardContentType.emoji => CupertinoIcons.smiley,
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
    ClipboardContentType.jwt => 'JWT',
    ClipboardContentType.emoji => 'EMOJI',
    ClipboardContentType.file => 'FILE',
    ClipboardContentType.image => 'IMAGE',
  };
}
