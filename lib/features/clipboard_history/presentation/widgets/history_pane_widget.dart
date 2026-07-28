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
          child: state.isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : items.isEmpty
              ? EmptyStateWidget(hasQuery: state.query.isNotEmpty)
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
                    return Padding(
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
                    );
                  },
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
