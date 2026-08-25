import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/clipboard_content_type.dart';
import '../../domain/clipboard_item.dart';

Future<bool> shareClipboardItem(
  BuildContext context,
  ClipboardItem item,
) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  final origin = renderBox == null
      ? null
      : renderBox.localToGlobal(Offset.zero) & renderBox.size;
  final params = buildClipboardShareParams(item, sharePositionOrigin: origin);
  if (params == null) return false;

  try {
    await SharePlus.instance.share(params);
    return true;
  } on Object {
    return false;
  }
}

/// Builds a native share payload that preserves the clipboard item's type.
///
/// The receiving platform can then offer destinations that accept a URL, one
/// or more files, an image, or plain text instead of treating every clipboard
/// item as an untyped string.
ShareParams? buildClipboardShareParams(
  ClipboardItem item, {
  Rect? sharePositionOrigin,
}) {
  switch (item.contentType) {
    case ClipboardContentType.url:
      final uri = _httpUri(item.primaryUrl) ?? _httpUri(item.content);
      if (uri != null) {
        return ShareParams(uri: uri, sharePositionOrigin: sharePositionOrigin);
      }
      return _textShareParams(item.content, sharePositionOrigin);
    case ClipboardContentType.image:
      final imagePath = item.imagePath;
      if (imagePath != null && File(imagePath).existsSync()) {
        final imageMimeType = item.mimeType?.startsWith('image/') == true
            ? item.mimeType
            : null;
        return ShareParams(
          files: <XFile>[XFile(imagePath, mimeType: imageMimeType)],
          sharePositionOrigin: sharePositionOrigin,
        );
      }
      final remoteImageUri = _httpUri(item.content);
      if (remoteImageUri != null) {
        return ShareParams(
          uri: remoteImageUri,
          sharePositionOrigin: sharePositionOrigin,
        );
      }
      return _textShareParams(item.content, sharePositionOrigin);
    case ClipboardContentType.file:
      final files = _existingClipboardFiles(item.content);
      if (files.isNotEmpty) {
        return ShareParams(
          files: files,
          sharePositionOrigin: sharePositionOrigin,
        );
      }
      return _textShareParams(item.content, sharePositionOrigin);
    case ClipboardContentType.text:
    case ClipboardContentType.email:
    case ClipboardContentType.phone:
    case ClipboardContentType.code:
    case ClipboardContentType.color:
    case ClipboardContentType.json:
    case ClipboardContentType.jwt:
    case ClipboardContentType.emoji:
      return _textShareParams(item.content, sharePositionOrigin);
  }
}

ShareParams? _textShareParams(String content, Rect? sharePositionOrigin) {
  final text = content.trim();
  if (text.isEmpty) return null;
  return ShareParams(text: text, sharePositionOrigin: sharePositionOrigin);
}

Uri? _httpUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

List<XFile> _existingClipboardFiles(String content) {
  final seenPaths = <String>{};
  final files = <XFile>[];

  for (final line in content.replaceAll('\r\n', '\n').split('\n')) {
    final rawPath = line.trim();
    if (rawPath.isEmpty) continue;
    final path = _localFilePath(rawPath);
    if (path == null || !seenPaths.add(path) || !_isShareablePath(path)) {
      continue;
    }
    files.add(XFile(path));
  }

  return files;
}

String? _localFilePath(String value) {
  if (!value.toLowerCase().startsWith('file://')) return value;
  try {
    final uri = Uri.parse(value);
    if (uri.scheme != 'file') return null;
    return uri.toFilePath(windows: Platform.isWindows);
  } on FormatException {
    return null;
  }
}

bool _isShareablePath(String path) {
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: true);
    return type == FileSystemEntityType.file ||
        type == FileSystemEntityType.directory;
  } on FileSystemException {
    return false;
  }
}
