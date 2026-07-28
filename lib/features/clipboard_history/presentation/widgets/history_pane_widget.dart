import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';
import '../history_controller.dart';
import 'clipboard_card_widget.dart';
import 'content_type_filter_sheet.dart';

class HistoryPaneWidget extends ConsumerWidget {
  const HistoryPaneWidget({
    super.key,
    required this.compact,
    required this.searchController,
    required this.focusNode,
    required this.onCopy,
    required this.onDelete,
    required this.onAddToCollection,
    required this.onShowItemActions,
    this.onOpenSidebar,
  });

  final bool compact;
  final TextEditingController searchController;
  final FocusNode focusNode;
  final ValueChanged<ClipboardItem> onCopy;
  final ValueChanged<ClipboardItem> onDelete;
  final ValueChanged<ClipboardItem> onAddToCollection;
  final void Function(
    BuildContext context,
    WidgetRef ref,
    ClipboardItem item,
    ValueChanged<ClipboardItem> onDelete,
    ValueChanged<ClipboardItem> onAddToCollection,
  )
  onShowItemActions;
  final VoidCallback? onOpenSidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyControllerProvider);
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);
    final items = state.visibleItems;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 22,
            14,
            compact ? 12 : 22,
            12,
          ),
          child: Row(
            children: [
              if (compact && onOpenSidebar != null) ...[
                CupertinoIconControl(
                  icon: CupertinoIcons.sidebar_left,
                  onPressed: onOpenSidebar!,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: CupertinoSearchTextField(
                  key: const Key('history-search'),
                  controller: searchController,
                  focusNode: focusNode,
                  placeholder: 'search_history_placeholder'.tr,
                  onChanged: historyNotifier.search,
                ),
              ),
              const SizedBox(width: 8),
              if (settings.aiEnabled) ...[
                CupertinoIconControl(
                  key: const Key('history-ai-button'),
                  icon: CupertinoIcons.sparkles,
                  color: CupertinoColors.activeBlue,
                  onPressed: () async {
                    final selectedItem =
                        state.hasExplicitSelection &&
                            state.visibleItems.isNotEmpty
                        ? state.visibleItems.firstWhere(
                            (item) => item.id == state.selectedItemId,
                            orElse: () => state.visibleItems.first,
                          )
                        : null;
                    ref
                        .read(aiControllerProvider.notifier)
                        .setClipboardContext(selectedItem);
                    await ref.read(desktopIntegrationProvider).showAiWindow();
                  },
                ),
                const SizedBox(width: 2),
              ],
              CupertinoIconControl(
                key: const Key('history-filter-button'),
                icon: CupertinoIcons.slider_horizontal_3,
                color: state.typeFilters.isNotEmpty
                    ? CupertinoTheme.of(context).primaryColor
                    : null,
                onPressed: () =>
                    _chooseType(context, historyNotifier, state.typeFilters),
              ),
            ],
          ),
        ),
        const CupertinoDivider(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            reverseDuration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: state.isLoading
                ? const Center(
                    key: Key('history-loading'),
                    child: CupertinoActivityIndicator(),
                  )
                : items.isEmpty
                ? EmptyStateWidget(
                    key: ValueKey('history-empty-${state.query}'),
                    hasQuery: state.query.isNotEmpty,
                  )
                : ListView.builder(
                    key: ValueKey(
                      'list-${state.section}-${state.typeFilters}-${state.query}',
                    ),
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 22,
                      12,
                      compact ? 12 : 22,
                      24,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _AnimatedHistoryItem(
                        key: ValueKey('animated-${item.id}'),
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ClipboardCardWidget(
                            key: const Key('clipboard-item'),
                            item: item,
                            selected: item.id == state.selectedItemId,
                            onTap: () {
                              historyNotifier.select(item.id);
                              onCopy(item);
                            },
                            onCopy: onCopy,
                            onDelete: onDelete,
                            onAddToCollection: onAddToCollection,
                            onShowItemActions: onShowItemActions,
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

  Future<void> _chooseType(
    BuildContext context,
    ClipboardHistoryController notifier,
    Set<ClipboardContentType> currentTypes,
  ) async {
    final selected = await showContentTypeFilterSheet(
      context,
      selectedTypes: currentTypes,
    );
    if (selected != null) await notifier.setTypeFilters(selected);
  }
}

class _AnimatedHistoryItem extends StatefulWidget {
  const _AnimatedHistoryItem({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_AnimatedHistoryItem> createState() => _AnimatedHistoryItemState();
}

class _AnimatedHistoryItemState extends State<_AnimatedHistoryItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _position;
  Timer? _startTimer;
  bool _animationScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.68, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.965, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 1, curve: Curves.easeOutBack),
      ),
    );
    _position = Tween<Offset>(
      begin: Offset(widget.index.isEven ? -0.018 : 0.018, 0.075),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_animationScheduled) return;
    _animationScheduled = true;

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
      return;
    }

    // Stagger the visible cards, but cap the wait so long lists stay snappy.
    final delay = Duration(milliseconds: (widget.index * 36).clamp(0, 180));
    _startTimer = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
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
          child: ScaleTransition(
            scale: _scale,
            alignment: Alignment.topCenter,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key, required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? CupertinoIcons.search : CupertinoIcons.doc_on_clipboard,
            size: 42,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery ? 'no_results_found'.tr : 'clipboard_empty_title'.tr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasQuery
                ? 'try_different_search'.tr
                : 'clipboard_empty_subtitle'.tr,
            style: TextStyle(
              fontSize: 13,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
