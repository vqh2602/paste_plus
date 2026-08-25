import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';
import '../history_controller.dart';
import 'content_type_filter_sheet.dart';
import '../../../vault/presentation/vault_dialogs.dart';
import 'search_syntax_field.dart';

class QuickToolbarWidget extends ConsumerWidget {
  const QuickToolbarWidget({
    super.key,
    required this.state,
    required this.collections,
    required this.monitoringEnabled,
    required this.searchController,
    required this.searchFocusNode,
    required this.onOpenMainWindow,
    required this.onChooseType,
  });

  final ClipboardHistoryState state;
  final List<ClipboardCollection> collections;
  final bool monitoringEnabled;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onOpenMainWindow;
  final ValueChanged<BuildContext> onChooseType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyNotifier = ref.read(historyControllerProvider.notifier);

    final systemTabs = [
      (
        label: context.l10n.all_clips,
        icon: CupertinoIcons.square_grid_2x2,
        section: HistorySection.all,
      ),
      (
        label: context.l10n.starred_clips,
        icon: CupertinoIcons.star_fill,
        section: HistorySection.pinned,
      ),
    ];

    final typeTabs = [
      (
        label: context.l10n.link,
        icon: CupertinoIcons.link,
        type: ClipboardContentType.url,
      ),
      (
        label: context.l10n.image,
        icon: CupertinoIcons.photo,
        type: ClipboardContentType.image,
      ),
      (
        label: context.l10n.code,
        icon: CupertinoIcons.chevron_left_slash_chevron_right,
        type: ClipboardContentType.code,
      ),
    ];
    const fixedTypes = {
      ClipboardContentType.url,
      ClipboardContentType.image,
      ClipboardContentType.code,
    };

    return SizedBox(
      height: 62,
      child: Row(
        children: [
          const SizedBox(width: 10),
          if (ref.watch(settingsControllerProvider).aiEnabled) ...[
            CupertinoIconControl(
              icon: CupertinoIcons.sparkles,
              color: CupertinoColors.activeBlue,
              onPressed: () async {
                ref
                    .read(aiControllerProvider.notifier)
                    .setClipboardContext(null);
                await ref.read(desktopIntegrationProvider).showAiWindow();
              },
            ),
            const SizedBox(width: 4),
          ],
          CupertinoIconControl(
            icon: monitoringEnabled
                ? CupertinoIcons.pause_circle
                : CupertinoIcons.play_circle,
            onPressed: () async {
              final enabled = !monitoringEnabled;
              await ref
                  .read(settingsControllerProvider.notifier)
                  .update(
                    (current) => current.copyWith(monitoringEnabled: enabled),
                  );
              await historyNotifier.setMonitoring(enabled);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in systemTabs) ...[
                    CupertinoChoicePill(
                      key: ValueKey('quick-section-${tab.section.name}'),
                      label: tab.label,
                      icon: tab.icon,
                      selected: state.section == tab.section,
                      onPressed: () =>
                          historyNotifier.selectSection(tab.section),
                    ),
                    const SizedBox(width: 6),
                  ],
                  for (final collection in collections) ...[
                    CupertinoChoicePill(
                      label: collection.isVault
                          ? context.l10n.vault_title
                          : collection.name,
                      icon: collection.isVault
                          ? CupertinoIcons.lock_fill
                          : CupertinoIcons.folder,
                      selected:
                          state.section == HistorySection.collection &&
                          state.collectionId == collection.id,
                      onPressed: () async {
                        if (collection.isVault &&
                            !await ensureVaultUnlocked(context, ref)) {
                          return;
                        }
                        await historyNotifier.selectSection(
                          HistorySection.collection,
                          collectionId: collection.id,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  for (final tab in typeTabs) ...[
                    CupertinoChoicePill(
                      key: ValueKey('quick-type-${tab.type.name}'),
                      label: tab.label,
                      icon: tab.icon,
                      selected:
                          state.typeFilters.contains(tab.type) ||
                          _sectionType(state.section) == tab.type,
                      onPressed: () =>
                          historyNotifier.toggleQuickTypeFilter(tab.type),
                    ),
                    const SizedBox(width: 4),
                  ],
                  for (final type in state.typeFilters.difference(
                    fixedTypes,
                  )) ...[
                    CupertinoChoicePill(
                      key: ValueKey('quick-active-type-${type.name}'),
                      label: contentTypeLabel(context, type),
                      icon: contentTypeIcon(type),
                      selected: true,
                      badge: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 12,
                        color: CupertinoColors.white,
                      ),
                      onPressed: () => historyNotifier.toggleTypeFilter(type),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 260,
            child: SearchSyntaxField(
              fieldKey: const Key('quick-panel-search'),
              controller: searchController,
              focusNode: searchFocusNode,
              placeholder: context.l10n.search_in_clipboard,
              onChanged: historyNotifier.search,
            ),
          ),
          const SizedBox(width: 6),
          CupertinoIconControl(
            key: const Key('quick-filter-button'),
            icon: CupertinoIcons.slider_horizontal_3,
            color: state.typeFilters.isNotEmpty
                ? CupertinoTheme.of(context).primaryColor
                : null,
            onPressed: () => onChooseType(context),
          ),
          CupertinoIconControl(
            icon: CupertinoIcons.arrow_up_left_arrow_down_right,
            onPressed: onOpenMainWindow,
          ),
          CupertinoIconControl(
            icon: CupertinoIcons.xmark,
            onPressed: () =>
                ref.read(desktopIntegrationProvider).hideQuickPanel(),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  ClipboardContentType? _sectionType(HistorySection section) =>
      switch (section) {
        HistorySection.images => ClipboardContentType.image,
        HistorySection.links => ClipboardContentType.url,
        HistorySection.code => ClipboardContentType.code,
        _ => null,
      };
}
