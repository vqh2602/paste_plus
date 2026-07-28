import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';
import '../history_controller.dart';

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
        label: 'all_clips'.tr,
        icon: CupertinoIcons.square_grid_2x2,
        section: HistorySection.all,
      ),
      (
        label: 'starred_clips'.tr,
        icon: CupertinoIcons.star_fill,
        section: HistorySection.pinned,
      ),
    ];

    final typeTabs = [
      (
        label: 'text'.tr,
        icon: CupertinoIcons.doc_text,
        section: HistorySection.all,
      ),
      (
        label: 'link'.tr,
        icon: CupertinoIcons.link,
        section: HistorySection.links,
      ),
      (
        label: 'image'.tr,
        icon: CupertinoIcons.photo,
        section: HistorySection.images,
      ),
      (
        label: 'code'.tr,
        icon: CupertinoIcons.chevron_left_slash_chevron_right,
        section: HistorySection.code,
      ),
    ];

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
                final visible = state.visibleItems;
                final selectedItem = visible.isNotEmpty ? visible.first : null;
                ref
                    .read(aiControllerProvider.notifier)
                    .setClipboardContext(selectedItem);
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
                      label: collection.name,
                      icon: CupertinoIcons.folder,
                      selected: state.section == HistorySection.collection &&
                          state.collectionId == collection.id,
                      onPressed: () => historyNotifier.selectSection(
                        HistorySection.collection,
                        collectionId: collection.id,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  for (final tab in typeTabs) ...[
                    CupertinoChoicePill(
                      label: tab.label,
                      icon: tab.icon,
                      selected: state.section == tab.section,
                      onPressed: () =>
                          historyNotifier.selectSection(tab.section),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (state.typeFilter != null) ...[
                    CupertinoChoicePill(
                      label: typeName(state.typeFilter!),
                      icon: typeIcon(state.typeFilter!),
                      selected: true,
                      onPressed: () => historyNotifier.filterByType(null),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 260,
            child: CupertinoSearchTextField(
              key: const Key('quick-panel-search'),
              controller: searchController,
              focusNode: searchFocusNode,
              placeholder: 'search_in_clipboard'.tr,
              onChanged: historyNotifier.search,
            ),
          ),
          const SizedBox(width: 6),
          CupertinoIconControl(
            icon: CupertinoIcons.slider_horizontal_3,
            color: state.typeFilter != null
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

  String typeName(ClipboardContentType type) => switch (type) {
    ClipboardContentType.text => 'Văn bản',
    ClipboardContentType.url => 'Liên kết',
    ClipboardContentType.email => 'Email',
    ClipboardContentType.phone => 'Điện thoại',
    ClipboardContentType.code => 'Code',
    ClipboardContentType.color => 'Màu HEX',
    ClipboardContentType.json => 'JSON',
    ClipboardContentType.file => 'Đường dẫn file',
    ClipboardContentType.image => 'Hình ảnh',
  };

  IconData typeIcon(ClipboardContentType type) => switch (type) {
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
}
