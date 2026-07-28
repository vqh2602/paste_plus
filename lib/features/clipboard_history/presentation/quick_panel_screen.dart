import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/ui/cupertino_components.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_item.dart';
import 'widgets/quick_clipboard_card_widget.dart';
import 'widgets/quick_empty_state_widget.dart';
import 'widgets/quick_toolbar_widget.dart';

class QuickPanelScreen extends ConsumerStatefulWidget {
  const QuickPanelScreen({super.key});

  @override
  ConsumerState<QuickPanelScreen> createState() => _QuickPanelScreenState();
}

class _QuickPanelScreenState extends ConsumerState<QuickPanelScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _itemScrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _itemScrollController.dispose();
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
    ref.read(quickPanelModeProvider.notifier).state = false;
    await ref.read(historyControllerProvider.notifier).copy(item);
    await desktop.hideQuickPanel();
    await desktop.pasteToPreviousApplication();
  }

  Future<void> _openMainWindow() async {
    final desktop = ref.read(desktopIntegrationProvider);
    await desktop.showMainWindow();
  }

  void _chooseType(BuildContext context) {
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    showCupertinoModalPopup<ClipboardContentType>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('filter_by_type'.tr),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text('all_types'.tr),
          ),
          ...ClipboardContentType.values.map((type) {
            return CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, type),
              child: Text(type.name.toUpperCase()),
            );
          }),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
      ),
    ).then((type) {
      if (type != null) {
        historyNotifier.filterByType(type);
      }
    });
  }

  void _showItemActions(BuildContext context, ClipboardItem item) {
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(item.content),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pasteItem(item);
            },
            child: Text('copy_and_paste'.tr),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              historyNotifier.togglePinned(item);
            },
            child: Text(item.isPinned ? 'unpin'.tr : 'pin'.tr),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              historyNotifier.delete(item);
            },
            child: Text('delete'.tr),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final collections = ref.watch(collectionsControllerProvider).value ?? const [];
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
      final key = LogicalKeyboardKey(
        LogicalKeyboardKey.digit1.keyId + (i - 1),
      );
      shortcutBindings[SingleActivator(key, meta: Platform.isMacOS, control: !Platform.isMacOS)] = () {
        if (i <= totalItems) {
          _pasteItem(visibleItems[i - 1]);
        }
      };
    }

    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Focus(
        autofocus: true,
        child: CupertinoPageScaffold(
          backgroundColor: resolveColor(context, ClipFlowColors.sidebar),
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
                    ? QuickEmptyStateWidget(hasQuery: state.query.isNotEmpty)
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
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: QuickClipboardCardWidget(
                              item: item,
                              number: index + 1,
                              selected: isSelected,
                              onTap: () {
                                setState(() => _selectedIndex = index);
                                _pasteItem(item);
                              },
                              onPin: () => ref
                                  .read(historyControllerProvider.notifier)
                                  .togglePinned(item),
                              onActions: (ctx) => _showItemActions(ctx, item),
                            ),
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
}
