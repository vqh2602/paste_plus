import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/constants/app_version.dart';
import '../domain/url_preview_metadata.dart';

class UrlPreviewService {
  const UrlPreviewService({
    this.requestTimeout = const Duration(seconds: 8),
    this.maxResponseBytes = 1024 * 1024,
    this.maxRedirects = 4,
  });

  final Duration requestTimeout;
  final int maxResponseBytes;
  final int maxRedirects;

  Future<UrlPreviewMetadata?> fetch(String value) async {
    final initialUri = _normalizeUri(value);
    if (initialUri == null) return null;

    final client = HttpClient()..connectionTimeout = requestTimeout;
    try {
      var currentUri = initialUri;
      for (
        var redirectCount = 0;
        redirectCount <= maxRedirects;
        redirectCount++
      ) {
        if (!await _isSafePublicUri(currentUri)) return null;

        final request = await client.getUrl(currentUri).timeout(requestTimeout);
        request.followRedirects = false;
        request.persistentConnection = false;
        request.headers
          ..set(
            HttpHeaders.userAgentHeader,
            'ClipFlow/${ClipFlowVersion.current} URLPreview',
          )
          ..set(
            HttpHeaders.acceptHeader,
            'text/html,application/xhtml+xml;q=0.9,*/*;q=0.1',
          );
        final response = await request.close().timeout(requestTimeout);

        if (_isRedirect(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null || redirectCount == maxRedirects) return null;
          currentUri = currentUri.resolve(location);
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          return null;
        }
        final mimeType = response.headers.contentType?.mimeType.toLowerCase();
        if (mimeType != null &&
            mimeType != 'text/html' &&
            mimeType != 'application/xhtml+xml') {
          await response.drain<void>();
          return null;
        }

        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(requestTimeout)) {
          if (bytes.length + chunk.length > maxResponseBytes) return null;
          bytes.add(chunk);
        }
        final html = utf8.decode(bytes.takeBytes(), allowMalformed: true);
        var metadata = parseHtml(html, currentUri);
        final imageUri = Uri.tryParse(metadata.imageUrl ?? '');
        if (imageUri != null && !await _isSafePublicUri(imageUri)) {
          metadata = metadata.copyWith(clearImage: true);
        }
        return metadata;
      }
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
    return null;
  }

  static UrlPreviewMetadata parseHtml(String html, Uri pageUri) {
    final metadata = <String, String>{};
    for (final match in RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html)) {
      final attributes = _attributes(match.group(0)!);
      final key =
          (attributes['property'] ??
                  attributes['name'] ??
                  attributes['itemprop'])
              ?.toLowerCase();
      final content = attributes['content'];
      if (key != null && content != null && content.trim().isNotEmpty) {
        metadata.putIfAbsent(key, () => content);
      }
    }

    String? firstValue(Iterable<String> keys) {
      for (final key in keys) {
        final value = metadata[key];
        if (value?.trim().isNotEmpty == true) return _plainText(value!);
      }
      return null;
    }

    final titleTag = RegExp(
      r'<title\b[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html)?.group(1);
    final imageValue = firstValue(const [
      'og:image',
      'og:image:url',
      'twitter:image',
      'twitter:image:src',
      'image',
    ]);
    final imageUri = imageValue == null ? null : pageUri.resolve(imageValue);

    return UrlPreviewMetadata(
      resolvedUrl: pageUri.toString(),
      fetchedAt: DateTime.now().toUtc(),
      title:
          firstValue(const ['og:title', 'twitter:title']) ??
          (titleTag == null ? null : _plainText(titleTag)),
      description: firstValue(const [
        'og:description',
        'twitter:description',
        'description',
      ]),
      imageUrl: imageUri?.hasScheme == true ? imageUri.toString() : null,
      siteName: firstValue(const [
        'og:site_name',
        'application-name',
        'twitter:site',
      ]),
    );
  }

  static Map<String, String> _attributes(String tag) {
    final attributes = <String, String>{};
    final expression = RegExp(
      r'''([a-zA-Z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''',
      dotAll: true,
    );
    for (final match in expression.allMatches(tag)) {
      final name = match.group(1)!.toLowerCase();
      final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes.putIfAbsent(name, () => _decodeEntities(value));
    }
    return attributes;
  }

  static String _plainText(String value) {
    return _decodeEntities(
      value.replaceAll(RegExp(r'<[^>]*>'), ''),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decodeEntities(String value) {
    var decoded = value.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|\d+);'), (
      match,
    ) {
      final token = match.group(1)!;
      final codePoint = token.startsWith('x')
          ? int.tryParse(token.substring(1), radix: 16)
          : int.tryParse(token);
      return codePoint == null
          ? match.group(0)!
          : String.fromCharCode(codePoint);
    });
    const named = {
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
      '&ndash;': '–',
      '&mdash;': '—',
      '&hellip;': '…',
      '&middot;': '·',
      '&amp;': '&',
    };
    for (final entry in named.entries) {
      decoded = decoded.replaceAll(entry.key, entry.value);
    }
    return decoded;
  }

  static Uri? _normalizeUri(String value) {
    final trimmed = value.trim();
    final normalized = trimmed.startsWith('www.')
        ? 'https://$trimmed'
        : trimmed;
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return null;
    return uri;
  }

  static bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  static Future<bool> _isSafePublicUri(Uri uri) async {
    if ((uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host.endsWith('.localhost')) return false;
    try {
      final addresses = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 4));
      return addresses.isNotEmpty && addresses.every(_isPublicAddress);
    } on Object {
      return false;
    }
  }

  static bool _isPublicAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (bytes.length == 4) {
      return _isPublicIpv4(bytes);
    }
    if (bytes.length != 16) return false;
    final isIpv4Mapped =
        bytes.take(10).every((value) => value == 0) &&
        bytes[10] == 0xFF &&
        bytes[11] == 0xFF;
    if (isIpv4Mapped) {
      return _isPublicIpv4(Uint8List.fromList(bytes.sublist(12)));
    }
    final isUnspecified = bytes.every((value) => value == 0);
    final isLoopback =
        bytes.take(15).every((value) => value == 0) && bytes[15] == 1;
    final isUniqueLocal = (bytes[0] & 0xFE) == 0xFC;
    final isLinkLocal = bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80;
    final isMulticast = bytes[0] == 0xFF;
    return !isUnspecified &&
        !isLoopback &&
        !isUniqueLocal &&
        !isLinkLocal &&
        !isMulticast;
  }

  static bool _isPublicIpv4(Uint8List bytes) {
    final first = bytes[0];
    final second = bytes[1];
    if (first == 0 || first == 10 || first == 127 || first >= 224) {
      return false;
    }
    if (first == 100 && second >= 64 && second <= 127) return false;
    if (first == 169 && second == 254) return false;
    if (first == 172 && second >= 16 && second <= 31) return false;
    if (first == 192 && second == 168) return false;
    if (first == 198 && (second == 18 || second == 19)) return false;
    return true;
  }
}
