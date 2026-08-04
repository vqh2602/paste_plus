import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';

bool isImageUrl(String content) {
  final trimmed = content.trim();
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    return false;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  final path = uri.path.toLowerCase();
  final fullUrl = trimmed.toLowerCase();

  final imageExtensions = [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.svg',
    '.ico',
    '.heic',
    '.avif',
  ];

  for (final ext in imageExtensions) {
    if (path.endsWith(ext) ||
        fullUrl.contains('$ext?') ||
        fullUrl.contains('$ext#')) {
      return true;
    }
  }

  final host = uri.host.toLowerCase();
  if (host == 'picsum.photos' ||
      host == 'via.placeholder.com' ||
      host == 'dummyimage.com' ||
      host == 'placekitten.com' ||
      (host == 'images.unsplash.com' && path.startsWith('/photo-'))) {
    return true;
  }

  return false;
}

class CachedNetworkImage extends StatefulWidget {
  const CachedNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorBuilder,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorBuilder;

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  File? _cachedFile;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadCache();
  }

  @override
  void didUpdateWidget(covariant CachedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadCache();
    }
  }

  Future<void> _loadCache() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/clipflow_img_cache',
      );
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final hash = md5.convert(utf8.encode(widget.url)).toString();
      final file = File('${cacheDir.path}/$hash');

      if (await file.exists() && (await file.length()) > 0) {
        if (!mounted) return;
        setState(() {
          _cachedFile = file;
          _loading = false;
        });
        return;
      }

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.url));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'ClipFlow/1.1.4 ImageCache',
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          <int>[],
          (buffer, data) => buffer..addAll(data),
        );
        client.close();
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        setState(() {
          _cachedFile = file;
          _loading = false;
        });
      } else {
        client.close();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: CupertinoColors.systemGroupedBackground,
        child:
            widget.placeholder ??
            const Center(child: CupertinoActivityIndicator(radius: 8)),
      );
    }

    if (_error || _cachedFile == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: CupertinoColors.systemGroupedBackground,
        child:
            widget.errorBuilder ??
            const Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 20,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
      );
    }

    return Image.file(
      _cachedFile!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorBuilder ??
            Container(
              width: widget.width,
              height: widget.height,
              color: CupertinoColors.systemGroupedBackground,
              child: const Center(
                child: Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 18,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            );
      },
    );
  }
}
