import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/ui/cupertino_components.dart';
import '../domain/clipboard_item.dart';
import 'widgets/clipboard_action_menu.dart';
import 'widgets/clipboard_edit_dialog.dart';
import 'widgets/clipboard_preview_dialog.dart';
import 'widgets/clipboard_share.dart';
import 'widgets/content_type_filter_sheet.dart';
import 'widgets/note_edit_dialog.dart';
import 'widgets/quick_clipboard_card_widget.dart';
import 'widgets/quick_empty_state_widget.dart';
import 'widgets/quick_toolbar_widget.dart';

class QuickPanelScreen extends ConsumerStatefulWidget {
  const QuickPanelScreen({super.key});

  @override
  ConsumerState<QuickPanelScreen> createState() => _QuickPanelScreenState();
}

class _QuickPanelScreenState extends ConsumerState<QuickPanelScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _itemScrollController = ScrollController();
  late final AnimationController _entranceController;
  late final Animation<double> _panelOpacity;
  late final Animation<double> _panelScale;
  late final Animation<Offset> _panelPosition;
  bool _entranceStarted = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    _panelOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.68, curve: Curves.easeOutCubic),
    );
    _panelScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _panelPosition =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _entranceController.value = 1;
    } else {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _itemScrollController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_itemScrollController.hasClients) return;
    const cardWidth = 300.0;
    final targetOffset = index * cardWidth;
    _itemScrollController.animateTo(
      targetOffset.clamp(0, _itemScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _moveSelection(int delta, int totalItems) {
    if (totalItems == 0) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, totalItems - 1);
    });
    _scrollToIndex(_selectedIndex);
  }

  Future<void> _pasteItem(ClipboardItem item) async {
    final desktop = ref.read(desktopIntegrationProvider);
    // The quick panel is recreated whenever it is opened. Clear the provider
    // query as well as this controller so a previous search cannot leave a
    // filtered list behind under an empty search field on the next opening.
    _searchController.clear();
    ref.read(historyControllerProvider.notifier).search('');
    if (mounted) setState(() => _selectedIndex = 0);
    ref.read(quickPanelModeProvider.notifier).state = false;
    await ref.read(historyControllerProvider.notifier).copy(item);
    await desktop.hideQuickPanel();
    await desktop.pasteToPreviousApplication();
  }

  Future<void> _pasteItemAsPlainText(ClipboardItem item) async {
    final desktop = ref.read(desktopIntegrationProvider);
    _searchController.clear();
    ref.read(historyControllerProvider.notifier).search('');
    if (mounted) setState(() => _selectedIndex = 0);
    final copied = await ref
        .read(historyControllerProvider.notifier)
        .copyAsPlainText(item);
    if (!copied) return;
    ref.read(quickPanelModeProvider.notifier).state = false;
    await desktop.hideQuickPanel();
    await desktop.pasteToPreviousApplication();
  }

  Future<void> _openMainWindow() async {
    final desktop = ref.read(desktopIntegrationProvider);
    await desktop.showMainWindow();
  }

  Future<void> _chooseType(BuildContext context) async {
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final selected = await showContentTypeFilterSheet(
      context,
      selectedTypes: ref.read(historyControllerProvider).typeFilters,
    );
    if (selected != null) await historyNotifier.setTypeFilters(selected);
  }

  Future<void> _handleAddToCollection(ClipboardItem item) async {
    final collections =
        ref.read(collectionsControllerProvider).value ?? const [];
    if (collections.isEmpty) {
      showCupertinoNotice(context, context.l10n.no_collections);
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

    if (collection != null) {
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

  void _showItemActions(BuildContext context, ClipboardItem item) async {
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final action = await showClipboardActionMenu(
      context: context,
      item: item,
      copyAction: 'copy_paste',
      copyLabel: context.l10n.copy_and_paste,
    );

    if (!context.mounted || action == null) return;

    if (action == 'open') {
      final url = openableClipboardUrl(item);
      if (url != null) {
        await ref.read(desktopIntegrationProvider).openUrl(url);
      }
    } else if (action == 'paste_plain') {
      await _pasteItemAsPlainText(item);
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
    } else if (action == 'copy_paste') {
      _pasteItem(item);
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
      _handleAddToCollection(item);
    } else if (action == 'delete') {
      historyNotifier.delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final collections =
        ref.watch(collectionsControllerProvider).value ?? const [];
    final settings = ref.watch(settingsControllerProvider);
    final visibleItems = state.visibleItems;
    final totalItems = visibleItems.length;

    if (_selectedIndex >= totalItems && totalItems > 0) {
      _selectedIndex = totalItems - 1;
    }

    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): () {
        ref.read(desktopIntegrationProvider).hideQuickPanel();
      },
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
        _moveSelection(-1, totalItems);
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight): () {
        _moveSelection(1, totalItems);
      },
      const SingleActivator(LogicalKeyboardKey.enter): () {
        if (visibleItems.isNotEmpty && _selectedIndex < totalItems) {
          _pasteItem(visibleItems[_selectedIndex]);
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
        if (i <= totalItems) {
          _pasteItem(visibleItems[i - 1]);
        }
      };
    }

    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Focus(
        autofocus: true,
        child: FadeTransition(
          opacity: _panelOpacity,
          child: SlideTransition(
            position: _panelPosition,
            child: ScaleTransition(
              scale: _panelScale,
              alignment: Alignment.bottomCenter,
              child: CupertinoPageScaffold(
                backgroundColor: resolveColor(context, ClipFlowColors.sidebar),
                child: SafeArea(
                  child: Column(
                    children: [
                      QuickToolbarWidget(
                        state: state,
                        collections: collections,
                        monitoringEnabled: settings.monitoringEnabled,
                        searchController: _searchController,
                        searchFocusNode: _searchFocusNode,
                        onOpenMainWindow: _openMainWindow,
                        onChooseType: _chooseType,
                      ),
                      const CupertinoDivider(),
                      Expanded(
                        child: totalItems == 0
                            ? QuickEmptyStateWidget(
                                hasQuery: state.query.isNotEmpty,
                              )
                            : ListView.builder(
                                controller: _itemScrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                itemCount: totalItems,
                                itemBuilder: (context, index) {
                                  final item = visibleItems[index];
                                  final isSelected = index == _selectedIndex;
                                  return _AnimatedQuickPanelItem(
                                    key: ValueKey('quick-animated-${item.id}'),
                                    index: index,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: QuickClipboardCardWidget(
                                        item: item,
                                        number: index + 1,
                                        selected: isSelected,
                                        onTap: () {
                                          setState(
                                            () => _selectedIndex = index,
                                          );
                                          _pasteItem(item);
                                        },
                                        onPin: () async {
                                          final wasPinned = item.isPinned;
                                          await ref
                                              .read(
                                                historyControllerProvider
                                                    .notifier,
                                              )
                                              .togglePinned(item);
                                          if (!context.mounted) return;
                                          showCupertinoNotice(
                                            context,
                                            wasPinned
                                                ? context.l10n.unpin
                                                : context.l10n.pinned,
                                          );
                                        },
                                        onActions: (ctx) =>
                                            _showItemActions(ctx, item),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedQuickPanelItem extends StatefulWidget {
  const _AnimatedQuickPanelItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_AnimatedQuickPanelItem> createState() =>
      _AnimatedQuickPanelItemState();
}

class _AnimatedQuickPanelItemState extends State<_AnimatedQuickPanelItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _position;
  Timer? _timer;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.62, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(
      begin: 0.9,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _position = Tween<Offset>(
      begin: const Offset(0.12, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 24 + (widget.index * 16).clamp(0, 72));
    _timer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _position,
          child: ScaleTransition(scale: _scale, child: widget.child),
        ),
      ),
    );
  }
}
