import 'dart:typed_data';

class ClipboardPayload {
  const ClipboardPayload({
    this.text,
    this.imageBytes,
    this.sourceAppName,
    this.sourceAppIdentifier,
  });

  final String? text;
  final Uint8List? imageBytes;
  final String? sourceAppName;
  final String? sourceAppIdentifier;

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) &&
      (imageBytes == null || imageBytes!.isEmpty);
}
