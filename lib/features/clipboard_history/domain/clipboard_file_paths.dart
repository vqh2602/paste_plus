import 'dart:io';

/// Parses newline-separated file clipboard content, including `file://` URIs.
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

List<String> existingClipboardFilePaths(String content) {
  return [
    for (final path in clipboardFilePaths(content))
      if (_exists(path)) path,
  ];
}

String? firstExistingClipboardFilePath(String content) {
  final paths = existingClipboardFilePaths(content);
  return paths.isEmpty ? null : paths.first;
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

bool _exists(String path) {
  try {
    final type = FileSystemEntity.typeSync(path, followLinks: true);
    return type == FileSystemEntityType.file ||
        type == FileSystemEntityType.directory;
  } on FileSystemException {
    return false;
  }
}
