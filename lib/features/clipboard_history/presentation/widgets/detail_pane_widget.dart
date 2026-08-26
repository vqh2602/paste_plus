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
import '../../domain/smart_text_tools.dart';
import 'calculation_result_line.dart';
import '../history_controller.dart';

import 'clipboard_file_preview.dart';
import 'clipboard_color_preview.dart';
import 'clipboard_preview_dialog.dart';
import 'note_edit_dialog.dart';
import 'url_preview_card.dart';

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

  Future<void> _handleCopy(ClipboardItem item) async {
    await ref.read(historyControllerProvider.notifier).copy(item);
    if (mounted) showCupertinoNotice(context, context.l10n.copied);
  }

  Future<void> _handleTogglePinned(ClipboardItem item) async {
    final wasPinned = item.isPinned;
    await ref.read(historyControllerProvider.notifier).togglePinned(item);
    if (!mounted) return;
    showCupertinoNotice(
      context,
      wasPinned ? context.l10n.unpin : context.l10n.pinned,
    );
  }

  Future<void> _handleOpenUrl(ClipboardItem item) async {
    final raw = item.primaryUrl?.trim().isNotEmpty == true
        ? item.primaryUrl!.trim()
        : item.content.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.hasScheme ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      return;
    }
    await ref.read(desktopIntegrationProvider).openUrl(uri.toString());
  }

  Future<void> _handleRevealFile(String path) {
    return ref.read(desktopIntegrationProvider).revealInFileManager(path);
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
    final viewingVault =
        state.section == HistorySection.collection &&
        state.collectionId == ClipboardCollection.vaultId;
    final filePath = item.contentType == ClipboardContentType.file
        ? firstExistingClipboardFilePath(item.content)
        : null;
    final filePaths = item.contentType == ClipboardContentType.file
        ? clipboardFilePaths(item.content)
        : const <String>[];
    final displayedFilePath = item.contentType == ClipboardContentType.file
        ? (filePaths.isEmpty ? null : filePaths.first)
        : null;
    return ColoredBox(
      color: resolveColor(context, ClipFlowColors.sidebar),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(_typeIcon(item.contentType), size: 19),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          _typeLabel(item.contentType),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                _DetailActionToolbar(
                  item: item,
                  viewingVault: viewingVault,
                  isProcessing: _isProcessing,
                  isUploading: _isUploading,
                  filePath: filePath,
                  onCopy: () => _handleCopy(item!),
                  onOpenUrl: () => _handleOpenUrl(item!),
                  onRevealFile: filePath == null
                      ? null
                      : () => _handleRevealFile(filePath),
                  onOcr: () => _handleOcr(item!),
                  onTranslate: () => _handleTranslate(item!),
                  onCloudUpload: () => _handleCloudUpload(item!),
                  onTogglePinned: () => _handleTogglePinned(item!),
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
                    : item.contentType == ClipboardContentType.file
                    ? ClipboardFilePreview(content: item.content, height: 260)
                    : item.contentType == ClipboardContentType.url
                    ? UrlPreviewCard(item: item)
                    : parsedColor != null
                    ? ClipboardColorPreview(
                        value: item.content,
                        color: parsedColor,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HighlightedText(
                            text: item.content,
                            query: state.query,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.55,
                              color:
                                  item.contentType == ClipboardContentType.url
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
                                  item.contentType ==
                                          ClipboardContentType.code ||
                                      item.contentType ==
                                          ClipboardContentType.json ||
                                      item.contentType ==
                                          ClipboardContentType.jwt
                                  ? 'monospace'
                                  : null,
                            ),
                          ),
                          CalculationResultLine(
                            content: item.content,
                            enabled:
                                item.contentType == ClipboardContentType.text,
                          ),
                        ],
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
                      constraints: const BoxConstraints(maxHeight: 60),
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
            if (item.contentType == ClipboardContentType.url)
              MetadataRowWidget(
                label: context.l10n.url,
                valueWidget: Text(
                  _displayUrl(item.primaryUrl ?? item.content),
                  key: const Key('detail-pane-full-url'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: const TextStyle(color: CupertinoColors.activeBlue),
                ),
              ),
            if (displayedFilePath != null)
              MetadataRowWidget(
                label: context.l10n.file,
                valueWidget: Text(
                  displayedFilePath,
                  key: const Key('detail-pane-file-path'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            MetadataRowWidget(
              label: context.l10n.usage_count,
              value: '${item.copyCount}',
            ),
            if (_metadataValue(context, item) case final metadata?)
              MetadataRowWidget(
                label:
                    item.contentType == ClipboardContentType.image ||
                        isImageUrl(item.content)
                    ? context.l10n.ai_size_label
                    : item.contentType == ClipboardContentType.file
                    ? context.l10n.file_size
                    : context.l10n.details,
                valueWidget: metadata,
              ),
            if (item.contentType == ClipboardContentType.image ||
                isImageUrl(item.content))
              MetadataRowWidget(
                label: context.l10n.file_size,
                valueWidget: ClipboardFileSizeText(
                  key: const Key('detail-pane-image-file-size'),
                  content: item.imagePath ?? item.content,
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget? _metadataValue(BuildContext context, ClipboardItem item) {
    final valueStyle = CupertinoTheme.of(context).textTheme.textStyle;
    if (item.contentType == ClipboardContentType.text) {
      return Text(
        '${item.content.runes.length} ${context.l10n.chars_unit}',
        key: const Key('detail-pane-text-metadata'),
        style: valueStyle,
      );
    }

    if (item.contentType == ClipboardContentType.image ||
        isImageUrl(item.content)) {
      return ImageDimensionsText(
        path: item.imagePath ?? item.content,
        textKey: const Key('detail-pane-image-metadata'),
        style: valueStyle,
      );
    }

    if (item.contentType == ClipboardContentType.file) {
      return ClipboardFileSizeText(
        key: const Key('detail-pane-file-size'),
        content: item.content,
        style: valueStyle,
      );
    }

    if (item.contentType == ClipboardContentType.color) {
      final format = ColorParser.formatName(item.content);
      if (format != null) {
        return Text(
          format,
          key: const Key('detail-pane-color-metadata'),
          style: valueStyle,
        );
      }
    }
    if (item.contentType == ClipboardContentType.code) {
      final language = SmartTextTools.programmingLanguage(item.content);
      if (language != null) {
        return Text(
          '${context.l10n.detected_language}: $language',
          key: const Key('detail-pane-code-metadata'),
          style: valueStyle,
        );
      }
    }
    if (item.contentType == ClipboardContentType.jwt) {
      return Text(
        context.l10n.jwt,
        key: const Key('detail-pane-jwt-metadata'),
        style: valueStyle,
      );
    }
    return null;
  }

  String _displayUrl(String value) {
    final trimmed = value.trim();
    final schemeEnd = trimmed.indexOf('://');
    if (schemeEnd < 0 || schemeEnd + 3 >= trimmed.length) return trimmed;
    // Keep the scheme attached to the hostname. Otherwise Flutter may wrap a
    // long URL immediately after `https://`, leaving a nearly empty first row.
    return '${trimmed.substring(0, schemeEnd + 3)}\u2060'
        '${trimmed.substring(schemeEnd + 3)}';
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
    ClipboardContentType.jwt => CupertinoIcons.lock,
    ClipboardContentType.emoji => CupertinoIcons.smiley,
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
    ClipboardContentType.jwt => 'JWT',
    ClipboardContentType.emoji => 'EMOJI',
    ClipboardContentType.file => 'FILE',
    ClipboardContentType.image => 'IMAGE',
  };
}

class _DetailActionToolbar extends StatelessWidget {
  const _DetailActionToolbar({
    required this.item,
    required this.viewingVault,
    required this.isProcessing,
    required this.isUploading,
    required this.filePath,
    required this.onCopy,
    required this.onOpenUrl,
    required this.onRevealFile,
    required this.onOcr,
    required this.onTranslate,
    required this.onCloudUpload,
    required this.onTogglePinned,
  });

  final ClipboardItem item;
  final bool viewingVault;
  final bool isProcessing;
  final bool isUploading;
  final String? filePath;
  final VoidCallback onCopy;
  final VoidCallback onOpenUrl;
  final VoidCallback? onRevealFile;
  final VoidCallback onOcr;
  final VoidCallback onTranslate;
  final VoidCallback onCloudUpload;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final isImage = item.contentType == ClipboardContentType.image;
    final isFile = item.contentType == ClipboardContentType.file;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoIconControl(
          key: const Key('detail-copy-action'),
          icon: CupertinoIcons.doc_on_doc,
          size: 17,
          tooltip: context.l10n.copy_again,
          onPressed: onCopy,
        ),
        if (item.contentType == ClipboardContentType.url)
          CupertinoIconControl(
            key: const Key('detail-open-browser-action'),
            icon: CupertinoIcons.arrow_up_right_square,
            size: 17,
            tooltip: context.l10n.open_in_browser,
            onPressed: onOpenUrl,
          ),
        if (isFile)
          CupertinoIconControl(
            key: const Key('detail-show-in-folder-action'),
            icon: CupertinoIcons.folder_open,
            size: 17,
            tooltip: context.l10n.show_in_folder,
            onPressed: filePath == null ? null : onRevealFile,
          ),
        if (!viewingVault && isImage) ...[
          CupertinoIconControl(
            key: const Key('detail-ocr-action'),
            icon: CupertinoIcons.doc_text_search,
            size: 17,
            tooltip: context.l10n.extract_ocr,
            onPressed: isProcessing ? null : onOcr,
          ),
          CupertinoIconControl(
            key: const Key('detail-cloud-upload-action'),
            icon: CupertinoIcons.cloud_upload,
            size: 17,
            // color: CupertinoColors.activeGreen,
            tooltip: context.l10n.upload_cloud,
            onPressed: isUploading ? null : onCloudUpload,
          ),
        ] else if (!viewingVault && !isFile)
          CupertinoIconControl(
            key: const Key('detail-translate-action'),
            icon: CupertinoIcons.globe,
            size: 17,
            tooltip: context.l10n.translate_text,
            onPressed: isProcessing ? null : onTranslate,
          ),
        CupertinoIconControl(
          key: const Key('detail-pin-action'),
          icon: item.isPinned ? CupertinoIcons.pin_fill : CupertinoIcons.pin,
          size: 17,
          color: item.isPinned ? CupertinoTheme.of(context).primaryColor : null,
          tooltip: item.isPinned ? context.l10n.unpin : context.l10n.pin,
          onPressed: onTogglePinned,
        ),
      ],
    );
  }
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
    this.value,
    this.valueWidget,
  }) : assert((value == null) != (valueWidget == null));

  final String label;
  final String? value;
  final Widget? valueWidget;

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
          Flexible(
            child:
                valueWidget ??
                Text(
                  value!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
          ),
        ],
      ),
    );
  }
}
