class SharedCollectionPayload {
  const SharedCollectionPayload({
    required this.messageId,
    required this.sourceDeviceId,
    required this.collectionId,
    required this.name,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
    this.deleted = false,
  });

  final String messageId;
  final String sourceDeviceId;
  final String collectionId;
  final String name;
  final String icon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;
  final bool deleted;

  Map<String, Object?> toMetadataJson() => {
    'id': collectionId,
    'name': name,
    'icon': icon,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'sortOrder': sortOrder,
  };

  factory SharedCollectionPayload.fromMetadataJson(
    Map<String, Object?> json, {
    String messageId = '',
    String sourceDeviceId = '',
  }) {
    return SharedCollectionPayload(
      messageId: messageId,
      sourceDeviceId: sourceDeviceId,
      collectionId: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'folder',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}
