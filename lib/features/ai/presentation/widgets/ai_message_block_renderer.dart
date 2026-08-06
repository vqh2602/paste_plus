import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/localization_extensions.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../clipboard_history/domain/clipboard_content_type.dart';
import '../../../clipboard_history/domain/clipboard_item.dart';
import '../../domain/ai_agent_protocol.dart';
import 'ai_markdown_content_widget.dart';

class AiMessageBlockRenderer extends StatelessWidget {
  const AiMessageBlockRenderer({required this.block, this.onCopy, super.key});
  final AiMessageBlock block;

  /// Copy handler for text blocks, so markdown/code blocks keep the same
  /// copy affordance the chat tile has always offered.
  final ValueChanged<String>? onCopy;

  @override
  Widget build(BuildContext context) => switch (block) {
    AiTextBlock(:final text) => AiMarkdownContentWidget(
      content: text,
      onCopy: (value) {
        onCopy?.call(value);
        if (onCopy == null) {
          Clipboard.setData(ClipboardData(text: value));
        }
      },
    ),
    AiLocalizedTitleBlock(:final title) => Text(
      aiMessageTitleText(context, title),
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    AiClipboardListBlock(:final resultSetId, :final items, :final title) =>
      AiClipboardResultList(
        resultSetId: resultSetId,
        items: items,
        title: title,
      ),
    AiClipboardGridBlock(
      :final resultSetId,
      :final items,
      :final title,
      :final crossAxisCount,
    ) =>
      AiClipboardImageGrid(
        resultSetId: resultSetId,
        items: items,
        title: title,
        crossAxisCount: crossAxisCount,
      ),
    AiUrlListBlock(
      :final resultSetId,
      :final items,
      :final urlsByClipboardId,
      :final title,
    ) =>
      AiClipboardUrlList(
        resultSetId: resultSetId,
        items: items,
        urlsByClipboardId: urlsByClipboardId,
        title: title,
      ),
    AiCollectionListBlock(:final collections) => AiCollectionResultList(
      collections: collections,
    ),
    AiActionReceiptBlock(:final receipt) => AiActionReceiptView(
      receipt: receipt,
    ),
    AiErrorBlock(:final localizedMessageKey) => AiErrorView(
      messageKey: localizedMessageKey,
    ),
  };
}

/// Resolves an agent-produced semantic title into the active app locale.
String aiMessageTitleText(BuildContext context, AiMessageTitle title) {
  final l10n = context.l10n;
  final template = switch (title.kind) {
    AiMessageTitleKind.resultCount => l10n.ai_result_count,
    AiMessageTitleKind.urlResultCount => l10n.ai_result_url_count,
    AiMessageTitleKind.imageResultCount => l10n.ai_result_image_count,
    AiMessageTitleKind.empty => l10n.ai_result_empty,
    AiMessageTitleKind.savedResultSet => l10n.ai_saved_result_set,
    AiMessageTitleKind.imageNeedsVisionModel =>
      l10n.ai_image_needs_vision_model,
  };
  return template.replaceAll('@count', '${title.count}');
}

/// Keeps long agent results from pushing the whole conversation off screen.
///
/// Results scroll inside their own bounded viewport instead of being pinned
/// out into the chat transcript.
class AiResultViewport extends StatelessWidget {
  const AiResultViewport({
    required this.child,
    this.maxHeight = 320,
    super.key,
  });

  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CupertinoScrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AiClipboardResultList extends ConsumerWidget {
  const AiClipboardResultList({
    required this.resultSetId,
    required this.items,
    this.title,
    super.key,
  });
  final String resultSetId;
  final List<ClipboardItem> items;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedIds = ref.watch(deletedItemIdsProvider);
    final visibleItems =
        items.where((item) => !deletedIds.contains(item.id)).toList();
    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title!),
        const SizedBox(height: 8),
        AiResultViewport(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < visibleItems.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                _AiClipboardResultCard(item: visibleItems[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AiClipboardImageGrid extends ConsumerWidget {
  const AiClipboardImageGrid({
    required this.resultSetId,
    required this.items,
    this.title,
    this.crossAxisCount = 3,
    super.key,
  });
  final String resultSetId;
  final List<ClipboardItem> items;
  final String? title;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedIds = ref.watch(deletedItemIdsProvider);
    final visibleItems =
        items.where((item) => !deletedIds.contains(item.id)).toList();
    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title!),
        const SizedBox(height: 8),
        AiResultViewport(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleItems.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              // Tall enough for the thumbnail plus a full action row: a
              // shorter cell overflowed and clipped the buttons, which made
              // them impossible to tap.
              mainAxisExtent: 168,
            ),
            itemBuilder: (_, index) =>
                _AiClipboardResultCard(item: visibleItems[index], imageFirst: true),
          ),
        ),
      ],
    );
  }
}

class AiClipboardUrlList extends ConsumerWidget {
  const AiClipboardUrlList({
    required this.resultSetId,
    required this.items,
    required this.urlsByClipboardId,
    this.title,
    super.key,
  });
  final String resultSetId;
  final List<ClipboardItem> items;
  final Map<String, List<String>> urlsByClipboardId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedIds = ref.watch(deletedItemIdsProvider);
    final visibleItems =
        items.where((item) => !deletedIds.contains(item.id)).toList();
    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title!),
        const SizedBox(height: 8),
        AiResultViewport(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < visibleItems.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                _AiClipboardResultCard(
                  item: visibleItems[index],
                  highlightedUrls:
                      urlsByClipboardId[visibleItems[index].id] ?? const [],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AiCollectionResultList extends StatelessWidget {
  const AiCollectionResultList({required this.collections, super.key});
  final List<ClipboardCollection> collections;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final collection in collections)
        Row(
          children: [
            const Icon(CupertinoIcons.folder, size: 16),
            const SizedBox(width: 8),
            Text(collection.name),
          ],
        ),
    ],
  );
}

class AiActionReceiptView extends StatelessWidget {
  const AiActionReceiptView({required this.receipt, super.key});
  final AiActionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final template = switch (receipt.code) {
      'clipboard.pin.success' => context.l10n.ai_receipt_pin,
      'clipboard.unpin.success' => context.l10n.ai_receipt_unpin,
      'clipboard.delete.success' => context.l10n.ai_receipt_delete,
      'clipboard.collection.add.success' => context.l10n.ai_receipt_collection,
      _ => context.l10n.ai_receipt_generic,
    };
    final message = template.replaceAll('@count', '${receipt.affectedCount}');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: CupertinoColors.systemGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class AiErrorView extends StatelessWidget {
  const AiErrorView({required this.messageKey, super.key});
  final String messageKey;

  @override
  Widget build(BuildContext context) => Text(
    aiErrorText(context, messageKey),
    style: const TextStyle(color: CupertinoColors.systemRed),
  );
}

/// Maps an agent error code to a localized, user-safe message.
String aiErrorText(BuildContext context, String code) => switch (code) {
  'clipboard.reference.not_found' ||
  'clipboard.reference.invalid' => context.l10n.ai_error_reference_not_found,
  'collection.not_found' => context.l10n.ai_error_collection_not_found,
  'collection.name.required' => context.l10n.ai_error_collection_name_required,
  _ => context.l10n.ai_error_generic,
};

class _AiClipboardResultCard extends ConsumerWidget {
  const _AiClipboardResultCard({
    required this.item,
    this.imageFirst = false,
    this.highlightedUrls = const [],
  });
  final ClipboardItem item;
  final bool imageFirst;
  final List<String> highlightedUrls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The block holds an immutable snapshot from when the agent answered.
    // Watch live history so pin/delete are reflected here instead of looking
    // like the button did nothing.
    final live = ref
        .watch(historyControllerProvider)
        .items
        .where((candidate) => candidate.id == this.item.id)
        .firstOrNull;
    final item = live ?? this.item;
    final imageFile = item.imagePath == null ? null : File(item.imagePath!);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageFirst && imageFile?.existsSync() == true)
            // Flexible (not Expanded) so the action row below always keeps its
            // space even when the thumbnail wants every pixel.
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  imageFile!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Text(
              item.content.isEmpty
                  ? '[${item.contentType.name}]'
                  : item.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily:
                    item.contentType == ClipboardContentType.code ||
                        item.contentType == ClipboardContentType.json
                    ? 'monospace'
                    : null,
              ),
            ),
          for (final url in highlightedUrls) ...[
            const SizedBox(height: 5),
            Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CupertinoColors.activeBlue,
                decoration: TextDecoration.underline,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // A horizontal scroller keeps every action reachable in narrow grid
          // cells; a Wrap would silently clip the row and swallow taps.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoIconControl(
                  icon: CupertinoIcons.doc_on_doc,
                  size: 14,
                  tooltip: context.l10n.copy,
                  onPressed: () async {
                    await ref
                        .read(historyControllerProvider.notifier)
                        .copy(item);
                    if (context.mounted) {
                      showCupertinoNotice(context, context.l10n.copied);
                    }
                  },
                ),
                CupertinoIconControl(
                  icon: CupertinoIcons.arrow_right_square,
                  size: 14,
                  tooltip: context.l10n.paste_all,
                  onPressed: () async {
                    await ref
                        .read(historyControllerProvider.notifier)
                        .copy(item);
                    await ref
                        .read(desktopIntegrationProvider)
                        .pasteToPreviousApplication();
                    if (context.mounted) {
                      showCupertinoNotice(context, context.l10n.copied);
                    }
                  },
                ),
                CupertinoIconControl(
                  icon: item.isPinned
                      ? CupertinoIcons.pin_fill
                      : CupertinoIcons.pin,
                  size: 14,
                  onPressed: () async {
                    final wasPinned = item.isPinned;
                    await ref
                        .read(historyControllerProvider.notifier)
                        .togglePinned(item);
                    if (context.mounted) {
                      showCupertinoNotice(
                        context,
                        wasPinned ? context.l10n.unpin : context.l10n.pinned,
                      );
                    }
                  },
                ),
                CupertinoIconControl(
                  icon: CupertinoIcons.folder_badge_plus,
                  size: 14,
                  onPressed: () => _addToCollection(context, ref),
                ),
                if (item.imagePath?.isNotEmpty == true)
                  CupertinoIconControl(
                    icon: CupertinoIcons.folder_open,
                    size: 14,
                    onPressed: () => _revealFile(context),
                  ),
                CupertinoIconControl(
                  icon: CupertinoIcons.delete,
                  size: 14,
                  onPressed: () async {
                    await ref
                        .read(historyControllerProvider.notifier)
                        .delete(item);
                    ref
                        .read(deletedItemIdsProvider.notifier)
                        .markDeleted(item.id);
                    if (context.mounted) {
                      showCupertinoNotice(context, context.l10n.item_deleted);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCollection(BuildContext context, WidgetRef ref) async {
    final collections =
        ref.read(collectionsControllerProvider).value ?? const [];
    final selected = await showCupertinoModalPopup<ClipboardCollection>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(context.l10n.add_to_collection),
        actions: [
          for (final collection in collections)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context, collection),
              child: Text(collection.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
    if (selected != null) {
      await ref
          .read(historyControllerProvider.notifier)
          .addToCollection(item.id, selected.id);
      if (context.mounted) {
        showCupertinoNotice(context, context.l10n.added_to_collection);
      }
    }
  }

  Future<void> _revealFile(BuildContext context) async {
    final path = item.imagePath;
    if (path == null || path.isEmpty) return;
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', path]);
    } else {
      await Process.run('xdg-open', [File(path).parent.path]);
    }
    if (context.mounted) {
      showCupertinoNotice(context, context.l10n.copied);
    }
  }
}
