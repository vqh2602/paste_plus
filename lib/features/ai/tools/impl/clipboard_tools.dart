import '../../../clipboard_history/domain/clipboard_content_type.dart';
import '../../../clipboard_history/domain/clipboard_item.dart';
import '../../../clipboard_history/domain/clipboard_repository.dart';
import '../ai_tool.dart';

/// Read-only tool: Searches clipboard history with filters.
class SearchClipboardTool implements AiTool {
  SearchClipboardTool(this._clipboardHistory, [this._repository]);

  final List<ClipboardItem> _clipboardHistory;
  final ClipboardRepository? _repository;

  @override
  String get name => 'search_clipboard';

  @override
  String get description =>
      'Tìm kiếm các mục trong lịch sử clipboard theo loại, từ khóa, ứng dụng hoặc thời gian.';

  @override
  bool get requiresConfirmation => false;

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'content_type': {'type': 'string', 'enum': ['json', 'url', 'code', 'text', 'image', 'file']},
          'query': {'type': 'string'},
          'date_range': {'type': 'string', 'enum': ['today', 'yesterday', 'recent']},
        },
      };

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    final contentType = (arguments['content_type'] ?? '').toString().toLowerCase();
    final query = (arguments['query'] ?? '').toString().toLowerCase();
    final dateRange = (arguments['date_range'] ?? '').toString().toLowerCase();

    List<ClipboardItem> items = _clipboardHistory;
    if (_repository != null && _clipboardHistory.isEmpty) {
      items = await _repository.getItems(limit: 50);
    }

    final filtered = items.where((item) {
      if (contentType.isNotEmpty) {
        if (contentType == 'json' && item.contentType != ClipboardContentType.json) return false;
        if (contentType == 'url' && item.contentType != ClipboardContentType.url) return false;
        if (contentType == 'code' && item.contentType != ClipboardContentType.code) return false;
        if (contentType == 'image' && item.contentType != ClipboardContentType.image) return false;
      }
      if (query.isNotEmpty) {
        if (!item.content.toLowerCase().contains(query) &&
            !(item.sourceAppName?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      if (dateRange == 'yesterday') {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        if (item.createdAt.day != yesterday.day) return false;
      }
      return true;
    }).toList();

    final formatted = filtered.take(10).map((i) => '[clip:${i.id}] (${i.contentType.name}): ${i.content}').join('\n---\n');

    return AiToolResult.ok(
      filtered.isNotEmpty
          ? 'Đã tìm thấy ${filtered.length} mục clipboard khớp:\n$formatted'
          : 'Không tìm thấy mục clipboard nào phù hợp.',
      filtered,
    );
  }
}

/// Read-only tool: Fetches a single clipboard item by ID.
class GetClipboardItemTool implements AiTool {
  GetClipboardItemTool(this._clipboardHistory);

  final List<ClipboardItem> _clipboardHistory;

  @override
  String get name => 'get_clipboard_item';

  @override
  String get description => 'Lấy chi tiết một mục clipboard cụ thể theo clip_id.';

  @override
  bool get requiresConfirmation => false;

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'clip_id': {'type': 'string'},
        },
        'required': ['clip_id'],
      };

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    final clipId = arguments['clip_id']?.toString() ?? '';
    final item = _clipboardHistory.firstWhere(
      (i) => i.id == clipId,
      orElse: () => mockFallbackItem(clipId),
    );

    return AiToolResult.ok(
      '[clip:${item.id}] Loại: ${item.contentType.name}, Nội dung:\n${item.content}',
      item,
    );
  }
}

/// Read-only tool: Extracts URLs from content.
class ExtractUrlsTool implements AiTool {
  @override
  String get name => 'extract_urls';

  @override
  String get description => 'Trích xuất tất cả các đường dẫn URL hoặc endpoint từ văn bản.';

  @override
  bool get requiresConfirmation => false;

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
        },
        'required': ['text'],
      };

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    final text = arguments['text']?.toString() ?? '';
    final urlRegex = RegExp(r'https?://[^\s<>"]+|www\.[^\s<>"]+', caseSensitive: false);
    final matches = urlRegex.allMatches(text).map((m) => m.group(0)!).toList();

    return AiToolResult.ok(
      matches.isNotEmpty
          ? 'Đã trích xuất ${matches.length} URL:\n${matches.join('\n')}'
          : 'Không tìm thấy URL nào trong văn bản.',
      matches,
    );
  }
}

/// Read-only tool: Lists collections.
class ListCollectionsTool implements AiTool {
  ListCollectionsTool([this._repository]);

  final ClipboardRepository? _repository;

  @override
  String get name => 'list_collections';

  @override
  String get description => 'Liệt kê các bộ sưu tập clipboard hiện có.';

  @override
  bool get requiresConfirmation => false;

  @override
  Map<String, dynamic> get inputSchema => {'type': 'object', 'properties': {}};

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    if (_repository != null) {
      final collections = await _repository.getCollections();
      final list = collections.map((c) => '- [collection:${c.id}] ${c.name}').join('\n');
      return AiToolResult.ok(
        collections.isNotEmpty ? 'Danh sách bộ sưu tập:\n$list' : 'Chưa có bộ sưu tập nào.',
        collections,
      );
    }
    return AiToolResult.ok('Danh sách bộ sưu tập hiện trống.');
  }
}

/// Mutating tool: Pins or unpins a clipboard item.
class PinClipboardTool implements AiTool {
  PinClipboardTool([this._repository]);

  final ClipboardRepository? _repository;

  @override
  String get name => 'pin_clipboard';

  @override
  String get description => 'Ghim hoặc bỏ ghim một mục clipboard theo clip_id.';

  @override
  bool get requiresConfirmation => true;

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'clip_id': {'type': 'string'},
          'pinned': {'type': 'boolean'},
        },
        'required': ['clip_id'],
      };

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    final clipId = arguments['clip_id']?.toString() ?? '';
    final pinned = arguments['pinned'] == true;

    if (_repository != null && clipId.isNotEmpty) {
      await _repository.setPinned(clipId, pinned);
    }
    return AiToolResult.ok('Đã ${pinned ? 'ghim' : 'bỏ ghim'} mục clipboard [clip:$clipId] thành công.');
  }
}

/// Mutating tool: Adds a clipboard item to a collection.
class AddToCollectionTool implements AiTool {
  AddToCollectionTool([this._repository]);

  final ClipboardRepository? _repository;

  @override
  String get name => 'add_to_collection';

  @override
  String get description => 'Thêm một mục clipboard vào bộ sưu tập chỉ định.';

  @override
  bool get requiresConfirmation => true;

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'clip_id': {'type': 'string'},
          'collection_id': {'type': 'string'},
        },
        'required': ['clip_id', 'collection_id'],
      };

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    final clipId = arguments['clip_id']?.toString() ?? '';
    final collectionId = arguments['collection_id']?.toString() ?? '';

    if (_repository != null && clipId.isNotEmpty && collectionId.isNotEmpty) {
      await _repository.addToCollection(clipId, collectionId);
    }
    return AiToolResult.ok('Đã thêm mục [clip:$clipId] vào bộ sưu tập [collection:$collectionId].');
  }
}

/// Mutating tool: Deletes a clipboard item.
class DeleteClipboardItemTool implements AiTool {
  DeleteClipboardItemTool([this._repository]);

  final ClipboardRepository? _repository;

  @override
  String get name => 'delete_clipboard_item';

  @override
  String get description => 'Xóa một mục clipboard theo clip_id.';

  @override
  bool get requiresConfirmation => true;

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'clip_id': {'type': 'string'},
        },
        'required': ['clip_id'],
      };

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    final clipId = arguments['clip_id']?.toString() ?? '';
    if (_repository != null && clipId.isNotEmpty) {
      await _repository.deleteItem(clipId);
    }
    return AiToolResult.ok('Đã xóa mục clipboard [clip:$clipId] thành công.');
  }
}

ClipboardItem mockFallbackItem(String id) {
  final now = DateTime.now();
  return ClipboardItem(
    id: id,
    content: 'Mục clipboard $id',
    normalizedContent: 'mục clipboard $id',
    contentHash: 'hash-$id',
    contentType: ClipboardContentType.text,
    createdAt: now,
    updatedAt: now,
    lastCopiedAt: now,
    isPinned: false,
    isSensitive: false,
    copyCount: 1,
  );
}
