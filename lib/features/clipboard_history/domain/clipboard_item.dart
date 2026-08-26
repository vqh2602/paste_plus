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
    this.note,
    this.containsUrl = false,
    this.primaryUrl,
    this.urlHost,
    this.urlKind,
    this.mimeType,
    this.fileExtension,
    this.hasOcrText = false,
    this.searchableText = '',
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
  final String? note;
  final int copyCount;
  final bool containsUrl;
  final String? primaryUrl;
  final String? urlHost;
  final String? urlKind;
  final String? mimeType;
  final String? fileExtension;
  final bool hasOcrText;
  final String searchableText;

  ClipboardItem copyWith({
    String? content,
    String? normalizedContent,
    ClipboardContentType? contentType,
    bool? isPinned,
    DateTime? lastCopiedAt,
    int? copyCount,
    String? note,
    bool clearNote = false,
    String? metadataJson,
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
      metadataJson: metadataJson ?? this.metadataJson,
      note: clearNote ? null : (note ?? this.note),
      copyCount: copyCount ?? this.copyCount,
      containsUrl: containsUrl,
      primaryUrl: primaryUrl,
      urlHost: urlHost,
      urlKind: urlKind,
      mimeType: mimeType,
      fileExtension: fileExtension,
      hasOcrText: hasOcrText,
      searchableText: searchableText,
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
      note: map['note'] as String?,
      copyCount: map['copy_count'] as int? ?? 1,
      containsUrl: (map['contains_url'] as int? ?? 0) == 1,
      primaryUrl: map['primary_url'] as String?,
      urlHost: map['url_host'] as String?,
      urlKind: map['url_kind'] as String?,
      mimeType: map['mime_type'] as String?,
      fileExtension: map['file_extension'] as String?,
      hasOcrText: (map['has_ocr_text'] as int? ?? 0) == 1,
      searchableText:
          (map['searchable_text'] as String?) ??
          (map['normalized_content'] as String?) ??
          '',
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
    'note': note,
    'copy_count': copyCount,
    'contains_url': containsUrl ? 1 : 0,
    'primary_url': primaryUrl,
    'url_host': urlHost,
    'url_kind': urlKind,
    'mime_type': mimeType,
    'file_extension': fileExtension,
    'has_ocr_text': hasOcrText ? 1 : 0,
    'searchable_text': searchableText,
  };
}

class ClipboardCollection {
  static const vaultId = 'vault';

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

  bool get isVault => id == vaultId;
  bool get isSystem => isVault;

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
