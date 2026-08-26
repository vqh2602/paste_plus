import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'cached_network_image_widget.dart';
import 'package:clipflow/core/localization/localization_extensions.dart';
import 'cupertino_components.dart';

/// Opens a full-screen interactive image viewer with zoom, pan, and copy capabilities.
void showImageZoomDialog(
  BuildContext context, {
  required String path,
  String? title,
  VoidCallback? onCopy,
}) {
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _ImageZoomViewerModal(
      path: path,
      title: title,
      onCopy: onCopy,
    ),
  );
}

class _ImageZoomViewerModal extends StatefulWidget {
  const _ImageZoomViewerModal({
    required this.path,
    this.title,
    this.onCopy,
  });

  final String path;
  final String? title;
  final VoidCallback? onCopy;

  @override
  State<_ImageZoomViewerModal> createState() => _ImageZoomViewerModalState();
}

class _ImageZoomViewerModalState extends State<_ImageZoomViewerModal> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      setState(() {
        _transformationController.value = Matrix4.identity();
      });
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      setState(() {
        // ignore: deprecated_member_use
        _transformationController.value = Matrix4.identity()
          // ignore: deprecated_member_use
          ..translate(-position.dx * 1.2, -position.dy * 1.2)
          // ignore: deprecated_member_use
          ..scale(2.5);
      });
    }
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = isImageUrl(widget.path);
    final fileExists = !isOnline && File(widget.path).existsSync();

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.94),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Zoomable Image View
              Center(
                child: GestureDetector(
                  onDoubleTapDown: _handleDoubleTapDown,
                  onDoubleTap: _handleDoubleTap,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 6.0,
                    clipBehavior: Clip.none,
                    child: isOnline
                        ? CachedNetworkImage(
                            url: widget.path,
                            fit: BoxFit.contain,
                          )
                        : (fileExists
                            ? Image.file(
                                File(widget.path),
                                fit: BoxFit.contain,
                              )
                            : Text(
                                context.l10n.image_not_found,
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                ),
                              )),
                  ),
                ),
              ),

              // Header Controls (Close, Title, Reset Zoom, Copy)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      color: CupertinoColors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.title != null)
                      Expanded(
                        child: Text(
                          widget.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.all(8),
                      color: CupertinoColors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      onPressed: _resetZoom,
                      child: const Icon(
                        CupertinoIcons.arrow_counterclockwise,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
                    ),
                    if (widget.onCopy != null) ...[
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        color: CupertinoColors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        onPressed: () {
                          widget.onCopy!();
                          showCupertinoNotice(context, context.l10n.copied);
                        },
                        child: const Icon(
                          CupertinoIcons.doc_on_doc,
                          color: CupertinoColors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom Gesture Hint Banner
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      context.l10n.image_zoom_hint,
                      style: const TextStyle(
                        color: CupertinoColors.systemGrey4,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
