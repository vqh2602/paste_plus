import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/platform/shortcut_config.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../ai/presentation/ai_chat_screen.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_item.dart';
import 'quick_panel_screen.dart';
import 'widgets/detail_pane_widget.dart';
import 'widgets/history_pane_widget.dart';
import 'widgets/sidebar_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSettings() {
    context.push('/settings');
  }

  void _handleCopy(ClipboardItem item) {
    ref.read(historyControllerProvider.notifier).copy(item);
  }

  Future<void> _handleDelete(ClipboardItem item) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('delete_item_title'.tr),
        content: Text('delete_item_confirm'.tr),
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

    if (confirm == true) {
      await ref.read(historyControllerProvider.notifier).delete(item);
    }
  }

  Future<void> _showCreateCollectionDialog() async {
    final controller = TextEditingController();
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('new_collection'.tr),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'collection_name'.tr,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('create'.tr),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name != null && name.isNotEmpty) {
      await ref.read(collectionsControllerProvider.notifier).create(name);
    }
  }

  Future<void> _handleDeleteCollection(ClipboardCollection collection) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('delete_collection'.tr),
        content: Text('delete_collection_confirm'.tr),
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

    if (confirm == true) {
      await ref
          .read(collectionsControllerProvider.notifier)
          .delete(collection.id);
    }
  }

  Future<void> _handleAddToCollection(ClipboardItem item) async {
    final collections =
        ref.read(collectionsControllerProvider).value ?? const [];
    if (collections.isEmpty) {
      await _showCreateCollectionDialog();
      return;
    }

    final collection = await showCupertinoModalPopup<ClipboardCollection>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('add_to_collection'.tr),
        actions: collections.map((col) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(col),
            child: Text(col.name),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr),
        ),
      ),
    );

    if (collection != null) {
      await ref
          .read(historyControllerProvider.notifier)
          .addToCollection(item.id, collection.id);
      if (!mounted) return;
      showCupertinoNotice(context, 'added_to_collection'.tr);
    }
  }

  Future<void> _showItemActions(
    BuildContext context,
    WidgetRef ref,
    ClipboardItem item,
    ValueChanged<ClipboardItem> onDelete,
    ValueChanged<ClipboardItem> onAddToCollection,
  ) async {
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final isImage = item.contentType == ClipboardContentType.image;

    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(item.content),
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
          ] else ...[
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, 'translate'),
              child: Text('translate_text'.tr),
            ),
          ],
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'ask_ai'),
            child: Text('ask_ai'.tr),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'copy'),
            child: Text('copy'.tr),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'pin'),
            child: Text(item.isPinned ? 'unpin_item'.tr : 'pin_item'.tr),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'collection'),
            child: Text('add_to_collection'.tr),
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

    if (!context.mounted || action == null) return;

    if (action == 'ask_ai') {
      ref.read(aiControllerProvider.notifier).setClipboardContext(item);
      await ref.read(desktopIntegrationProvider).showAiWindow();
    } else if (action == 'ocr') {
      final text = await historyNotifier.performOcr(item);
      if (context.mounted) {
        showCupertinoNotice(
          context,
          text != null ? 'ocr_success'.tr : 'ocr_empty'.tr,
        );
      }
    } else if (action == 'cloud_upload') {
      final url = await historyNotifier.uploadImageToCloud(item);
      if (context.mounted) {
        showCupertinoNotice(
          context,
          url != null ? 'upload_cloud_success'.tr : 'upload_cloud_failed'.tr,
        );
      }
    } else if (action == 'translate') {
      final settings = ref.read(settingsControllerProvider);
      final text = await historyNotifier.translateItem(
        item,
        settings.targetTranslationLanguage,
      );
      if (context.mounted) {
        showCupertinoNotice(
          context,
          text != null ? 'translate_success'.tr : 'translate_failed'.tr,
        );
      }
    } else if (action == 'copy') {
      historyNotifier.copy(item);
    } else if (action == 'pin') {
      historyNotifier.togglePinned(item);
    } else if (action == 'collection') {
      onAddToCollection(item);
    } else if (action == 'delete') {
      onDelete(item);
    }
  }

  void _moveSelection(int delta) {
    final state = ref.read(historyControllerProvider);
    final items = state.visibleItems;
    if (items.isEmpty) return;
    final currentIndex = items.indexWhere(
      (it) => it.id == state.selectedItemId,
    );
    final nextIndex = (currentIndex + delta).clamp(0, items.length - 1);
    ref.read(historyControllerProvider.notifier).select(items[nextIndex].id);
  }

  @override
  Widget build(BuildContext context) {
    final aiWindowMode = ref.watch(aiWindowModeProvider);
    final quickPanelMode = ref.watch(quickPanelModeProvider);
    if (aiWindowMode && quickPanelMode) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = (constraints.maxWidth * 0.38)
              .clamp(460.0, 620.0)
              .toDouble();
          final panelHeight = constraints.maxHeight.clamp(300.0, 390.0);
          return Row(
            children: [
              const Expanded(child: AiChatScreen()),
              ColoredBox(
                color: resolveColor(context, ClipFlowColors.border),
                child: const SizedBox(width: 1, height: double.infinity),
              ),
              SizedBox(
                width: panelWidth,
                child: ColoredBox(
                  color: resolveColor(context, ClipFlowColors.sidebar),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: panelHeight,
                      child: const QuickPanelScreen(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
    if (aiWindowMode) {
      return const AiChatScreen();
    }
    if (quickPanelMode) {
      return const QuickPanelScreen();
    }
    final settings = ref.watch(settingsControllerProvider);
    final state = ref.watch(historyControllerProvider);
    final collections =
        ref.watch(collectionsControllerProvider).value ?? const [];

    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          _moveSelection(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          _moveSelection(-1),
      const SingleActivator(LogicalKeyboardKey.enter): () {
        final selected = state.selectedItemId;
        if (selected != null) {
          final item = state.visibleItems.firstWhere((it) => it.id == selected);
          _handleCopy(item);
        }
      },
      shortcutActivator(
        decodeShortcut(
          settings.focusSearchShortcut,
          ShortcutAction.focusSearch,
        ),
      ): () =>
          _searchFocusNode.requestFocus(),
      shortcutActivator(
        decodeShortcut(settings.togglePinShortcut, ShortcutAction.togglePin),
      ): () {
        final selected = state.selectedItemId;
        if (selected != null) {
          final item = state.visibleItems.firstWhere((it) => it.id == selected);
          ref.read(historyControllerProvider.notifier).togglePinned(item);
        }
      },
      shortcutActivator(
        decodeShortcut(settings.deleteItemShortcut, ShortcutAction.deleteItem),
      ): () {
        final selected = state.selectedItemId;
        if (selected != null) {
          final item = state.visibleItems.firstWhere((it) => it.id == selected);
          _handleDelete(item);
        }
      },
    };

    for (var i = 1; i <= 9; i++) {
      final key = LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + (i - 1));
      shortcutBindings[SingleActivator(
        key,
        meta: Platform.isMacOS,
        control: !Platform.isMacOS,
      )] = () {
        final items = state.visibleItems;
        if (i <= items.length) {
          _handleCopy(items[i - 1]);
        }
      };
    }

    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 780;
    final isMedium = width >= 780 && width < 1120;

    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Focus(
        autofocus: true,
        child: CupertinoPageScaffold(
          child: isCompact
              ? HistoryPaneWidget(
                  compact: true,
                  searchController: _searchController,
                  focusNode: _searchFocusNode,
                  onCopy: _handleCopy,
                  onDelete: _handleDelete,
                  onAddToCollection: _handleAddToCollection,
                  onShowItemActions: _showItemActions,
                  onOpenSidebar: () {
                    showCupertinoModalPopup<void>(
                      context: context,
                      builder: (context) => SizedBox(
                        width: 280,
                        child: SidebarWidget(
                          state: state,
                          collections: collections,
                          onOpenSettings: _openSettings,
                          onCreateCollection: _showCreateCollectionDialog,
                          onDeleteCollection: _handleDeleteCollection,
                        ),
                      ),
                    );
                  },
                )
              : Row(
                  children: [
                    SizedBox(
                      width: isMedium ? 200 : 230,
                      child: SidebarWidget(
                        state: state,
                        collections: collections,
                        reserveWindowControls: Platform.isMacOS,
                        onOpenSettings: _openSettings,
                        onCreateCollection: _showCreateCollectionDialog,
                        onDeleteCollection: _handleDeleteCollection,
                      ),
                    ),
                    ColoredBox(
                      color: resolveColor(context, ClipFlowColors.border),
                      child: const SizedBox(width: 1, height: double.infinity),
                    ),
                    Expanded(
                      flex: 3,
                      child: HistoryPaneWidget(
                        compact: false,
                        searchController: _searchController,
                        focusNode: _searchFocusNode,
                        onCopy: _handleCopy,
                        onDelete: _handleDelete,
                        onAddToCollection: _handleAddToCollection,
                        onShowItemActions: _showItemActions,
                      ),
                    ),
                    if (!isMedium) ...[
                      ColoredBox(
                        color: resolveColor(context, ClipFlowColors.border),
                        child: const SizedBox(
                          width: 1,
                          height: double.infinity,
                        ),
                      ),
                      const Expanded(flex: 2, child: DetailPaneWidget()),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
