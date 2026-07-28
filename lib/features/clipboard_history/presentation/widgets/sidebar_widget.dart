import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_item.dart';
import '../history_controller.dart';

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({
    super.key,
    required this.state,
    required this.collections,
    required this.onOpenSettings,
    required this.onCreateCollection,
    required this.onDeleteCollection,
  });

  final ClipboardHistoryState state;
  final List<ClipboardCollection> collections;
  final VoidCallback onOpenSettings;
  final VoidCallback onCreateCollection;
  final ValueChanged<ClipboardCollection> onDeleteCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyNotifier = ref.read(historyControllerProvider.notifier);

    final systemItems = [
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

    final typeItems = [
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

    return ColoredBox(
      color: resolveColor(context, ClipFlowColors.sidebar),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    image: const DecorationImage(
                      image: AssetImage('assets/branding/clipflow_app_icon.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'app_name'.tr,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const Spacer(),
                CupertinoIconControl(
                  icon: CupertinoIcons.settings,
                  onPressed: onOpenSettings,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final item in systemItems)
                    SidebarTileWidget(
                      icon: item.icon,
                      label: item.label,
                      selected: state.section == item.section,
                      onTap: () => historyNotifier.selectSection(item.section),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'collections_header'.tr,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: resolveColor(
                                context,
                                ClipFlowColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      CupertinoIconControl(
                        icon: CupertinoIcons.add,
                        size: 16,
                        onPressed: onCreateCollection,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final collection in collections)
                    SidebarTileWidget(
                      icon: CupertinoIcons.folder,
                      label: collection.name,
                      selected: state.section == HistorySection.collection &&
                          state.collectionId == collection.id,
                      trailing: CupertinoIconControl(
                        icon: CupertinoIcons.xmark,
                        size: 13,
                        onPressed: () => onDeleteCollection(collection),
                      ),
                      onTap: () => historyNotifier.selectSection(
                        HistorySection.collection,
                        collectionId: collection.id,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      'type_filter_header'.tr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                  for (final item in typeItems)
                    SidebarTileWidget(
                      icon: item.icon,
                      label: item.label,
                      selected: state.section == item.section,
                      onTap: () => historyNotifier.selectSection(item.section),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SidebarTileWidget extends StatelessWidget {
  const SidebarTileWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CupertinoPressable(
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primary : const Color(0x00000000),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? CupertinoColors.white : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? CupertinoColors.white : null,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
