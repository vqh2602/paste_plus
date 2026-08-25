import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/platform/shortcut_config.dart';
import '../../../core/services/update_service.dart';
import '../../../core/ui/app_window_controls.dart';
import '../../../core/ui/cupertino_components.dart';
import '../../ai/presentation/ai_chat_screen.dart';
import '../domain/clipboard_item.dart';
import '../domain/smart_text_tools.dart';
import 'history_controller.dart';
import 'quick_panel_screen.dart';
import 'widgets/clipboard_action_menu.dart';
import 'widgets/clipboard_edit_dialog.dart';
import 'widgets/clipboard_preview_dialog.dart';
import 'widgets/clipboard_share.dart';
import 'widgets/detail_pane_widget.dart';
import 'widgets/history_pane_widget.dart';
import 'widgets/note_edit_dialog.dart';
import 'widgets/search_syntax_field.dart';
import '../../vault/presentation/vault_dialogs.dart';
import 'widgets/mobile_sidebar_sheet.dart';
import 'widgets/sidebar_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = SearchSyntaxTextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.checkAutoUpdate(context, ref);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSettings() {
    unawaited(_leaveVaultAndOpenSettings());
  }

  Future<void> _leaveVaultAndOpenSettings() async {
    final history = ref.read(historyControllerProvider);
    if (history.section == HistorySection.collection &&
        history.collectionId == ClipboardCollection.vaultId) {
      await ref
          .read(historyControllerProvider.notifier)
          .selectSection(HistorySection.all);
      if (!mounted) return;
    }
    context.push('/settings');
  }

  void _handleCopy(ClipboardItem item) {
    ref.read(historyControllerProvider.notifier).copy(item);
  }

  Future<void> _handleDelete(ClipboardItem item) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.delete_item_title),
        content: Text(context.l10n.delete_item_confirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
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
        title: Text(context.l10n.new_collection),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: context.l10n.collection_name,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.create),
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
        title: Text(context.l10n.delete_collection),
        content: Text(context.l10n.delete_collection_confirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
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
    final settings = ref.read(settingsControllerProvider);
    final collections =
        (ref.read(collectionsControllerProvider).value ?? const [])
            .where((collection) => !collection.isVault || settings.vaultEnabled)
            .toList(growable: false);
    if (collections.isEmpty) {
      await _showCreateCollectionDialog();
      return;
    }

    final collection = await showCupertinoModalPopup<ClipboardCollection>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.add_to_collection),
        actions: collections.map((col) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(col),
            child: Text(col.name),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ),
    );

    if (!mounted) return;
    if (collection != null) {
      if (collection.isVault && !await ensureVaultUnlocked(context, ref)) {
        return;
      }
      await ref
          .read(historyControllerProvider.notifier)
          .addToCollection(item.id, collection.id);
      if (!mounted) return;
      showCupertinoNotice(
        context,
        context.l10n.added_to_collection_named.replaceAll(
          '@name',
          collection.name,
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
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final history = ref.read(historyControllerProvider);
    final action = await showClipboardActionMenu(
      context: context,
      item: item,
      protectVaultContent:
          history.section == HistorySection.collection &&
          history.collectionId == ClipboardCollection.vaultId,
    );

    if (!context.mounted || action == null) return;

    if (action == 'open') {
      final url = openableClipboardUrl(item);
      if (url != null) {
        await ref.read(desktopIntegrationProvider).openUrl(url);
      }
    } else if (action == 'paste_plain') {
      final copied = await historyNotifier.copyAsPlainText(item);
      if (copied) {
        final desktop = ref.read(desktopIntegrationProvider);
        await desktop.hideQuickPanel();
        await desktop.pasteToPreviousApplication();
      }
    } else if (action == 'text_transform') {
      final transform = await showTextTransformMenu(context: context);
      if (!context.mounted || transform == null) return;
      try {
        final result = SmartTextTools.transform(item.content, transform);
        await historyNotifier.addTextItem(result);
        if (context.mounted) {
          showCupertinoNotice(context, context.l10n.transformed_copied);
        }
      } on TextTransformException {
        if (context.mounted) {
          showCupertinoNotice(context, context.l10n.transform_failed);
        }
      }
    } else if (action == 'link_cleaner') {
      try {
        final result = SmartTextTools.cleanUrl(item.content);
        await historyNotifier.addTextItem(result);
        if (context.mounted) {
          showCupertinoNotice(context, context.l10n.link_cleaned);
        }
      } on TextTransformException {
        if (context.mounted) {
          showCupertinoNotice(context, context.l10n.transform_failed);
        }
      }
    } else if (action == 'share') {
      final shared = await shareClipboardItem(context, item);
      if (!shared && context.mounted) {
        showCupertinoNotice(context, context.l10n.share_failed);
      }
    } else if (action == 'preview') {
      await showClipboardPreviewDialog(
        context: context,
        item: item,
        onCopy: () => historyNotifier.copy(item),
      );
    } else if (action == 'edit') {
      final updated = await showClipboardEditDialog(context, ref, item);
      if (updated && context.mounted) {
        showCupertinoNotice(context, context.l10n.clipboard_updated);
      }
    } else if (action == 'note') {
      await showNoteEditDialog(context, ref, item);
    } else if (action == 'ask_ai') {
      ref.read(aiControllerProvider.notifier).setClipboardContext(item);
      await ref.read(desktopIntegrationProvider).showAiWindow();
    } else if (action == 'ocr') {
      final text = await historyNotifier.performOcr(item);
      if (context.mounted) {
        showCupertinoNotice(
          context,
          text != null ? context.l10n.ocr_success : context.l10n.ocr_empty,
        );
      }
    } else if (action == 'cloud_upload') {
      final url = await historyNotifier.uploadImageToCloud(item);
      if (context.mounted) {
        showCupertinoNotice(
          context,
          url != null
              ? context.l10n.upload_cloud_success
              : context.l10n.upload_cloud_failed,
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
          text != null
              ? context.l10n.translate_success
              : context.l10n.translate_failed,
        );
      }
    } else if (action == 'copy') {
      historyNotifier.copy(item);
    } else if (action == 'pin') {
      final wasPinned = item.isPinned;
      await historyNotifier.togglePinned(item);
      if (context.mounted) {
        showCupertinoNotice(
          context,
          wasPinned ? context.l10n.unpin : context.l10n.pinned,
        );
      }
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
        (ref.watch(collectionsControllerProvider).value ?? const [])
            .where((collection) => !collection.isVault || settings.vaultEnabled)
            .toList(growable: false);

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
      ): () async {
        final selected = state.selectedItemId;
        if (selected != null) {
          final item = state.visibleItems.firstWhere((it) => it.id == selected);
          final wasPinned = item.isPinned;
          await ref.read(historyControllerProvider.notifier).togglePinned(item);
          if (!context.mounted) return;
          showCupertinoNotice(
            context,
            wasPinned ? context.l10n.unpin : context.l10n.pinned,
          );
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
          child: SafeArea(
            child: Column(
              children: [
                const AppWindowHeader(),
                Expanded(
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
                              builder: (context) => MobileSidebarSheet(
                                state: state,
                                collections: collections,
                                onOpenSettings: _openSettings,
                                onCreateCollection: _showCreateCollectionDialog,
                                onDeleteCollection: _handleDeleteCollection,
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
                              color: resolveColor(
                                context,
                                ClipFlowColors.border,
                              ),
                              child: const SizedBox(
                                width: 1,
                                height: double.infinity,
                              ),
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
                                color: resolveColor(
                                  context,
                                  ClipFlowColors.border,
                                ),
                                child: const SizedBox(
                                  width: 1,
                                  height: double.infinity,
                                ),
                              ),
                              const Expanded(
                                flex: 2,
                                child: DetailPaneWidget(),
                              ),
                            ],
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
}
