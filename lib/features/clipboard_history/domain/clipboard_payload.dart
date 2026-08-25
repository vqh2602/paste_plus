import 'dart:typed_data';

class ClipboardPayload {
  const ClipboardPayload({
    this.text,
    this.imageBytes,
    this.filePaths = const [],
    this.sourceAppName,
    this.sourceAppIdentifier,
  });

  final String? text;
  final Uint8List? imageBytes;
  final List<String> filePaths;
  final String? sourceAppName;
  final String? sourceAppIdentifier;

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) &&
      (imageBytes == null || imageBytes!.isEmpty) &&
      filePaths.isEmpty;
}
