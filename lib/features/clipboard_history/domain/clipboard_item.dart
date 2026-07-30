import 'clipboard_content_type.dart';

class ClipboardItem {
  const ClipboardItem({
    required this.id,
    required this.content,
    required this.normalizedContent,
    required this.contentHash,
    required this.contentType,
    required this.createdAt,
    required this.updatedAt,
    required this.lastCopiedAt,
    required this.isPinned,
    required this.isSensitive,
    required this.copyCount,
    this.sourceAppName,
    this.sourceAppIdentifier,
    this.imagePath,
    this.metadataJson,
  });

  final String id;
  final String content;
  final String normalizedContent;
  final String contentHash;
  final ClipboardContentType contentType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastCopiedAt;
  final String? sourceAppName;
  final String? sourceAppIdentifier;
  final bool isPinned;
  final bool isSensitive;
  final String? imagePath;
  final String? metadataJson;
  final int copyCount;

  ClipboardItem copyWith({
    String? content,
    String? normalizedContent,
    ClipboardContentType? contentType,
    bool? isPinned,
    DateTime? lastCopiedAt,
    int? copyCount,
  }) {
    return ClipboardItem(
      id: id,
      content: content ?? this.content,
      normalizedContent: normalizedContent ?? this.normalizedContent,
      contentHash: contentHash,
      contentType: contentType ?? this.contentType,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastCopiedAt: lastCopiedAt ?? this.lastCopiedAt,
      sourceAppName: sourceAppName,
      sourceAppIdentifier: sourceAppIdentifier,
      isPinned: isPinned ?? this.isPinned,
      isSensitive: isSensitive,
      imagePath: imagePath,
      metadataJson: metadataJson,
      copyCount: copyCount ?? this.copyCount,
    );
  }

  factory ClipboardItem.fromMap(Map<String, Object?> map) {
    return ClipboardItem(
      id: map['id']! as String,
      content: (map['content'] as String?) ?? '',
      normalizedContent: (map['normalized_content'] as String?) ?? '',
      contentHash: map['content_hash']! as String,
      contentType: ClipboardContentType.fromDatabase(
        map['content_type']! as String,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      lastCopiedAt: DateTime.fromMillisecondsSinceEpoch(
        map['last_copied_at']! as int,
      ),
      sourceAppName: map['source_app_name'] as String?,
      sourceAppIdentifier: map['source_app_identifier'] as String?,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isSensitive: (map['is_sensitive'] as int? ?? 0) == 1,
      imagePath: map['image_path'] as String?,
      metadataJson: map['metadata_json'] as String?,
      copyCount: map['copy_count'] as int? ?? 1,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'content': content,
    'normalized_content': normalizedContent,
    'content_hash': contentHash,
    'content_type': contentType.name,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'last_copied_at': lastCopiedAt.millisecondsSinceEpoch,
    'source_app_name': sourceAppName,
    'source_app_identifier': sourceAppIdentifier,
    'is_pinned': isPinned ? 1 : 0,
    'is_sensitive': isSensitive ? 1 : 0,
    'image_path': imagePath,
    'metadata_json': metadataJson,
    'copy_count': copyCount,
  };
}

class ClipboardCollection {
  const ClipboardCollection({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String icon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;

  factory ClipboardCollection.fromMap(Map<String, Object?> map) {
    return ClipboardCollection(
      id: map['id']! as String,
      name: map['name']! as String,
      icon: (map['icon'] as String?) ?? 'folder',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
    'sort_order': sortOrder,
  };
}
