import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/platform/shortcut_config.dart';
import '../../../core/ui/cached_network_image_widget.dart';
import '../../../core/ui/cupertino_components.dart';
import '../domain/clipboard_content_type.dart';
import '../domain/clipboard_item.dart';
import 'history_controller.dart';

class QuickPanelScreen extends ConsumerStatefulWidget {
  const QuickPanelScreen({super.key});

  @override
  ConsumerState<QuickPanelScreen> createState() => _QuickPanelScreenState();
}

class _QuickPanelScreenState extends ConsumerState<QuickPanelScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _moveSelection(int direction) {
    final items = ref.read(historyControllerProvider).visibleItems;
    if (items.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + direction).clamp(0, items.length - 1).toInt();
    });
    ref
        .read(historyControllerProvider.notifier)
        .select(items[_selectedIndex].id);
    _scrollController.animateTo(
      (_selectedIndex * 306).toDouble(),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _copy(ClipboardItem item) async {
    final controller = ref.read(historyControllerProvider.notifier);
    final desktop = ref.read(desktopIntegrationProvider);
    await controller.copy(item);
    await desktop.hideQuickPanel();
    ref.read(quickPanelModeProvider.notifier).state = false;
    final pasted = await desktop.pasteToPreviousApplication();
    if (!pasted && Platform.isMacOS) {
      final hasPermission = await desktop.checkAccessibilityPermission();
      if (!hasPermission) {
        await desktop.requestAccessibilityPermission();
      }
    }
    unawaited(controller.reload());
  }

  Future<void> _openMainWindow() async {
    ref.read(quickPanelModeProvider.notifier).state = false;
    await ref.read(desktopIntegrationProvider).showMainWindow();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final items = state.visibleItems;
    if (items.isNotEmpty && _selectedIndex >= items.length) {
      _selectedIndex = items.length - 1;
    }

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          _moveSelection(1),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          _moveSelection(-1),
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          ref.read(desktopIntegrationProvider).hideQuickPanel(),
      const SingleActivator(LogicalKeyboardKey.enter): () {
        if (items.isNotEmpty) _copy(items[_selectedIndex]);
      },
      shortcutActivator(
        decodeShortcut(
          settings.focusSearchShortcut,
          ShortcutAction.focusSearch,
        ),
      ): _searchFocus.requestFocus,
      shortcutActivator(
        decodeShortcut(settings.togglePinShortcut, ShortcutAction.togglePin),
      ): () {
        if (items.isNotEmpty) {
          ref
              .read(historyControllerProvider.notifier)
              .togglePinned(items[_selectedIndex]);
        }
      },
      shortcutActivator(
        decodeShortcut(settings.deleteItemShortcut, ShortcutAction.deleteItem),
      ): () {
        if (items.isNotEmpty) {
          ref
              .read(historyControllerProvider.notifier)
              .delete(items[_selectedIndex]);
        }
      },
    };
    final digitKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    for (var index = 0; index < digitKeys.length; index++) {
      void select() {
        if (index < items.length) _copy(items[index]);
      }

      shortcuts[SingleActivator(digitKeys[index], meta: true)] = select;
      shortcuts[SingleActivator(digitKeys[index], control: true)] = select;
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: CupertinoPageScaffold(
          backgroundColor: const Color(0x00000000),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: resolveColor(
                      context,
                      ClipFlowColors.surface,
                    ).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: resolveColor(context, ClipFlowColors.border),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: 0.22),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _QuickToolbar(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        state: state,
                        monitoringEnabled: settings.monitoringEnabled,
                        onOpenMainWindow: _openMainWindow,
                      ),
                      const CupertinoDivider(),
                      Expanded(
                        child: state.isLoading
                            ? const Center(child: CupertinoActivityIndicator())
                            : items.isEmpty
                            ? _QuickEmptyState(hasQuery: state.query.isNotEmpty)
                            : ListView.separated(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  14,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _QuickClipboardCard(
                                    item: item,
                                    number: index + 1,
                                    selected: index == _selectedIndex,
                                    onTap: () {
                                      setState(() => _selectedIndex = index);
                                      ref
                                          .read(
                                            historyControllerProvider.notifier,
                                          )
                                          .select(item.id);
                                      _copy(item);
                                    },
                                    onPin: () => ref
                                        .read(
                                          historyControllerProvider.notifier,
                                        )
                                        .togglePinned(item),
                                    onDelete: () => ref
                                        .read(
                                          historyControllerProvider.notifier,
                                        )
                                        .delete(item),
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

class _QuickToolbar extends ConsumerWidget {
  const _QuickToolbar({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.monitoringEnabled,
    required this.onOpenMainWindow,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ClipboardHistoryState state;
  final bool monitoringEnabled;
  final VoidCallback onOpenMainWindow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    final collectionsState = ref.watch(collectionsControllerProvider);
    final collections = collectionsState.value ?? [];

    final systemTabs = [
      (
        label: 'all'.tr,
        icon: CupertinoIcons.doc_on_clipboard,
        section: HistorySection.all,
      ),
      (
        label: 'pinned'.tr,
        icon: CupertinoIcons.pin,
        section: HistorySection.pinned,
      ),
    ];

    final typeTabs = [
      (
        label: 'images'.tr,
        icon: CupertinoIcons.photo,
        section: HistorySection.images,
      ),
      (
        label: 'links'.tr,
        icon: CupertinoIcons.link,
        section: HistorySection.links,
      ),
      (
        label: 'code'.tr,
        icon: CupertinoIcons.chevron_left_slash_chevron_right,
        section: HistorySection.code,
      ),
    ];

    return SizedBox(
      height: 62,
      child: Row(
        children: [
          const SizedBox(width: 10),
          CupertinoIconControl(
            icon: monitoringEnabled
                ? CupertinoIcons.pause_circle
                : CupertinoIcons.play_circle,
            onPressed: () async {
              final enabled = !monitoringEnabled;
              await ref
                  .read(settingsControllerProvider.notifier)
                  .update(
                    (current) => current.copyWith(monitoringEnabled: enabled),
                  );
              await historyNotifier.setMonitoring(enabled);
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in systemTabs) ...[
                    CupertinoChoicePill(
                      label: tab.label,
                      icon: tab.icon,
                      selected: state.section == tab.section,
                      onPressed: () =>
                          historyNotifier.selectSection(tab.section),
                    ),
                    const SizedBox(width: 6),
                  ],
                  for (final collection in collections) ...[
                    CupertinoChoicePill(
                      label: collection.name,
                      icon: CupertinoIcons.folder,
                      selected: state.section == HistorySection.collection &&
                          state.collectionId == collection.id,
                      onPressed: () => historyNotifier.selectSection(
                        HistorySection.collection,
                        collectionId: collection.id,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  for (final tab in typeTabs) ...[
                    CupertinoChoicePill(
                      label: tab.label,
                      icon: tab.icon,
                      selected: state.section == tab.section,
                      onPressed: () =>
                          historyNotifier.selectSection(tab.section),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (state.typeFilter != null) ...[
                    CupertinoChoicePill(
                      label: _typeName(state.typeFilter!),
                      icon: _typeIcon(state.typeFilter!),
                      selected: true,
                      onPressed: () => historyNotifier.filterByType(null),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 260,
            child: CupertinoSearchTextField(
              key: const Key('quick-panel-search'),
              controller: controller,
              focusNode: focusNode,
              placeholder: 'search_in_clipboard'.tr,
              onChanged: historyNotifier.search,
            ),
          ),
          const SizedBox(width: 6),
          CupertinoIconControl(
            icon: CupertinoIcons.slider_horizontal_3,
            color: state.typeFilter != null
                ? CupertinoTheme.of(context).primaryColor
                : null,
            onPressed: () => _chooseType(context, ref),
          ),
          CupertinoIconControl(
            icon: CupertinoIcons.arrow_up_left_arrow_down_right,
            onPressed: onOpenMainWindow,
          ),
          CupertinoIconControl(
            icon: CupertinoIcons.xmark,
            onPressed: () =>
                ref.read(desktopIntegrationProvider).hideQuickPanel(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Future<void> _chooseType(BuildContext context, WidgetRef ref) async {
    final selected = await showCupertinoModalPopup<ClipboardContentType?>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('all'.tr),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text('all'.tr),
          ),
          for (final type in ClipboardContentType.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, type),
              child: Text(_typeName(type)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, state.typeFilter),
          child: Text('cancel'.tr),
        ),
      ),
    );
    ref.read(historyControllerProvider.notifier).filterByType(selected);
  }
}

class _QuickClipboardCard extends ConsumerWidget {
  const _QuickClipboardCard({
    required this.item,
    required this.number,
    required this.selected,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  final ClipboardItem item;
  final int number;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColor(item.contentType);
    return SizedBox(
      width: 292,
      child: CupertinoPressable(
        onPressed: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: resolveColor(context, ClipFlowColors.surface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? CupertinoTheme.of(context).primaryColor
                  : resolveColor(context, ClipFlowColors.border),
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _typeIcon(item.contentType),
                      color: CupertinoColors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _typeName(item.contentType),
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    CupertinoIconControl(
                      icon: item.isPinned
                          ? CupertinoIcons.pin_fill
                          : CupertinoIcons.pin,
                      color: CupertinoColors.white,
                      size: 16,
                      onPressed: onPin,
                    ),
                    CupertinoIconControl(
                      icon: CupertinoIcons.ellipsis,
                      color: CupertinoColors.white,
                      size: 17,
                      onPressed: () => _actions(context, ref),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child:
                      item.contentType == ClipboardContentType.image
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: (item.imagePath != null &&
                                        File(item.imagePath!).existsSync())
                                    ? Image.file(
                                        File(item.imagePath!),
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        url: item.content,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            if (item.content.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.content,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: ClipFlowColors.secondaryText,
                                ),
                              ),
                            ],
                          ],
                        )
                      : isImageUrl(item.content)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: CachedNetworkImage(
                                  url: item.content,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: ClipFlowColors.secondaryText,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          item.content,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.sourceAppName ?? 'this_device'.tr,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: ClipFlowColors.secondaryText,
                        ),
                      ),
                    ),
                    if (number <= 9)
                      Text(
                        '${Platform.isMacOS ? '⌘' : 'Ctrl+'}$number',
                        style: const TextStyle(fontSize: 11),
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

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
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
            onPressed: () => Navigator.pop(context, 'pin'),
            child: Text(item.isPinned ? 'unpin_item'.tr : 'pin_item'.tr),
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
    } else if (action == 'pin') {
      onPin();
    } else if (action == 'delete') {
      onDelete();
    }
  }
}

class _QuickEmptyState extends StatelessWidget {
  const _QuickEmptyState({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? CupertinoIcons.search : CupertinoIcons.doc_on_clipboard,
            size: 34,
            color: CupertinoTheme.of(context).primaryColor,
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery ? 'no_results_found'.tr : 'clipboard_empty_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _typeName(ClipboardContentType type) => switch (type) {
  ClipboardContentType.text => 'text'.tr,
  ClipboardContentType.url => 'links'.tr,
  ClipboardContentType.email => 'email'.tr,
  ClipboardContentType.phone => 'phone'.tr,
  ClipboardContentType.code => 'code'.tr,
  ClipboardContentType.color => 'color'.tr,
  ClipboardContentType.json => 'JSON',
  ClipboardContentType.file => 'files'.tr,
  ClipboardContentType.image => 'images'.tr,
};

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

Color _typeColor(ClipboardContentType type) => switch (type) {
  ClipboardContentType.url => const Color(0xFF0A84FF),
  ClipboardContentType.code ||
  ClipboardContentType.json => const Color(0xFF7048D8),
  ClipboardContentType.image => const Color(0xFFFF9F0A),
  ClipboardContentType.color => const Color(0xFFFF375F),
  ClipboardContentType.email ||
  ClipboardContentType.phone => const Color(0xFF28A745),
  ClipboardContentType.file => const Color(0xFF32ADE6),
  ClipboardContentType.text => const Color(0xFF5E5CE6),
};
