import 'dart:io';
import 'dart:typed_data';

import 'package:clipflow/core/localization/localization_extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../../app/providers.dart';
import '../../../../core/ui/cupertino_components.dart';
import '../../../../core/utils/color_parser.dart';
import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';

Future<bool> showClipboardEditDialog(
  BuildContext context,
  WidgetRef ref,
  ClipboardItem item,
) async {
  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: context.l10n.cancel,
        barrierColor: CupertinoColors.black.withValues(alpha: 0.22),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _ClipboardEditDialog(item: item),
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
      ) ??
      false;
}

class _ClipboardEditDialog extends ConsumerStatefulWidget {
  const _ClipboardEditDialog({required this.item});

  final ClipboardItem item;

  @override
  ConsumerState<_ClipboardEditDialog> createState() =>
      _ClipboardEditDialogState();
}

class _ClipboardEditDialogState extends ConsumerState<_ClipboardEditDialog> {
  late final TextEditingController _controller;
  Uint8List? _imageBytes;
  img.Image? _decodedImage;
  int _quarterTurns = 0;
  bool _saving = false;
  bool _imageLoadFailed = false;
  String? _error;

  bool get _isImage => widget.item.contentType == ClipboardContentType.image;
  bool get _isColor => widget.item.contentType == ClipboardContentType.color;
  bool get _validText => _controller.text.trim().isNotEmpty;
  bool get _validColor => ColorParser.parse(_controller.text) != null;
  bool get _canSave =>
      !_saving &&
      (_isImage
          ? _decodedImage != null
          : (_isColor ? _validColor : _validText));

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.content);
    if (_isImage) {
      _loadImage();
    }
  }

  void _loadImage() {
    final path = widget.item.imagePath;
    if (path == null || path.isEmpty) return;
    try {
      final bytes = File(path).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      _imageBytes = bytes;
      _decodedImage = decoded;
    } on Object {
      _imageLoadFailed = true;
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Uint8List? editedImageBytes;
      if (_isImage) {
        final source = _decodedImage!;
        final edited = _quarterTurns == 0
            ? source
            : img.copyRotate(source, angle: _quarterTurns * 90);
        editedImageBytes = Uint8List.fromList(img.encodePng(edited));
      }
      final updated = await ref
          .read(historyControllerProvider.notifier)
          .updateItemContent(
            widget.item,
            content: _controller.text,
            imageBytes: editedImageBytes,
          );
      if (!mounted) return;
      if (updated == null) {
        setState(() {
          _saving = false;
          _error = context.l10n.clipboard_update_failed;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.clipboard_update_failed;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Container(
              key: const Key('clipboard-edit-dialog'),
              decoration: BoxDecoration(
                border: Border.all(
                  color: resolveColor(context, ClipFlowColors.border),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildEditor()),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          const SizedBox(width: 10),
          CupertinoButton(
            key: const Key('clipboard-edit-cancel'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          const Spacer(),
          if (_isImage) ...[
            CupertinoButton(
              key: const Key('clipboard-edit-rotate-left'),
              padding: const EdgeInsets.all(8),
              onPressed: _decodedImage == null || _saving
                  ? null
                  : () =>
                        setState(() => _quarterTurns = (_quarterTurns + 3) % 4),
              child: const Icon(CupertinoIcons.rotate_left, size: 20),
            ),
            CupertinoButton(
              key: const Key('clipboard-edit-rotate-right'),
              padding: const EdgeInsets.all(8),
              onPressed: _decodedImage == null || _saving
                  ? null
                  : () =>
                        setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
              child: const Icon(CupertinoIcons.rotate_right, size: 20),
            ),
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CupertinoButton.filled(
              key: const Key('clipboard-edit-save'),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const CupertinoActivityIndicator(
                      radius: 8,
                      color: CupertinoColors.white,
                    )
                  : Text(context.l10n.save),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    if (_isImage) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          color: resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: resolveColor(context, ClipFlowColors.border),
          ),
        ),
        child: _imageBytes == null
            ? const Center(child: CupertinoActivityIndicator())
            : Padding(
                padding: const EdgeInsets.all(10),
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                ),
              ),
      );
    }

    if (_isColor) {
      final color = ColorParser.parse(_controller.text);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Expanded(
              child: Container(
                key: const Key('clipboard-edit-color-preview'),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color ?? CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: resolveColor(context, ClipFlowColors.border),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _controller.text,
                  style: TextStyle(
                    color: color == null
                        ? CupertinoColors.systemRed
                        : _contrastingTextColor(color),
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              key: const Key('clipboard-edit-field'),
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              padding: const EdgeInsets.all(12),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: CupertinoTextField(
        key: const Key('clipboard-edit-field'),
        controller: _controller,
        autofocus: true,
        expands: true,
        minLines: null,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        onChanged: (_) => setState(() {}),
        padding: const EdgeInsets.all(14),
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          fontFamily:
              widget.item.contentType == ClipboardContentType.code ||
                  widget.item.contentType == ClipboardContentType.json
              ? 'monospace'
              : null,
        ),
        decoration: BoxDecoration(
          color: resolveColor(context, ClipFlowColors.surface),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: resolveColor(context, ClipFlowColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    String value;
    if (_isImage) {
      final image = _decodedImage;
      if (image == null) {
        value = '— × — px';
      } else if (_quarterTurns.isOdd) {
        value = '${image.height} × ${image.width} px';
      } else {
        value = '${image.width} × ${image.height} px';
      }
    } else if (_isColor) {
      value = _validColor
          ? ColorParser.formatName(_controller.text) ?? context.l10n.color
          : context.l10n.invalid_color_code;
    } else {
      final text = _controller.text;
      final words = text.trim().isEmpty
          ? 0
          : text.trim().split(RegExp(r'\s+')).length;
      final lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
      value =
          '${text.runes.length} ${context.l10n.characters}  ·  '
          '$words ${context.l10n.words}  ·  $lines ${context.l10n.lines}';
    }
    final error =
        _error ??
        (_imageLoadFailed ? context.l10n.clipboard_update_failed : null);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                error ?? value,
                key: const Key('clipboard-edit-footer'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: error != null || (_isColor && !_validColor)
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : resolveColor(context, ClipFlowColors.secondaryText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _contrastingTextColor(Color color) => color.computeLuminance() > 0.45
      ? CupertinoColors.black
      : CupertinoColors.white;
}
