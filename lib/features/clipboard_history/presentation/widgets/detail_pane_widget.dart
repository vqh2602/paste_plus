import 'package:clipflow/core/localization/localization_extensions.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../../core/ui/image_zoom_viewer.dart';
import '../../../../core/utils/color_parser.dart';
import '../../../ai/domain/ai_feature_action.dart';
import '../../../ai/domain/ai_feature_request.dart';
import '../../../ai/localization/ai_locale_spec.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';

import 'note_edit_dialog.dart';

class DetailPaneWidget extends ConsumerStatefulWidget {
  const DetailPaneWidget({super.key});

  @override
  ConsumerState<DetailPaneWidget> createState() => _DetailPaneWidgetState();
}

class _DetailPaneWidgetState extends ConsumerState<DetailPaneWidget> {
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
        showCupertinoNotice(context, context.l10n.ocr_success);
      } else {
        showCupertinoNotice(context, context.l10n.ocr_empty);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleTranslate(ClipboardItem item) async {
    final settings = ref.read(settingsControllerProvider);
    setState(() => _isProcessing = true);
    try {
      final targetLocaleTag = AiLanguageRegistry.normalizeTag(
        settings.targetTranslationLanguage,
      );
      ref.read(aiControllerProvider.notifier).setClipboardContext(item);
      await ref.read(desktopIntegrationProvider).showAiWindow();
      await ref
          .read(aiControllerProvider.notifier)
          .sendUserMessage(
            'Translate the clipboard content to $targetLocaleTag.',
            featureGroup: AiFeatureGroup.translate,
            featureRequest: AiTranslateRequest(
              targetLocaleTag: targetLocaleTag,
            ),
            selectedOption: targetLocaleTag,
            contextItem: item,
          );
      if (!mounted) return;
      showCupertinoNotice(context, context.l10n.translate_success);
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
        showCupertinoNotice(context, context.l10n.upload_cloud_success);
      } else {
        showCupertinoNotice(context, context.l10n.upload_cloud_failed);
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
    final parsedColor = item?.contentType == ClipboardContentType.color
        ? ColorParser.parse(item!.content)
        : null;

    if (item == null) {
      return Center(child: Text(context.l10n.select_item_to_view));
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
                          ClipboardImagePreviewWidget(
                            path: item.imagePath ?? item.content,
                            height: 260,
                            item: item,
                          ),
                          if (item.content.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              item.content,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: resolveColor(
                                  context,
                                  ClipFlowColors.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : isOnlineImage
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipboardImagePreviewWidget(
                            path: item.content,
                            height: 260,
                            item: item,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.content,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: resolveColor(
                                context,
                                ClipFlowColors.secondaryText,
                              ),
                            ),
                          ),
                        ],
                      )
                    : parsedColor != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 200,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: parsedColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: resolveColor(
                                  context,
                                  ClipFlowColors.border,
                                ),
                                width: 1.0,
                              ),
                            ),
                          ),
                          HighlightedText(
                            text: item.content,
                            query: state.query,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color: resolveColor(
                                context,
                                ClipFlowColors.secondaryText,
                              ),
                              fontFamily: 'monospace',
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
                          decoration:
                              item.contentType == ClipboardContentType.url
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor:
                              item.contentType == ClipboardContentType.url
                              ? CupertinoColors.activeBlue.withValues(
                                  alpha: 0.4,
                                )
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
            if (item.note != null && item.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: resolveColor(context, ClipFlowColors.surface),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: resolveColor(context, ClipFlowColors.border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.pencil,
                          size: 13,
                          color: resolveColor(
                            context,
                            ClipFlowColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          context.l10n.note,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: resolveColor(
                              context,
                              ClipFlowColors.secondaryText,
                            ),
                          ),
                        ),
                        const Spacer(),
                        CupertinoPressable(
                          onPressed: () =>
                              showNoteEditDialog(context, ref, item!),
                          child: Text(
                            context.l10n.edit_note,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.activeBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 60,
                      ),
                      child: CupertinoScrollbar(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            item.note!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: resolveColor(
                                context,
                                ClipFlowColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 8),
              CupertinoPressable(
                onPressed: () => showNoteEditDialog(context, ref, item!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.pencil,
                        size: 13,
                        color: resolveColor(
                          context,
                          ClipFlowColors.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        context.l10n.add_note,
                        style: TextStyle(
                          fontSize: 12,
                          color: resolveColor(
                            context,
                            ClipFlowColors.secondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const CupertinoDivider(),
            const SizedBox(height: 12),
            MetadataRowWidget(
              label: context.l10n.copied_time,
              value: DateFormat('dd/MM/yyyy HH:mm').format(item.lastCopiedAt),
            ),
            MetadataRowWidget(
              label: context.l10n.source_app,
              value: item.sourceAppName ?? context.l10n.unknown,
            ),
            MetadataRowWidget(
              label: context.l10n.usage_count,
              value: '${item.copyCount}',
            ),
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
                          context.l10n.extract_ocr,
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
                  onPressed: _isUploading
                      ? null
                      : () => _handleCloudUpload(item!),
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
                          context.l10n.upload_cloud,
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
                  onPressed: _isProcessing
                      ? null
                      : () => _handleTranslate(item!),
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
                          context.l10n.translate_text,
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
                child: Text(context.l10n.copy_again),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(ClipboardContentType type) => switch (type) {
    ClipboardContentType.text => CupertinoIcons.doc_text,
    ClipboardContentType.url => CupertinoIcons.link,
    ClipboardContentType.email => CupertinoIcons.mail,
    ClipboardContentType.phone => CupertinoIcons.phone,
    ClipboardContentType.code =>
      CupertinoIcons.chevron_left_slash_chevron_right,
    ClipboardContentType.color => CupertinoIcons.color_filter,
    ClipboardContentType.json =>
      CupertinoIcons.chevron_left_slash_chevron_right,
    ClipboardContentType.file => CupertinoIcons.folder,
    ClipboardContentType.image => CupertinoIcons.photo,
  };

  String _typeLabel(ClipboardContentType type) => switch (type) {
    ClipboardContentType.text => 'TEXT',
    ClipboardContentType.url => 'LINK',
    ClipboardContentType.email => 'EMAIL',
    ClipboardContentType.phone => 'PHONE',
    ClipboardContentType.code => 'CODE',
    ClipboardContentType.color => 'COLOR',
    ClipboardContentType.json => 'JSON',
    ClipboardContentType.file => 'FILE',
    ClipboardContentType.image => 'IMAGE',
  };
}

class ClipboardImagePreviewWidget extends ConsumerWidget {
  const ClipboardImagePreviewWidget({
    super.key,
    required this.path,
    required this.height,
    this.item,
  });

  final String path;
  final double height;
  final ClipboardItem? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = isImageUrl(path);
    final fileExists = !isOnline && File(path).existsSync();

    return CupertinoPressable(
      onPressed: () {
        showImageZoomDialog(
          context,
          path: path,
          title: item?.sourceAppName != null
              ? 'Ảnh từ ${item!.sourceAppName}'
              : 'Xem hình ảnh',
          onCopy: item != null
              ? () => ref.read(historyControllerProvider.notifier).copy(item!)
              : null,
        );
      },
      child: Stack(
        children: [
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: resolveColor(context, ClipFlowColors.surface),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: resolveColor(context, ClipFlowColors.border),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: isOnline
                  ? CachedNetworkImage(
                      url: path,
                      height: height,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    )
                  : (fileExists
                        ? Image.file(
                            File(path),
                            height: height,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          )
                        : Center(child: Text(context.l10n.image_not_found))),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.arrow_up_left_arrow_down_right,
                size: 13,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetadataRowWidget extends StatelessWidget {
  const MetadataRowWidget({
    super.key,
    required this.label,
    required this.value,
  });

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
              style: TextStyle(
                color: resolveColor(context, ClipFlowColors.secondaryText),
              ),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
