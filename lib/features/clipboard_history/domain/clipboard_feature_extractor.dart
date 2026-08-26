import 'dart:convert';

import 'clipboard_content_type.dart';
import 'search_query.dart';
import 'url_preview_metadata.dart';

class ClipboardFeatures {
  const ClipboardFeatures({
    required this.containsUrl,
    required this.urls,
    required this.primaryUrl,
    required this.urlHost,
    required this.urlKind,
    required this.mimeType,
    required this.fileExtension,
    required this.hasOcrText,
    required this.searchableText,
  });

  final bool containsUrl;
  final List<String> urls;
  final String? primaryUrl;
  final String? urlHost;
  final ClipboardUrlKind? urlKind;
  final String? mimeType;
  final String? fileExtension;
  final bool hasOcrText;
  final String searchableText;
}

class ClipboardFeatureExtractor {
  const ClipboardFeatureExtractor();

  static final RegExp _urlPattern = RegExp(
    r"""(?:(?:https?|ftp)://|www\.)[^\s<>"'\]\[(){}]+""",
    caseSensitive: false,
  );

  ClipboardFeatures extract({
    required String content,
    required ClipboardContentType contentType,
    String? imagePath,
    String? metadataJson,
    String? note,
    String? sourceAppName,
  }) {
    final urls = <String>[];
    for (final match in _urlPattern.allMatches(content)) {
      final raw = match.group(0)?.replaceAll(RegExp(r'[.,;:!?]+$'), '') ?? '';
      final normalized = raw.startsWith('www.') ? 'https://$raw' : raw;
      final uri = Uri.tryParse(normalized);
      if (uri != null && uri.host.isNotEmpty) urls.add(uri.toString());
    }
    if (contentType == ClipboardContentType.url && urls.isEmpty) {
      final normalized = content.startsWith('www.')
          ? 'https://$content'
          : content;
      final uri = Uri.tryParse(normalized.trim());
      if (uri != null && uri.host.isNotEmpty) urls.add(uri.toString());
    }

    String? ocrText;
    final urlPreview = UrlPreviewMetadata.fromClipboardMetadata(metadataJson);
    if (metadataJson?.isNotEmpty == true) {
      try {
        final metadata = jsonDecode(metadataJson!) as Map<String, dynamic>;
        ocrText = metadata['ocrText']?.toString().trim();
      } on Object {
        ocrText = null;
      }
    }
    final primary = urls.firstOrNull;
    final uri = primary == null ? null : Uri.tryParse(primary);
    final extension = _extension(imagePath ?? content);
    return ClipboardFeatures(
      containsUrl: urls.isNotEmpty,
      urls: List.unmodifiable(urls),
      primaryUrl: primary,
      urlHost: uri?.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), ''),
      urlKind: _urlKind(uri),
      mimeType: _mimeType(extension, contentType),
      fileExtension: extension,
      hasOcrText: ocrText?.isNotEmpty == true,
      searchableText:
          [
                content,
                ocrText,
                urlPreview?.title,
                urlPreview?.description,
                urlPreview?.siteName,
                note,
                sourceAppName,
                imagePath,
              ]
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .join(' ')
              .toLowerCase(),
    );
  }

  ClipboardUrlKind? _urlKind(Uri? uri) {
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'github.com' ||
        host.endsWith('.github.com') ||
        host == 'gitlab.com' ||
        host == 'bitbucket.org') {
      return ClipboardUrlKind.repository;
    }
    if (RegExp(r'\.(png|jpe?g|gif|webp|svg|avif)$').hasMatch(path)) {
      return ClipboardUrlKind.image;
    }
    if (RegExp(r'\.(mp4|mov|webm|mkv|m3u8)$').hasMatch(path)) {
      return ClipboardUrlKind.video;
    }
    if (RegExp(r'\.(zip|rar|7z|dmg|exe|msi|apk|pdf)$').hasMatch(path)) {
      return ClipboardUrlKind.download;
    }
    return ClipboardUrlKind.webPage;
  }

  String? _extension(String value) {
    final path = Uri.tryParse(value)?.path ?? value;
    final match = RegExp(r'\.([a-zA-Z0-9]{1,10})$').firstMatch(path.trim());
    return match?.group(1)?.toLowerCase();
  }

  String? _mimeType(String? extension, ClipboardContentType type) {
    if (type == ClipboardContentType.image && extension == null) {
      return 'image/png';
    }
    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'pdf' => 'application/pdf',
      'json' => 'application/json',
      _ => null,
    };
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
