import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import '../../../../core/ui/cupertino_components.dart';

/// Returns the paths carried by a file clipboard item, including `file://`
/// values and newline-separated multi-file selections.
List<String> clipboardFilePaths(String content) {
  final paths = <String>[];
  final seen = <String>{};
  for (final line in content.replaceAll('\r\n', '\n').split('\n')) {
    final raw = line.trim();
    if (raw.isEmpty) continue;

    var path = raw;
    if (raw.toLowerCase().startsWith('file://')) {
      try {
        final uri = Uri.parse(raw);
        if (uri.scheme != 'file') continue;
        path = uri.toFilePath(windows: Platform.isWindows);
      } on FormatException {
        continue;
      }
    }

    if (seen.add(path)) paths.add(path);
  }
  return paths;
}

String? firstExistingClipboardFilePath(String content) {
  for (final path in clipboardFilePaths(content)) {
    try {
      if (FileSystemEntity.typeSync(path, followLinks: true) !=
          FileSystemEntityType.notFound) {
        return path;
      }
    } on FileSystemException {
      // Keep looking in case a multi-file clipboard item has another file.
    }
  }
  return null;
}

int? clipboardFilesSize(String content) {
  var total = 0;
  var hasFile = false;
  for (final path in clipboardFilePaths(content)) {
    try {
      if (FileSystemEntity.typeSync(path, followLinks: true) !=
          FileSystemEntityType.file) {
        continue;
      }
      total += File(path).lengthSync();
      hasFile = true;
    } on FileSystemException {
      // A clipboard item may outlive its source file.
    }
  }
  return hasFile ? total : null;
}

String formatFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes ${units[unit]}';
  final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

class ClipboardFileSizeText extends StatelessWidget {
  const ClipboardFileSizeText({super.key, required this.content, this.style});

  final String content;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final size = clipboardFilesSize(content);
    return Text(size == null ? '—' : formatFileSize(size), style: style);
  }
}

class ClipboardFilePreview extends StatefulWidget {
  const ClipboardFilePreview({
    super.key,
    required this.content,
    required this.height,
  });

  final String content;
  final double height;

  @override
  State<ClipboardFilePreview> createState() => _ClipboardFilePreviewState();
}

class _ClipboardFilePreviewState extends State<ClipboardFilePreview> {
  String? _path;
  Future<String?>? _thumbnail;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ClipboardFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) _resolve();
  }

  void _resolve() {
    _path = firstExistingClipboardFilePath(widget.content);
    _thumbnail = switch (_path) {
      final path? when _isDirectlyRenderableImage(path) => Future.value(path),
      final path? => _FileThumbnailService.thumbnailFor(path),
      null => Future.value(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path == null) {
      return _FileFallback(
        key: const Key('clipboard-file-preview-missing'),
        path: clipboardFilePaths(widget.content).firstOrNull ?? widget.content,
        height: widget.height,
      );
    }

    return FutureBuilder<String?>(
      future: _thumbnail,
      builder: (context, snapshot) {
        final thumbnailPath = snapshot.data;
        return Container(
          key: const Key('clipboard-file-preview'),
          width: double.infinity,
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: resolveColor(context, ClipFlowColors.sidebar),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: resolveColor(context, ClipFlowColors.border),
            ),
          ),
          child: switch ((thumbnailPath, snapshot.connectionState)) {
            (final thumbnail?, _) => Image.file(
              File(thumbnail),
              key: const Key('clipboard-file-preview-image'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _FileFallback(path: path, height: widget.height),
            ),
            (null, ConnectionState.waiting) => const Center(
              child: CupertinoActivityIndicator(),
            ),
            _ => _FileFallback(path: path, height: widget.height),
          },
        );
      },
    );
  }
}

class _FileFallback extends StatelessWidget {
  const _FileFallback({super.key, required this.path, required this.height});

  final String path;
  final double height;

  @override
  Widget build(BuildContext context) {
    final extension = p.extension(path).replaceFirst('.', '').toUpperCase();
    return Container(
      key: const Key('clipboard-file-preview-fallback'),
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.sidebar),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolveColor(context, ClipFlowColors.border)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_fill,
            size: 58,
            color: resolveColor(context, ClipFlowColors.secondaryText),
          ),
          if (extension.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              extension,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            p.basename(path),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: resolveColor(context, ClipFlowColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isDirectlyRenderableImage(String path) => {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
}.contains(p.extension(path).toLowerCase());

class _FileThumbnailService {
  const _FileThumbnailService._();

  static Future<String?> thumbnailFor(String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    if (Platform.isMacOS && _quickLookExtensions.contains(extension)) {
      return _macOsThumbnail(sourcePath);
    }
    if (Platform.isLinux && extension == '.pdf') {
      return _linuxPdfThumbnail(sourcePath);
    }
    return null;
  }

  static const _quickLookExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.pages',
    '.numbers',
    '.key',
  };

  static Future<String?> _macOsThumbnail(String sourcePath) async {
    if (!File('/usr/bin/qlmanage').existsSync()) return null;
    final outputDirectory = await _outputDirectory(sourcePath);
    final cached = _firstPng(outputDirectory);
    if (cached != null) return cached;

    final exitCode = await _run('/usr/bin/qlmanage', [
      '-t',
      '-s',
      '1200',
      '-o',
      outputDirectory.path,
      sourcePath,
    ]);
    return exitCode == 0 ? _firstPng(outputDirectory) : null;
  }

  static Future<String?> _linuxPdfThumbnail(String sourcePath) async {
    final outputDirectory = await _outputDirectory(sourcePath);
    final cached = _firstPng(outputDirectory);
    if (cached != null) return cached;
    final outputBase = p.join(outputDirectory.path, 'preview');
    final exitCode = await _run('pdftoppm', [
      '-f',
      '1',
      '-l',
      '1',
      '-singlefile',
      '-scale-to',
      '1200',
      '-png',
      sourcePath,
      outputBase,
    ]);
    return exitCode == 0 ? _firstPng(outputDirectory) : null;
  }

  static Future<Directory> _outputDirectory(String sourcePath) async {
    final stat = await FileStat.stat(sourcePath);
    final fingerprint = sha1
        .convert(
          utf8.encode(
            '$sourcePath:${stat.modified.millisecondsSinceEpoch}:${stat.size}',
          ),
        )
        .toString();
    return Directory(
      p.join(Directory.systemTemp.path, 'clipflow_file_previews', fingerprint),
    ).create(recursive: true);
  }

  static String? _firstPng(Directory directory) {
    try {
      for (final entity in directory.listSync()) {
        if (entity is File &&
            p.extension(entity.path).toLowerCase() == '.png') {
          return entity.path;
        }
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }

  static Future<int> _run(String executable, List<String> arguments) async {
    try {
      final process = await Process.start(executable, arguments);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      return await process.exitCode.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
    } on ProcessException {
      return -1;
    }
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
