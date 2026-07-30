import 'dart:typed_data';

import 'shared_collection_payload.dart';

class SharedClipboardPayload {
  const SharedClipboardPayload({
    required this.messageId,
    required this.sourceDeviceId,
    required this.createdAt,
    this.text,
    this.imageBytes,
    this.isPinned = false,
    this.collections = const [],
    this.writeToSystemClipboard = true,
    this.metadataAuthoritative = false,
  });

  final String messageId;
  final String sourceDeviceId;
  final DateTime createdAt;
  final String? text;
  final Uint8List? imageBytes;
  final bool isPinned;
  final List<SharedCollectionPayload> collections;
  final bool writeToSystemClipboard;
  final bool metadataAuthoritative;
}
