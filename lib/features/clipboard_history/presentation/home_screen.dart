import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/platform/shortcut_config.dart';
import '../../../core/ui/cached_network_image_widget.dart';
import '../../../core/ui/cupertino_components.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_item.dart';
import 'history_controller.dart';
import 'quick_panel_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  ClipboardItem? get _selectedItem {
    final state = ref.read(historyControllerProvider);
    for (final item in state.visibleItems) {
      if (item.id == state.selectedItemId) return item;
    }
    return null;
  }

  void _moveSelection(int direction) {
    final state = ref.read(historyControllerProvider);
    final items = state.visibleItems;
    if (items.isEmpty) return;
    final current = items.indexWhere((item) => item.id == state.selectedItemId);
    final next = (current + direction).clamp(0, items.length - 1);
    ref.read(historyControllerProvider.notifier).select(items[next].id);
  }

  Future<void> _copy(ClipboardItem item) async {
    final controller = ref.read(historyControllerProvider.notifier);
    await controller.copy(item);
    final settings = ref.read(settingsControllerProvider);
    final desktop = ref.read(desktopIntegrationProvider);

    if (settings.closeAfterCopy) {
      await desktop.hideQuickPanel();
      final pasted = await desktop.pasteToPreviousApplication();
      if (!pasted && Platform.isMacOS) {
        final hasPermission = await desktop.checkAccessibilityPermission();
        if (!hasPermission) {
          await desktop.requestAccessibilityPermission();
        }
      }
    } else {
      if (mounted) showCupertinoNotice(context, 'copied'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(quickPanelModeProvider)) {
      return const QuickPanelScreen();
    }
    final settings = ref.watch(settingsControllerProvider);
    final bindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          _moveSelection(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          _moveSelection(-1),
      const SingleActivator(LogicalKeyboardKey.enter): () {
        final item = _selectedItem;
        if (item != null) _copy(item);
      },
      shortcutActivator(
        decodeShortcut(settings.deleteItemShortcut, ShortcutAction.deleteItem),
      ): () {
        final item = _selectedItem;
        if (item != null) _confirmDelete(item);
      },
      shortcutActivator(
        decodeShortcut(
          settings.focusSearchShortcut,
          ShortcutAction.focusSearch,
        ),
      ): _focusNode.requestFocus,
      shortcutActivator(
        decodeShortcut(settings.togglePinShortcut, ShortcutAction.togglePin),
      ): () {
        final item = _selectedItem;
        if (item != null) {
          ref.read(historyControllerProvider.notifier).togglePinned(item);
        }
      },
    };

    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(
        autofocus: true,
        child: CupertinoPageScaffold(
          child: Column(
            children: [
              if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
                DragToMoveArea(
                  child: SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        const SizedBox(width: 80),
                        const Spacer(),
                        const Text(
                          'ClipFlow',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 80),
                      ],
                    ),
                  ),
                ),
              const CupertinoDivider(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final showPreview = constraints.maxWidth >= 1120;
                    return Row(
                      children: [
                        if (!compact) ...[
                          const SizedBox(width: 244, child: _Sidebar()),
                          SizedBox(
                            width: 1,
                            child: ColoredBox(color: resolveColor(context, ClipFlowColors.border)),
                          ),
                        ],
                        Expanded(
                          child: _HistoryPane(
                            compact: compact,
                            searchController: _searchController,
                            focusNode: _focusNode,
                            onOpenSidebar: compact
                                ? () => _showSidebar(context)
                                : null,
                            onCopy: _copy,
                            onDelete: _confirmDelete,
                            onAddToCollection: _showCollections,
                          ),
                        ),
                        if (showPreview) ...[
                          SizedBox(
                            width: 1,
                            child: ColoredBox(color: resolveColor(context, ClipFlowColors.border)),
                          ),
                          const SizedBox(width: 330, child: _DetailPane()),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSidebar(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Align(
        alignment: Alignment.centerLeft,
        child: SafeArea(
          child: CupertinoPopupSurface(
            child: SizedBox(
              width: 300,
              height: MediaQuery.sizeOf(context).height,
              child: _Sidebar(onNavigate: () => Navigator.pop(context)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ClipboardItem item) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('delete_item_title'.tr),
        content: Text('delete_cannot_undo'.tr),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyControllerProvider.notifier).delete(item);
    }
  }

  Future<void> _showCollections(ClipboardItem item) async {
    final collectionsNotifier =
        ref.read(collectionsControllerProvider.notifier);
    final historyNotifier = ref.read(historyControllerProvider.notifier);

    var collections = ref.read(collectionsControllerProvider).value ?? [];
    final selected = await historyNotifier.collectionIdsForItem(item.id);
    if (!mounted) return;

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text('add_to_collection_title'.tr),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (collections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text('no_collections'.tr),
                  )
                else
                  ...collections.map((collection) {
                    final checked = selected.contains(collection.id);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.folder, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(collection.name)),
                          CupertinoSwitch(
                            value: checked,
                            onChanged: (value) async {
                              if (value) {
                                await ref
                                    .read(clipboardRepositoryProvider)
                                    .addToCollection(item.id, collection.id);
                                selected.add(collection.id);
                              } else {
                                await ref
                                    .read(clipboardRepositoryProvider)
                                    .removeFromCollection(
                                      item.id,
                                      collection.id,
                                    );
                                selected.remove(collection.id);
                              }
                              setDialogState(() {});
                              await historyNotifier.reload();
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () async {
                final name = await _textDialog(
                  context,
                  title: 'new_collection'.tr,
                );
                if (name != null && name.trim().isNotEmpty) {
                  await collectionsNotifier.create(name.trim());
                  collections =
                      ref.read(collectionsControllerProvider).value ?? [];
                  setDialogState(() {});
                }
              },
              child: Text('new_collection_btn'.tr),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('granted'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({this.onNavigate});

  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final collections = ref.watch(collectionsControllerProvider);
    return ColoredBox(
      color: resolveColor(context, ClipFlowColors.sidebar),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                child: Text(
                  'library'.tr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: resolveColor(context, ClipFlowColors.secondaryText),
                  ),
                ),
              ),
              _NavTile(
                icon: CupertinoIcons.tray_full,
                label: 'all'.tr,
                selected: state.section == HistorySection.all,
                onTap: () => _navigate(ref, HistorySection.all),
              ),
              _NavTile(
                icon: CupertinoIcons.pin,
                label: 'pinned'.tr,
                selected: state.section == HistorySection.pinned,
                onTap: () => _navigate(ref, HistorySection.pinned),
              ),
              _NavTile(
                icon: CupertinoIcons.photo,
                label: 'images'.tr,
                selected: state.section == HistorySection.images,
                onTap: () => _navigate(ref, HistorySection.images),
              ),
              _NavTile(
                icon: CupertinoIcons.link,
                label: 'links'.tr,
                selected: state.section == HistorySection.links,
                onTap: () => _navigate(ref, HistorySection.links),
              ),
              _NavTile(
                icon: CupertinoIcons.chevron_left_slash_chevron_right,
                label: 'code'.tr,
                selected: state.section == HistorySection.code,
                onTap: () => _navigate(ref, HistorySection.code),
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
                          color: resolveColor(context, ClipFlowColors.secondaryText),
                        ),
                      ),
                    ),
                  ),
                  CupertinoIconControl(
                    icon: CupertinoIcons.add,
                    size: 16,
                    onPressed: () => _createCollection(context, ref),
                  ),
                ],
              ),
              Expanded(
                child: collections.when(
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(radius: 8),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (items) => ListView(
                    padding: EdgeInsets.zero,
                    children: items.map((collection) {
                      return _NavTile(
                        icon: CupertinoIcons.folder,
                        label: collection.name,
                        selected:
                            state.section == HistorySection.collection &&
                            state.collectionId == collection.id,
                        onTap: () => _navigate(
                          ref,
                          HistorySection.collection,
                          collectionId: collection.id,
                        ),
                        onLongPress: () =>
                            _collectionActions(context, ref, collection),
                        onOptionsPressed: () =>
                            _collectionActions(context, ref, collection),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const CupertinoDivider(),
              const SizedBox(height: 8),
              _NavTile(
                icon: CupertinoIcons.settings,
                label: 'settings'.tr,
                selected: false,
                onTap: () {
                  onNavigate?.call();
                  context.push('/settings');
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.lock_shield,
                      size: 13,
                      color: resolveColor(context, ClipFlowColors.secondaryText),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'local_data_only'.tr,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: resolveColor(context, ClipFlowColors.secondaryText),
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
    );
  }

  void _navigate(
    WidgetRef ref,
    HistorySection section, {
    String? collectionId,
  }) {
    ref
        .read(historyControllerProvider.notifier)
        .selectSection(section, collectionId: collectionId);
    onNavigate?.call();
  }

  Future<void> _createCollection(BuildContext context, WidgetRef ref) async {
    final name = await _textDialog(context, title: 'new_collection'.tr);
    if (name != null) {
      await ref.read(collectionsControllerProvider.notifier).create(name);
    }
  }

  Future<void> _collectionActions(
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
    if (action == 'rename') {
      final name = await _textDialog(
        context,
        title: 'rename_collection'.tr,
        initialValue: collection.name,
      );
      if (name != null) {
        await ref
            .read(collectionsControllerProvider.notifier)
            .rename(collection.id, name);
      }
    } else if (action == 'delete') {
      await ref
          .read(collectionsControllerProvider.notifier)
          .delete(collection.id);
      await ref
          .read(historyControllerProvider.notifier)
          .onCollectionDeleted(collection.id);
    }
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
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
      padding: const EdgeInsets.only(bottom: 3),
      child: GestureDetector(
        onLongPress: onLongPress,
        onSecondaryTap: onOptionsPressed ?? onLongPress,
        child: CupertinoPressable(
          onPressed: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? primary : const Color(0x00000000),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? CupertinoColors.white : null,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
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

class _HistoryPane extends ConsumerWidget {
  const _HistoryPane({
    required this.compact,
    required this.searchController,
    required this.focusNode,
    required this.onCopy,
    required this.onDelete,
    required this.onAddToCollection,
    this.onOpenSidebar,
  });

  final bool compact;
  final TextEditingController searchController;
  final FocusNode focusNode;
  final VoidCallback? onOpenSidebar;
  final ValueChanged<ClipboardItem> onCopy;
  final ValueChanged<ClipboardItem> onDelete;
  final ValueChanged<ClipboardItem> onAddToCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final items = state.visibleItems;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 10 : 20, 14, 18, 10),
          child: Row(
            children: [
              if (onOpenSidebar != null)
                CupertinoIconControl(
                  icon: CupertinoIcons.sidebar_left,
                  onPressed: onOpenSidebar,
                ),
              Expanded(
                child: CupertinoSearchTextField(
                  key: const Key('history-search'),
                  controller: searchController,
                  focusNode: focusNode,
                  placeholder: 'search_in_clipboard'.tr,
                  onChanged: ref
                      .read(historyControllerProvider.notifier)
                      .search,
                ),
              ),
              const SizedBox(width: 10),
              CupertinoIconControl(
                icon: settings.monitoringEnabled
                    ? CupertinoIcons.pause_circle
                    : CupertinoIcons.play_circle,
                color: settings.monitoringEnabled
                    ? null
                    : CupertinoColors.systemOrange,
                onPressed: () async {
                  final enabled = !settings.monitoringEnabled;
                  await ref
                      .read(settingsControllerProvider.notifier)
                      .update(
                        (current) =>
                            current.copyWith(monitoringEnabled: enabled),
                      );
                  await ref
                      .read(historyControllerProvider.notifier)
                      .setMonitoring(enabled);
                },
              ),
            ],
          ),
        ),
        if (state.section == HistorySection.all ||
            state.section == HistorySection.pinned ||
            state.section == HistorySection.collection) ...[
          SizedBox(
            height: 43,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 22),
              children: [
                _FilterPill(
                  label: 'all'.tr,
                  selected: state.typeFilter == null,
                  onPressed: () => ref
                      .read(historyControllerProvider.notifier)
                      .filterByType(null),
                ),
                for (final entry in {
                  ClipboardContentType.text: 'text'.tr,
                  ClipboardContentType.url: 'links'.tr,
                  ClipboardContentType.code: 'code'.tr,
                  ClipboardContentType.image: 'images'.tr,
                  ClipboardContentType.file: 'files'.tr,
                }.entries)
                  _FilterPill(
                    label: entry.value,
                    selected: state.typeFilter == entry.key,
                    onPressed: () => ref
                        .read(historyControllerProvider.notifier)
                        .filterByType(entry.key),
                  ),
              ],
            ),
          ),
          const CupertinoDivider(),
        ],
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: state.isLoading
                ? const Center(
                    key: ValueKey('loading'),
                    child: CupertinoActivityIndicator(),
                  )
                : state.errorMessage != null
                ? _ErrorState(
                    key: const ValueKey('error'),
                    message: state.errorMessage!,
                  )
                : items.isEmpty
                ? _EmptyState(
                    key: const ValueKey('empty'),
                    hasQuery: state.query.isNotEmpty,
                  )
                : ListView.builder(
                    key: ValueKey('list-${state.section}-${state.typeFilter}-${state.query}'),
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 22,
                      12,
                      compact ? 12 : 22,
                      24,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return StaggeredAnimatedItem(
                        key: ValueKey(item.id),
                        index: index,
                        child: _ClipboardItemCard(
                          item: item,
                          index: index,
                          selected: item.id == state.selectedItemId,
                          query: state.query,
                          onTap: () {
                            ref
                                .read(historyControllerProvider.notifier)
                                .select(item.id);
                            onCopy(item);
                          },
                          onPin: () => ref
                              .read(historyControllerProvider.notifier)
                              .togglePinned(item),
                          onMore: () => _showItemActions(
                            context,
                            ref,
                            item,
                            onDelete,
                            onAddToCollection,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: CupertinoChoicePill(
        label: label,
        selected: selected,
        onPressed: onPressed,
      ),
    );
  }
}

class _ClipboardItemCard extends StatelessWidget {
  const _ClipboardItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.selected,
    this.query = '',
    required this.onTap,
    required this.onPin,
    required this.onMore,
  });

  final ClipboardItem item;
  final int index;
  final bool selected;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(item.contentType);
    final primary = CupertinoTheme.of(context).primaryColor;
    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CupertinoPressable(
        key: const Key('clipboard-item'),
        onPressed: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: resolveColor(context, ClipFlowColors.surface),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? primary
                  : resolveColor(context, ClipFlowColors.border),
              width: selected ? 1.8 : 1.0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: item.contentType == ClipboardContentType.color
                    ? Container(
                        margin: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: _parseHex(item.content) ?? color,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      )
                    : Icon(
                        _typeIcon(item.contentType),
                        color: color,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _typeLabel(item.contentType),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _relativeTime(item.lastCopiedAt),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: resolveColor(context, ClipFlowColors.secondaryText),
                            ),
                          ),
                        ),
                        if (index < 9)
                          Text(
                            '${Platform.isMacOS ? '⌘' : 'Ctrl+'}${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: resolveColor(context, ClipFlowColors.secondaryText),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    if (item.contentType == ClipboardContentType.image) ...[
                      _ClipboardImagePreview(
                        path: item.imagePath ?? item.content,
                        height: 118,
                      ),
                      if (item.content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        HighlightedText(
                          text: item.content,
                          query: query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: resolveColor(context, ClipFlowColors.secondaryText),
                          ),
                        ),
                      ],
                    ]
                    else if (isImageUrl(item.content)) ...[
                      _ClipboardImagePreview(
                        path: item.content,
                        height: 118,
                      ),
                      const SizedBox(height: 4),
                      HighlightedText(
                        text: item.content,
                        query: query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: resolveColor(context, ClipFlowColors.secondaryText),
                        ),
                      ),
                    ]
                    else
                      HighlightedText(
                        text: item.content,
                        query: query,
                        maxLines:
                            item.contentType == ClipboardContentType.code ||
                                item.contentType == ClipboardContentType.json
                            ? 4
                            : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: item.contentType == ClipboardContentType.url
                              ? CupertinoColors.activeBlue
                              : null,
                          decoration: item.contentType == ClipboardContentType.url
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: item.contentType == ClipboardContentType.url
                              ? CupertinoColors.activeBlue.withValues(alpha: 0.4)
                              : null,
                          fontFamily:
                              item.contentType == ClipboardContentType.code ||
                                  item.contentType ==
                                      ClipboardContentType.json
                              ? 'monospace'
                              : null,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      item.sourceAppName ?? 'Thiết bị này',
                      style: TextStyle(
                        fontSize: 11,
                        color: resolveColor(context, ClipFlowColors.secondaryText),
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoIconControl(
                key: const Key('pin-button'),
                icon: item.isPinned
                    ? CupertinoIcons.pin_fill
                    : CupertinoIcons.pin,
                color: item.isPinned ? primary : null,
                size: 18,
                onPressed: onPin,
              ),
              CupertinoIconControl(
                key: const Key('item-more-button'),
                icon: CupertinoIcons.ellipsis,
                size: 19,
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
    return LongPressDraggable<String>(
      data: item.id,
      delay: const Duration(milliseconds: 180),
      feedback: SizedBox(
        width: 340,
        child: CupertinoPopupSurface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              item.content.isEmpty ? 'Hình ảnh' : item.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _DetailPane extends ConsumerStatefulWidget {
  const _DetailPane();

  @override
  ConsumerState<_DetailPane> createState() => _DetailPaneState();
}

class _DetailPaneState extends ConsumerState<_DetailPane> {
  bool _isProcessing = false;
  bool _isUploading = false;

  Future<void> _handleOcr(ClipboardItem item) async {
    setState(() => _isProcessing = true);
    try {
      final result = await ref
          .read(historyControllerProvider.notifier)
          .performOcr(item);
      if (!mounted) return;
      if (result != null) {
        showCupertinoNotice(context, 'ocr_success'.tr);
      } else {
        showCupertinoNotice(context, 'ocr_empty'.tr);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleTranslate(ClipboardItem item) async {
    final settings = ref.read(settingsControllerProvider);
    setState(() => _isProcessing = true);
    try {
      final result = await ref
          .read(historyControllerProvider.notifier)
          .translateItem(item, settings.targetTranslationLanguage);
      if (!mounted) return;
      if (result != null) {
        showCupertinoNotice(context, 'translate_success'.tr);
      } else {
        showCupertinoNotice(context, 'translate_failed'.tr);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCloudUpload(ClipboardItem item) async {
    setState(() => _isUploading = true);
    try {
      final url = await ref
          .read(historyControllerProvider.notifier)
          .uploadImageToCloud(item);
      if (!mounted) return;
      if (url != null) {
        showCupertinoNotice(context, 'upload_cloud_success'.tr);
      } else {
        showCupertinoNotice(context, 'upload_cloud_failed'.tr);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    ClipboardItem? item;
    for (final entry in state.visibleItems) {
      if (entry.id == state.selectedItemId) item = entry;
    }
    if (item == null) {
      return Center(child: Text('select_item_to_view'.tr));
    }
    final isImage = item.contentType == ClipboardContentType.image;
    final isOnlineImage = isImageUrl(item.content);
    return ColoredBox(
      color: resolveColor(context, ClipFlowColors.sidebar),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(item.contentType), size: 19),
                const SizedBox(width: 9),
                Text(
                  _typeLabel(item.contentType),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Expanded(
              child: SingleChildScrollView(
                child: isImage
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClipboardImagePreview(
                            path: item.imagePath ?? item.content,
                            height: 260,
                          ),
                          if (item.content.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              item.content,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: resolveColor(context, ClipFlowColors.secondaryText),
                              ),
                            ),
                          ],
                        ],
                      )
                    : isOnlineImage
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClipboardImagePreview(path: item.content, height: 260),
                          const SizedBox(height: 12),
                          Text(
                            item.content,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: resolveColor(context, ClipFlowColors.secondaryText),
                            ),
                          ),
                        ],
                      )
                    : HighlightedText(
                        text: item.content,
                        query: state.query,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: item.contentType == ClipboardContentType.url
                              ? CupertinoColors.activeBlue
                              : null,
                          decoration: item.contentType == ClipboardContentType.url
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: item.contentType == ClipboardContentType.url
                              ? CupertinoColors.activeBlue.withValues(alpha: 0.4)
                              : null,
                          fontFamily:
                              item.contentType == ClipboardContentType.code ||
                                  item.contentType == ClipboardContentType.json
                              ? 'monospace'
                              : null,
                        ),
                      ),
              ),
            ),
            const CupertinoDivider(),
            const SizedBox(height: 12),
            _MetadataRow(
              label: 'copied_time'.tr,
              value: DateFormat('dd/MM/yyyy HH:mm').format(item.lastCopiedAt),
            ),
            _MetadataRow(
              label: 'source_app'.tr,
              value: item.sourceAppName ?? 'unknown'.tr,
            ),
            _MetadataRow(label: 'usage_count'.tr, value: '${item.copyCount}'),
            const SizedBox(height: 14),
            if (isImage) ...[
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.activeBlue.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: _isProcessing ? null : () => _handleOcr(item!),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: CupertinoActivityIndicator(radius: 8),
                        )
                      else
                        const Icon(CupertinoIcons.doc_text_search, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'extract_ocr'.tr,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.activeGreen.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: _isUploading ? null : () => _handleCloudUpload(item!),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUploading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: CupertinoActivityIndicator(radius: 8),
                        )
                      else
                        const Icon(
                          CupertinoIcons.cloud_upload,
                          size: 16,
                          color: CupertinoColors.activeGreen,
                        ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'upload_cloud'.tr,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CupertinoColors.activeGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.activeBlue.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: _isProcessing ? null : () => _handleTranslate(item!),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: CupertinoActivityIndicator(radius: 8),
                        )
                      else
                        const Icon(CupertinoIcons.globe, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'translate_text'.tr,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: () =>
                    ref.read(historyControllerProvider.notifier).copy(item!),
                child: Text('copy_again'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: resolveColor(context, ClipFlowColors.secondaryText)),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _ClipboardImagePreview extends StatelessWidget {
  const _ClipboardImagePreview({required this.path, required this.height});

  final String? path;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (path != null && isImageUrl(path!)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          url: path!,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }
    if (path == null || !File(path!).existsSync()) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.photo_on_rectangle),
            SizedBox(height: 6),
            Text('File hình ảnh không còn tồn tại'),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path!),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Center(child: Text('Không thể hiển thị hình ảnh')),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery
                  ? CupertinoIcons.search
                  : CupertinoIcons.doc_on_clipboard,
              size: 50,
              color: CupertinoTheme.of(context).primaryColor,
            ),
            const SizedBox(height: 18),
            Text(
              hasQuery
                  ? 'no_results_found'.tr
                  : 'clipboard_empty_title'.tr,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'try_different_keyword'.tr
                  : 'clipboard_empty_subtitle'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: resolveColor(context, ClipFlowColors.secondaryText)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.exclamationmark_triangle, size: 44),
          const SizedBox(height: 14),
          Text(message),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: ref.read(historyControllerProvider.notifier).reload,
            child: Text('try_again'.tr),
          ),
        ],
      ),
    );
  }
}

Future<void> _showItemActions(
  BuildContext context,
  WidgetRef ref,
  ClipboardItem item,
  ValueChanged<ClipboardItem> onDelete,
  ValueChanged<ClipboardItem> onAddToCollection,
) async {
  final isImage = item.contentType == ClipboardContentType.image;
  final action = await showCupertinoModalPopup<String>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      actions: [
        if (isImage) ...[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'ocr'),
            child: Text('extract_ocr'.tr),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'cloud_upload'),
            child: Text('upload_cloud'.tr),
          ),
        ]
        else
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'translate'),
            child: Text('translate_text'.tr),
          ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, 'collection'),
          child: Text('add_to_collection_title'.tr),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, 'delete'),
          child: Text('delete'.tr),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text('cancel'.tr),
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'ocr') {
    final text = await ref
        .read(historyControllerProvider.notifier)
        .performOcr(item);
    if (context.mounted) {
      showCupertinoNotice(
        context,
        text != null
            ? 'ocr_success'.tr
            : 'ocr_empty'.tr,
      );
    }
  } else if (action == 'cloud_upload') {
    final url = await ref
        .read(historyControllerProvider.notifier)
        .uploadImageToCloud(item);
    if (context.mounted) {
      showCupertinoNotice(
        context,
        url != null
            ? 'upload_cloud_success'.tr
            : 'upload_cloud_failed'.tr,
      );
    }
  } else if (action == 'translate') {
    final settings = ref.read(settingsControllerProvider);
    final text = await ref
        .read(historyControllerProvider.notifier)
        .translateItem(item, settings.targetTranslationLanguage);
    if (context.mounted) {
      showCupertinoNotice(
        context,
        text != null ? 'translate_success'.tr : 'translate_failed'.tr,
      );
    }
  } else if (action == 'collection') {
    onAddToCollection(item);
  } else if (action == 'delete') {
    onDelete(item);
  }
}

Future<String?> _textDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) async {
  final controller = TextEditingController(text: initialValue);
  final result = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          autofocus: true,
          placeholder: 'collection_name_placeholder'.tr,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text('granted'.tr),
        ),
      ],
    ),
  );
  controller.dispose();
  return result?.trim().isEmpty == true ? null : result?.trim();
}

IconData _typeIcon(ClipboardContentType type) => switch (type) {
  ClipboardContentType.text => CupertinoIcons.text_alignleft,
  ClipboardContentType.url => CupertinoIcons.link,
  ClipboardContentType.email => CupertinoIcons.at,
  ClipboardContentType.phone => CupertinoIcons.phone,
  ClipboardContentType.code => CupertinoIcons.chevron_left_slash_chevron_right,
  ClipboardContentType.color => CupertinoIcons.paintbrush,
  ClipboardContentType.json => CupertinoIcons.doc_text,
  ClipboardContentType.file => CupertinoIcons.doc,
  ClipboardContentType.image => CupertinoIcons.photo,
};

String _typeLabel(ClipboardContentType type) => switch (type) {
  ClipboardContentType.text => 'text'.tr.toUpperCase(),
  ClipboardContentType.url => 'links'.tr.toUpperCase(),
  ClipboardContentType.email => 'EMAIL',
  ClipboardContentType.phone => 'phone'.tr.toUpperCase(),
  ClipboardContentType.code => 'code'.tr.toUpperCase(),
  ClipboardContentType.color => 'color'.tr.toUpperCase(),
  ClipboardContentType.json => 'JSON',
  ClipboardContentType.file => 'files'.tr.toUpperCase(),
  ClipboardContentType.image => 'images'.tr.toUpperCase(),
};

Color _typeColor(ClipboardContentType type) => switch (type) {
  ClipboardContentType.url => const Color(0xFF0A84FF),
  ClipboardContentType.code ||
  ClipboardContentType.json => const Color(0xFFBF5AF2),
  ClipboardContentType.image => const Color(0xFFFF9F0A),
  ClipboardContentType.color => const Color(0xFFFF375F),
  ClipboardContentType.email ||
  ClipboardContentType.phone => const Color(0xFF30D158),
  ClipboardContentType.file => const Color(0xFF64D2FF),
  ClipboardContentType.text => const Color(0xFF5E5CE6),
};

Color? _parseHex(String value) {
  final source = value.trim().replaceFirst('#', '');
  if (source.length != 6 && source.length != 8) return null;
  final parsed = int.tryParse(source, radix: 16);
  if (parsed == null) return null;
  return Color(source.length == 6 ? 0xFF000000 | parsed : parsed);
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inSeconds < 60) return 'just_now'.tr;
  if (difference.inMinutes < 60) {
    return 'mins_ago'.tr.replaceAll('@m', '${difference.inMinutes}');
  }
  if (difference.inHours < 24) {
    return 'hours_ago'.tr.replaceAll('@h', '${difference.inHours}');
  }
  if (difference.inDays < 7) {
    return 'days_ago'.tr.replaceAll('@d', '${difference.inDays}');
  }
  return DateFormat('dd/MM/yyyy').format(value);
}
