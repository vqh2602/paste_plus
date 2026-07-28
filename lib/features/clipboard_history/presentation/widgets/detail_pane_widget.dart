import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../ai/domain/ai_feature_action.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';

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
        showCupertinoNotice(context, 'ocr_success'.tr);
      } else {
        showCupertinoNotice(context, 'ocr_empty'.tr);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleTranslate(ClipboardItem item) async {
    final settings = ref.read(settingsControllerProvider);
    setState(() => _isProcessing = true);
    try {
      final option = settings.targetTranslationLanguage == 'en'
          ? 'Tự động -> Tiếng Anh'
          : 'Tự động -> Tiếng Việt';
      ref.read(aiControllerProvider.notifier).setClipboardContext(item);
      await ref.read(desktopIntegrationProvider).showAiWindow();
      await ref
          .read(aiControllerProvider.notifier)
          .sendUserMessage(
            'Dịch nội dung clipboard sang ${settings.targetTranslationLanguage}.',
            featureGroup: AiFeatureGroup.translate,
            selectedOption: option,
            contextItem: item,
          );
      if (!mounted) return;
      showCupertinoNotice(context, 'translate_success'.tr);
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
        showCupertinoNotice(context, 'upload_cloud_success'.tr);
      } else {
        showCupertinoNotice(context, 'upload_cloud_failed'.tr);
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
    if (item == null) {
      return Center(child: Text('select_item_to_view'.tr));
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
            const CupertinoDivider(),
            const SizedBox(height: 12),
            MetadataRowWidget(
              label: 'copied_time'.tr,
              value: DateFormat('dd/MM/yyyy HH:mm').format(item.lastCopiedAt),
            ),
            MetadataRowWidget(
              label: 'source_app'.tr,
              value: item.sourceAppName ?? 'unknown'.tr,
            ),
            MetadataRowWidget(
              label: 'usage_count'.tr,
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
                          'extract_ocr'.tr,
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
                          'upload_cloud'.tr,
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
                          'translate_text'.tr,
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
                child: Text('copy_again'.tr),
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

class ClipboardImagePreviewWidget extends StatelessWidget {
  const ClipboardImagePreviewWidget({
    super.key,
    required this.path,
    required this.height,
  });

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isOnline = isImageUrl(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: isOnline
          ? CachedNetworkImage(
              url: path,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          : (File(path).existsSync()
                ? Image.file(
                    File(path),
                    height: height,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Center(child: Text('image_not_found'.tr))),
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
