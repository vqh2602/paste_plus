import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_item.dart';
import '../history_controller.dart';
import 'clipboard_action_menu.dart';

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({
    super.key,
    required this.state,
    required this.collections,
    required this.onOpenSettings,
    required this.onCreateCollection,
    required this.onDeleteCollection,
    this.reserveWindowControls = false,
    this.onNavigationSelected,
  });

  final ClipboardHistoryState state;
  final List<ClipboardCollection> collections;
  final VoidCallback onOpenSettings;
  final VoidCallback onCreateCollection;
  final ValueChanged<ClipboardCollection> onDeleteCollection;
  final bool reserveWindowControls;
  final VoidCallback? onNavigationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyNotifier = ref.read(historyControllerProvider.notifier);

    void selectSection(HistorySection section, {String? collectionId}) {
      unawaited(
        historyNotifier.selectSection(section, collectionId: collectionId),
      );
      onNavigationSelected?.call();
    }

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
                    context.l10n.library,
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
                  label: context.l10n.all,
                  selected: state.section == HistorySection.all,
                  onTap: () => selectSection(HistorySection.all),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.pin,
                  label: context.l10n.pinned,
                  selected: state.section == HistorySection.pinned,
                  onTap: () => selectSection(HistorySection.pinned),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.photo,
                  label: context.l10n.images,
                  selected: state.section == HistorySection.images,
                  onTap: () => selectSection(HistorySection.images),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.link,
                  label: context.l10n.links,
                  selected: state.section == HistorySection.links,
                  onTap: () => selectSection(HistorySection.links),
                ),
                SidebarTileWidget(
                  icon: CupertinoIcons.chevron_left_slash_chevron_right,
                  label: context.l10n.code,
                  selected: state.section == HistorySection.code,
                  onTap: () => selectSection(HistorySection.code),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          context.l10n.collections,
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
                        DragTarget<ClipboardItem>(
                          key: Key('collection-drop-target-${collection.id}'),
                          onWillAcceptWithDetails: (details) => true,
                          onAcceptWithDetails: (details) {
                            unawaited(
                              _addItemToCollection(
                                context,
                                historyNotifier,
                                details.data,
                                collection,
                              ),
                            );
                          },
                          builder: (context, candidateData, rejectedData) =>
                              SidebarTileWidget(
                                icon: CupertinoIcons.folder,
                                label: _displayCollectionName(
                                  context,
                                  collection,
                                ),
                                selected:
                                    state.section ==
                                        HistorySection.collection &&
                                    state.collectionId == collection.id,
                                highlighted: candidateData.isNotEmpty,
                                onTap: () => selectSection(
                                  HistorySection.collection,
                                  collectionId: collection.id,
                                ),
                                onLongPress: () => _showCollectionActions(
                                  context,
                                  ref,
                                  collection,
                                ),
                                onOptionsPressed: (menuContext) =>
                                    _showCollectionActions(
                                      menuContext,
                                      ref,
                                      collection,
                                    ),
                              ),
                        ),
                    ],
                  ),
                ),
                const CupertinoDivider(),
                const SizedBox(height: 8),
                SidebarTileWidget(
                  icon: CupertinoIcons.settings,
                  label: context.l10n.settings,
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
                          context.l10n.local_data_only,
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

  String _displayCollectionName(
    BuildContext context,
    ClipboardCollection collection,
  ) {
    return switch (collection.id) {
      'personal' => context.l10n.collection_personal,
      'link' => context.l10n.collection_link,
      'reply' => context.l10n.collection_reply,
      _ => collection.name,
    };
  }

  Future<void> _addItemToCollection(
    BuildContext context,
    ClipboardHistoryController historyNotifier,
    ClipboardItem item,
    ClipboardCollection collection,
  ) async {
    await historyNotifier.addToCollection(item.id, collection.id);
    if (context.mounted) {
      showCupertinoNotice(
        context,
        context.l10n.added_to_collection_named.replaceAll(
          '@name',
          _displayCollectionName(context, collection),
        ),
      );
    }
  }

  Future<void> _showCollectionActions(
    BuildContext context,
    WidgetRef ref,
    ClipboardCollection collection,
  ) async {
    final action = await showCompactActionMenu(
      context: context,
      menuKey: const Key('collection-action-menu'),
      itemKeyPrefix: 'collection-action',
      actions: [
        CompactMenuAction(
          value: 'rename',
          icon: CupertinoIcons.pencil,
          label: context.l10n.rename,
        ),
        CompactMenuAction(
          value: 'delete',
          icon: CupertinoIcons.trash,
          label: context.l10n.delete_collection,
          dividerBefore: true,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    if (action == 'delete') {
      onDeleteCollection(collection);
    } else if (action == 'rename') {
      final controller = TextEditingController(text: collection.name);
      final name = await showCupertinoDialog<String>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(context.l10n.rename_collection),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(controller: controller, autofocus: true),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(context.l10n.rename),
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
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<BuildContext>? onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: GestureDetector(
        onLongPress: onLongPress,
        onSecondaryTap: onOptionsPressed != null
            ? () => onOptionsPressed!(context)
            : onLongPress,
        child: CupertinoPressable(
          onPressed: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? primary
                  : highlighted
                  ? primary.withValues(alpha: 0.16)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(9),
              border: highlighted && !selected
                  ? Border.all(color: primary, width: 1.5)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? CupertinoColors.white
                      : highlighted
                      ? primary
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected || highlighted
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected
                          ? CupertinoColors.white
                          : highlighted
                          ? primary
                          : null,
                    ),
                  ),
                ),
                if (onOptionsPressed != null) ...[
                  const SizedBox(width: 4),
                  Builder(
                    builder: (menuContext) => CupertinoIconControl(
                      icon: CupertinoIcons.ellipsis,
                      size: 14,
                      color: selected
                          ? CupertinoColors.white
                          : highlighted
                          ? primary
                          : resolveColor(context, ClipFlowColors.secondaryText),
                      onPressed: () => onOptionsPressed!(menuContext),
                    ),
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
