import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import '../../../../core/ui/cupertino_components.dart';
import '../../domain/clipboard_file_paths.dart';

export '../../domain/clipboard_file_paths.dart';

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
  bool _isDirectory = false;
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
    _isDirectory = _path != null && _pathIsDirectory(_path!);
    _thumbnail = switch ((_path, _isDirectory)) {
      (_, true) => Future.value(),
      (final path?, false) when _isDirectlyRenderableImage(path) =>
        Future.value(path),
      (final path?, false) => _FileThumbnailService.thumbnailFor(path),
      _ => Future.value(),
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

    if (!_isDirectory && _isDirectlyRenderableImage(path)) {
      return _PreviewFrame(
        height: widget.height,
        child: Image.file(
          File(path),
          key: const Key('clipboard-file-preview-image'),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _FileFallback(path: path, height: widget.height),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: _thumbnail,
      builder: (context, snapshot) {
        final thumbnailPath = snapshot.data;
        return _PreviewFrame(
          height: widget.height,
          child: switch ((thumbnailPath, snapshot.connectionState)) {
            (final thumbnail?, _) => Image.file(
              File(thumbnail),
              key: const Key('clipboard-file-preview-image'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _FileFallback(
                path: path,
                height: widget.height,
                isDirectory: _isDirectory,
              ),
            ),
            (null, ConnectionState.waiting) => const Center(
              child: CupertinoActivityIndicator(),
            ),
            _ => _FileFallback(
              path: path,
              height: widget.height,
              isDirectory: _isDirectory,
            ),
          },
        );
      },
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('clipboard-file-preview'),
      width: double.infinity,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.sidebar),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolveColor(context, ClipFlowColors.border)),
      ),
      child: child,
    );
  }
}

class _FileFallback extends StatelessWidget {
  const _FileFallback({
    super.key,
    required this.path,
    required this.height,
    this.isDirectory = false,
  });

  final String path;
  final double height;
  final bool isDirectory;

  @override
  Widget build(BuildContext context) {
    final extension = p.extension(path).replaceFirst('.', '').toUpperCase();
    final isCompact = height < 150;
    final isVeryCompact = height < 90;
    final iconSize = isVeryCompact ? 24.0 : (isCompact ? 36.0 : 48.0);
    final verticalPadding = isVeryCompact ? 4.0 : (isCompact ? 8.0 : 16.0);

    return Container(
      key: const Key('clipboard-file-preview-fallback'),
      width: double.infinity,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: resolveColor(context, ClipFlowColors.sidebar),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolveColor(context, ClipFlowColors.border)),
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDirectory
                    ? CupertinoIcons.folder_fill
                    : CupertinoIcons.doc_fill,
                key: isDirectory
                    ? const Key('clipboard-file-preview-folder-icon')
                    : const Key('clipboard-file-preview-document-icon'),
                size: iconSize,
                color: resolveColor(context, ClipFlowColors.secondaryText),
              ),
              if (!isDirectory && extension.isNotEmpty) ...[
                SizedBox(height: isCompact ? 4 : 8),
                Text(
                  extension,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              SizedBox(height: isCompact ? 4 : 6),
              Text(
                p.basename(path),
                maxLines: isCompact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isCompact ? 11 : 13,
                  color: resolveColor(context, ClipFlowColors.secondaryText),
                ),
              ),
            ],
          ),
        ),
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

bool _pathIsDirectory(String path) {
  try {
    return FileSystemEntity.typeSync(path, followLinks: true) ==
        FileSystemEntityType.directory;
  } on FileSystemException {
    return false;
  }
}

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
