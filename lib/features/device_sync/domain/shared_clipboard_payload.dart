import 'dart:typed_data';

class SharedClipboardPayload {
  const SharedClipboardPayload({
    required this.messageId,
    required this.sourceDeviceId,
    required this.createdAt,
    this.text,
    this.imageBytes,
    this.isPinned = false,
    this.collectionNames = const [],
  });

  final String messageId;
  final String sourceDeviceId;
  final DateTime createdAt;
  final String? text;
  final Uint8List? imageBytes;
  final bool isPinned;
  final List<String> collectionNames;
}
