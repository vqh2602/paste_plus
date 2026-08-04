import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_content_type.dart';

Future<Set<ClipboardContentType>?> showContentTypeFilterSheet(
  BuildContext context, {
  required Set<ClipboardContentType> selectedTypes,
}) {
  var selected = {...selectedTypes};
  return showCupertinoModalPopup<Set<ClipboardContentType>>(
    context: context,
    builder: (popupContext) => StatefulBuilder(
      builder: (context, setPopupState) {
        final width = (MediaQuery.sizeOf(context).width - 24)
            .clamp(300, 560)
            .toDouble();
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoPopupSurface(
                child: SizedBox(
                  width: width,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              context.l10n.filter_by_type,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${selected.length}/${ClipboardContentType.values.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: resolveColor(
                                  context,
                                  ClipFlowColors.secondaryText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              onPressed: selected.isEmpty
                                  ? null
                                  : () => setPopupState(selected.clear),
                              child: Text(
                                context.l10n.clear,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 470 ? 3 : 2;
                            final itemWidth =
                                (constraints.maxWidth - (columns - 1) * 8) /
                                columns;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final type in ClipboardContentType.values)
                                  SizedBox(
                                    width: itemWidth,
                                    child: CupertinoChoicePill(
                                      key: ValueKey('type-filter-${type.name}'),
                                      label: contentTypeLabel(context, type),
                                      icon: contentTypeIcon(type),
                                      selected: selected.contains(type),
                                      badge: selected.contains(type)
                                          ? const Icon(
                                              CupertinoIcons
                                                  .checkmark_circle_fill,
                                              size: 13,
                                              color: CupertinoColors.white,
                                            )
                                          : null,
                                      onPressed: () {
                                        setPopupState(() {
                                          if (!selected.add(type)) {
                                            selected.remove(type);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                onPressed: () => Navigator.pop(popupContext),
                                child: Text(context.l10n.cancel),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                onPressed: () => Navigator.pop(
                                  popupContext,
                                  Set.unmodifiable(selected),
                                ),
                                child: Text(context.l10n.apply_filters),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

String contentTypeLabel(BuildContext context, ClipboardContentType type) =>
    switch (type) {
      ClipboardContentType.text => context.l10n.text,
      ClipboardContentType.url => context.l10n.links,
      ClipboardContentType.email => context.l10n.email,
      ClipboardContentType.phone => context.l10n.phone,
      ClipboardContentType.code => context.l10n.code,
      ClipboardContentType.color => context.l10n.color,
      ClipboardContentType.json => 'JSON',
      ClipboardContentType.file => context.l10n.files,
      ClipboardContentType.image => context.l10n.images,
    };

IconData contentTypeIcon(ClipboardContentType type) => switch (type) {
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
