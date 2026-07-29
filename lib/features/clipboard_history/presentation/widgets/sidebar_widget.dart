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
    this.reserveWindowControls = false,
  });

  final ClipboardHistoryState state;
  final List<ClipboardCollection> collections;
  final VoidCallback onOpenSettings;
  final VoidCallback onCreateCollection;
  final ValueChanged<ClipboardCollection> onDeleteCollection;
  final bool reserveWindowControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyNotifier = ref.read(historyControllerProvider.notifier);

    return ColoredBox(
      color: resolveColor(context, ClipFlowColors.sidebar),
      child: SafeArea(
        top: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(-10 * (1 - value), 0),
              child: child,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              reserveWindowControls ? 50 : 14,
              12,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  key: const Key('sidebar-library-title'),
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                  child: Text(
                    'library'.tr,
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
                SidebarTileWidget(
                  icon: CupertinoIcons.tray_full,
                  label: 'all'.tr,
                  selected: state.section == HistorySection.all,
                  onTap: () =>
                      historyNotifier.selectSection(HistorySection.all),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.pin,
                  label: 'pinned'.tr,
                  selected: state.section == HistorySection.pinned,
                  onTap: () =>
                      historyNotifier.selectSection(HistorySection.pinned),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.photo,
                  label: 'images'.tr,
                  selected: state.section == HistorySection.images,
                  onTap: () =>
                      historyNotifier.selectSection(HistorySection.images),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.link,
                  label: 'links'.tr,
                  selected: state.section == HistorySection.links,
                  onTap: () =>
                      historyNotifier.selectSection(HistorySection.links),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.chevron_left_slash_chevron_right,
                  label: 'code'.tr,
                  selected: state.section == HistorySection.code,
                  onTap: () =>
                      historyNotifier.selectSection(HistorySection.code),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          'collections'.tr,
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
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final collection in collections)
                        SidebarTileWidget(
                          icon: CupertinoIcons.folder,
                          label: _displayCollectionName(collection),
                          selected:
                              state.section == HistorySection.collection &&
                              state.collectionId == collection.id,
                          onTap: () => historyNotifier.selectSection(
                            HistorySection.collection,
                            collectionId: collection.id,
                          ),
                          onLongPress: () =>
                              _showCollectionActions(context, ref, collection),
                          onOptionsPressed: () =>
                              _showCollectionActions(context, ref, collection),
                        ),
                    ],
                  ),
                ),
                const CupertinoDivider(),
                const SizedBox(height: 8),
                SidebarTileWidget(
                  icon: CupertinoIcons.settings,
                  label: 'settings'.tr,
                  selected: false,
                  onTap: onOpenSettings,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.lock_shield,
                        size: 13,
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'local_data_only'.tr,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCollectionActions(
    BuildContext context,
    WidgetRef ref,
    ClipboardCollection collection,
  ) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(collection.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'rename'),
            child: Text('rename'.tr),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text('delete_collection'.tr),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'delete') {
      onDeleteCollection(collection);
    } else if (action == 'rename') {
      final controller = TextEditingController(text: collection.name);
      final name = await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('rename_collection'.tr),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(controller: controller, autofocus: true),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('rename'.tr),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name != null && name.isNotEmpty) {
        await ref
            .read(collectionsControllerProvider.notifier)
            .rename(collection.id, name);
      }
    }
  }
}

class SidebarTileWidget extends StatelessWidget {
  const SidebarTileWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.onOptionsPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onLongPress: onLongPress,
        onSecondaryTap: onOptionsPressed ?? onLongPress,
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
                if (onOptionsPressed != null) ...[
                  const SizedBox(width: 4),
                  CupertinoIconControl(
                    icon: CupertinoIcons.ellipsis,
                    size: 14,
                    color: selected
                        ? CupertinoColors.white
                        : resolveColor(context, ClipFlowColors.secondaryText),
                    onPressed: onOptionsPressed,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
