import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';

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
  final VoidCallback onPin;
  final ValueChanged<BuildContext> onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColor(item.contentType);
    final query = ref.watch(historyControllerProvider).query;

    return SizedBox(
      width: 292,
      child: CupertinoPressable(
        onPressed: onTap,
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
                    Icon(
                      _typeIcon(item.contentType),
                      color: CupertinoColors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _typeName(item.contentType),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CupertinoIconControl(
                      icon: item.isPinned
                          ? CupertinoIcons.pin_fill
                          : CupertinoIcons.pin,
                      color: CupertinoColors.white,
                      size: 16,
                      onPressed: onPin,
                    ),
                    CupertinoIconControl(
                      icon: CupertinoIcons.ellipsis,
                      color: CupertinoColors.white,
                      size: 17,
                      onPressed: () => onActions(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: item.contentType == ClipboardContentType.image
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child:
                                    (item.imagePath != null &&
                                        File(item.imagePath!).existsSync())
                                    ? Image.file(
                                        File(item.imagePath!),
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        url: item.content,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: CachedNetworkImage(
                                  url: item.content,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
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
                      : HighlightedText(
                          text: item.content,
                          query: query,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: item.contentType == ClipboardContentType.url
                                ? CupertinoColors.activeBlue
                                : null,
                            decoration:
                                item.contentType == ClipboardContentType.url
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor:
                                item.contentType == ClipboardContentType.url
                                ? CupertinoColors.activeBlue.withValues(
                                    alpha: 0.4,
                                  )
                                : null,
                            fontFamily:
                                item.contentType == ClipboardContentType.code ||
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
                    Expanded(
                      child: Text(
                        item.sourceAppName ?? 'this_device'.tr,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ClipFlowColors.secondaryText,
                        ),
                      ),
                    ),
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

  String _typeName(ClipboardContentType type) => switch (type) {
    ClipboardContentType.text => 'text'.tr,
    ClipboardContentType.url => 'url'.tr,
    ClipboardContentType.email => 'email'.tr,
    ClipboardContentType.phone => 'phone'.tr,
    ClipboardContentType.code => 'code'.tr,
    ClipboardContentType.color => 'color'.tr,
    ClipboardContentType.json => 'json'.tr,
    ClipboardContentType.file => 'file'.tr,
    ClipboardContentType.image => 'image'.tr,
  };
}
