import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../../../../core/ui/cached_network_image_widget.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../../core/utils/color_parser.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';
import 'detail_pane_widget.dart';

Future<void> showClipboardPreviewDialog({
  required BuildContext context,
  required ClipboardItem item,
  required VoidCallback onCopy,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.cancel,
    barrierColor: CupertinoColors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _ClipboardPreviewDialog(item: item, onCopy: onCopy),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ClipboardPreviewDialog extends StatelessWidget {
  const _ClipboardPreviewDialog({required this.item, required this.onCopy});

  final ClipboardItem item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final content = item.content;
    final isImage =
        item.contentType == ClipboardContentType.image || isImageUrl(content);
    final characterCount = content.runes.length;
    final wordCount = content.trim().isEmpty
        ? 0
        : content.trim().split(RegExp(r'\s+')).length;
    final lineCount = content.isEmpty ? 0 : '\n'.allMatches(content).length + 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Container(
              key: const Key('clipboard-preview-dialog'),
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(
                  color: resolveColor(context, ClipFlowColors.border),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _PreviewHeader(item: item, onCopy: onCopy),
                  const CupertinoDivider(),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: resolveColor(context, ClipFlowColors.surface),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: resolveColor(context, ClipFlowColors.border),
                        ),
                      ),
                      child: _PreviewContent(item: item),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 16, 13),
                    child: Row(
                      children: isImage
                          ? [
                              ImageDimensionsText(
                                path: item.imagePath ?? item.content,
                                textKey: const Key(
                                  'clipboard-preview-image-dimensions',
                                ),
                              ),
                            ]
                          : [
                              _PreviewStat(
                                value: characterCount,
                                label: context.l10n.characters,
                              ),
                              const _PreviewStatDivider(),
                              _PreviewStat(
                                value: wordCount,
                                label: context.l10n.words,
                              ),
                              const _PreviewStatDivider(),
                              _PreviewStat(
                                value: lineCount,
                                label: context.l10n.lines,
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.item, required this.onCopy});

  final ClipboardItem item;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            CupertinoIconControl(
              key: const Key('clipboard-preview-close'),
              icon: CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: resolveColor(context, ClipFlowColors.secondaryText),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            Icon(_typeIcon(item.contentType), size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _typeLabel(context, item),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            CupertinoIconControl(
              key: const Key('clipboard-preview-copy'),
              icon: CupertinoIcons.doc_on_doc,
              size: 18,
              tooltip: context.l10n.copy,
              onPressed: () {
                onCopy();
                showCupertinoNotice(context, context.l10n.copied);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.item});

  final ClipboardItem item;

  @override
  Widget build(BuildContext context) {
    final isImage = item.contentType == ClipboardContentType.image;
    final isOnlineImage = isImageUrl(item.content);
    final parsedColor = item.contentType == ClipboardContentType.color
        ? ColorParser.parse(item.content)
        : null;

    if (isImage || isOnlineImage) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipboardImagePreviewWidget(
                path: item.imagePath ?? item.content,
                height: math.max(
                  180,
                  math.min(360, constraints.maxHeight - 50),
                ),
                item: item,
              ),
              if (item.content.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  item.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: resolveColor(context, ClipFlowColors.secondaryText),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (parsedColor != null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: parsedColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: resolveColor(context, ClipFlowColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SelectableText(
              item.content,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
            ),
          ],
        ),
      );
    }

    return CupertinoScrollbar(
      child: SingleChildScrollView(
        primary: true,
        child: SelectableText(
          item.content.isEmpty ? context.l10n.clipboard_empty : item.content,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: item.contentType == ClipboardContentType.url
                ? CupertinoColors.activeBlue
                : resolveColor(context, ClipFlowColors.text),
            decoration: item.contentType == ClipboardContentType.url
                ? TextDecoration.underline
                : TextDecoration.none,
            fontFamily:
                item.contentType == ClipboardContentType.code ||
                    item.contentType == ClipboardContentType.json
                ? 'monospace'
                : null,
          ),
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        '$value $label',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: resolveColor(context, ClipFlowColors.secondaryText),
        ),
      ),
    );
  }
}

class ImageDimensionsText extends StatefulWidget {
  const ImageDimensionsText({
    super.key,
    required this.path,
    this.textKey,
    this.style,
  });

  final String path;
  final Key? textKey;
  final TextStyle? style;

  @override
  State<ImageDimensionsText> createState() => _ImageDimensionsTextState();
}

class _ImageDimensionsTextState extends State<ImageDimensionsText> {
  int? _width;
  int? _height;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ImageDimensionsText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _width = null;
      _height = null;
      _resolve();
    }
  }

  void _resolve() {
    final path = widget.path;
    if (!isImageUrl(path)) {
      final dimensions = _readLocalDimensions(path);
      if (dimensions != null) {
        _width = dimensions.$1;
        _height = dimensions.$2;
        return;
      }
    }
    unawaited(_resolveWithCodec(path));
  }

  Future<void> _resolveWithCodec(String path) async {
    try {
      final bytes = isImageUrl(path)
          ? await _download(path)
          : await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted || widget.path != path) return;
      setState(() {
        _width = width;
        _height = height;
      });
    } on Object {
      // The preview can still render its normal missing-image state.
    }
  }

  (int, int)? _readLocalDimensions(String path) {
    RandomAccessFile? file;
    try {
      file = File(path).openSync();
      final bytes = file.readSync(math.min(file.lengthSync(), 256 * 1024));

      if (bytes.length >= 24 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return (_uint32BigEndian(bytes, 16), _uint32BigEndian(bytes, 20));
      }

      if (bytes.length >= 10 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46) {
        return (_uint16LittleEndian(bytes, 6), _uint16LittleEndian(bytes, 8));
      }

      if (bytes.length >= 30 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[12] == 0x56 &&
          bytes[13] == 0x50 &&
          bytes[14] == 0x38 &&
          bytes[15] == 0x58) {
        final width = 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16);
        final height = 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16);
        return (width, height);
      }

      if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        var offset = 2;
        while (offset + 8 < bytes.length) {
          if (bytes[offset] != 0xFF) {
            offset++;
            continue;
          }
          final marker = bytes[offset + 1];
          if (marker == 0xD8 || marker == 0xD9) {
            offset += 2;
            continue;
          }
          final segmentLength = (bytes[offset + 2] << 8) + bytes[offset + 3];
          if (segmentLength < 2 || offset + segmentLength + 2 > bytes.length) {
            break;
          }
          const sizeMarkers = {
            0xC0,
            0xC1,
            0xC2,
            0xC3,
            0xC5,
            0xC6,
            0xC7,
            0xC9,
            0xCA,
            0xCB,
            0xCD,
            0xCE,
            0xCF,
          };
          if (sizeMarkers.contains(marker)) {
            final height = (bytes[offset + 5] << 8) + bytes[offset + 6];
            final width = (bytes[offset + 7] << 8) + bytes[offset + 8];
            return (width, height);
          }
          offset += segmentLength + 2;
        }
      }
    } on Object {
      return null;
    } finally {
      file?.closeSync();
    }
    return null;
  }

  int _uint32BigEndian(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  int _uint16LittleEndian(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  Future<Uint8List> _download(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'ClipFlow/1.1.7');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Image request failed', uri: Uri.parse(url));
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = _width;
    final height = _height;
    return Text(
      width != null && height != null ? '$width × $height px' : '— × — px',
      key: widget.textKey,
      style:
          widget.style ??
          TextStyle(
            fontSize: 12,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
    );
  }
}

class _PreviewStatDivider extends StatelessWidget {
  const _PreviewStatDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '·',
        style: TextStyle(
          color: resolveColor(context, ClipFlowColors.secondaryText),
        ),
      ),
    );
  }
}

IconData _typeIcon(ClipboardContentType type) => switch (type) {
  ClipboardContentType.text => CupertinoIcons.doc_text,
  ClipboardContentType.url => CupertinoIcons.link,
  ClipboardContentType.email => CupertinoIcons.mail,
  ClipboardContentType.phone => CupertinoIcons.phone,
  ClipboardContentType.code => CupertinoIcons.chevron_left_slash_chevron_right,
  ClipboardContentType.color => CupertinoIcons.color_filter,
  ClipboardContentType.json => CupertinoIcons.chevron_left_slash_chevron_right,
  ClipboardContentType.file => CupertinoIcons.folder,
  ClipboardContentType.image => CupertinoIcons.photo,
};

String _typeLabel(BuildContext context, ClipboardItem item) {
  if (isImageUrl(item.content)) return context.l10n.image_link;
  return switch (item.contentType) {
    ClipboardContentType.text => context.l10n.text,
    ClipboardContentType.url => context.l10n.url,
    ClipboardContentType.email => context.l10n.email,
    ClipboardContentType.phone => context.l10n.phone,
    ClipboardContentType.code => context.l10n.code,
    ClipboardContentType.color => context.l10n.color,
    ClipboardContentType.json => context.l10n.json,
    ClipboardContentType.file => context.l10n.file,
    ClipboardContentType.image => context.l10n.image,
  };
}
