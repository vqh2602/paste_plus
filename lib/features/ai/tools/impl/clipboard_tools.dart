import '../../../clipboard_history/domain/clipboard_content_type.dart';
import '../../../clipboard_history/domain/clipboard_item.dart';
import '../../../clipboard_history/domain/clipboard_repository.dart';
import '../../../clipboard_history/domain/search_query.dart';
import '../../../clipboard_history/domain/clipboard_feature_extractor.dart';
import '../../domain/ai_agent_protocol.dart';
import '../../services/clipboard_semantic_query_compiler.dart';
import '../ai_tool.dart';

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

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
      'content_type': {
        'type': 'string',
        'enum': ['json', 'url', 'code', 'text', 'image', 'file'],
      },
      'query': {'type': 'string'},
      'content_types': {'type': 'array'},
      'contains_url': {
        'type': ['boolean', 'null'],
      },
      'url_hosts': {'type': 'array'},
      'url_kind': {
        'type': ['string', 'null'],
      },
      'text_query': {
        'type': ['string', 'null'],
      },
      'source_apps': {'type': 'array'},
      'file_extensions': {'type': 'array'},
      'date_range': {
        'type': 'string',
        'enum': ['today', 'yesterday', 'recent'],
      },
    },
  };

  @override
  Future<AiToolResult> execute(Map<String, dynamic> arguments) async {
    final query = _queryFromArguments(arguments);
    final page = _repository == null
        ? await _searchHistory(query)
        : await _repository.searchStructured(query);
    final filtered = page.items;
    final resultSetId = 'result-${DateTime.now().microsecondsSinceEpoch}';
    final displayMode = resolveDisplayMode(query: query, items: filtered);
    final formatted = filtered
        .take(10)
        .map((i) => '[clip:${i.id}] (${i.contentType.name}): ${i.content}')
        .join('\n---\n');
    return AiToolResult<ClipboardSearchPayload>(
      status: filtered.isEmpty ? AiToolStatus.empty : AiToolStatus.success,
      code: filtered.isEmpty
          ? 'clipboard.search.empty'
          : 'clipboard.search.success',
      payload: ClipboardSearchPayload(
        query: query,
        items: filtered,
        total: page.total,
        hasMore: page.hasMore,
        resultSetId: resultSetId,
        displayMode: displayMode,
      ),
      legacyOutput: filtered.isNotEmpty
          ? 'Đã tìm thấy ${page.total} mục clipboard khớp:\n$formatted'
          : 'Không tìm thấy mục clipboard nào phù hợp.',
    );
  }

  ClipboardSearchQuery _queryFromArguments(Map<String, dynamic> arguments) {
    List<String> strings(Object? value) => value is List
        ? value.map((item) => item.toString().toLowerCase()).toList()
        : <String>[];
    final rawTypes = strings(arguments['content_types']);
    final legacyType = arguments['content_type']?.toString().toLowerCase();
    if (legacyType?.isNotEmpty == true) rawTypes.add(legacyType!);
    final types = {
      for (final value in rawTypes)
        for (final type in ClipboardContentType.values)
          if (type.name == value) type,
    };
    final date = (arguments['date_preset'] ?? arguments['date_range'])
        ?.toString();
    final urlKindName = arguments['url_kind']?.toString();
    final urlKind = ClipboardUrlKind.values
        .where(
          (kind) =>
              kind.name == urlKindName ||
              (kind == ClipboardUrlKind.webPage && urlKindName == 'web_page'),
        )
        .firstOrNull;
    final explicitText = arguments['text_query']?.toString().trim();
    final rawQuery = arguments['query']?.toString().trim();
    final cleanTextQuery =
        explicitText ??
        (rawQuery?.isNotEmpty == true
            ? ClipboardSemanticQueryCompiler().compile(rawQuery!).textQuery
            : null);

    return ClipboardSearchQuery(
      contentTypes: types,
      textQuery: cleanTextQuery,
      containsUrl:
          arguments['contains_url'] as bool? ??
          (types.contains(ClipboardContentType.url) ? true : null),
      urlHosts: strings(arguments['url_hosts']).toSet(),
      urlKind: urlKind,
      sourceApps: strings(arguments['source_apps']).toSet(),
      fileExtensions: strings(arguments['file_extensions']).toSet(),
      pinned: arguments['pinned'] as bool?,
      dateRange: date == null || date.isEmpty
          ? null
          : ClipboardDateRange(preset: date == 'recent' ? 'last_7_days' : date),
      limit: ((arguments['limit'] as num?)?.toInt() ?? 30).clamp(1, 100),
    );
  }

  Future<ClipboardSearchPage> _searchHistory(ClipboardSearchQuery query) async {
    final repository = _MemoryClipboardRepository(_clipboardHistory);
    return repository.searchStructured(query);
  }
}

ClipboardResultDisplayMode resolveDisplayMode({
  required ClipboardSearchQuery query,
  required List<ClipboardItem> items,
}) {
  if (query.contentTypes.length == 1 &&
      query.contentTypes.contains(ClipboardContentType.image)) {
    return ClipboardResultDisplayMode.imageGrid;
  }
  if (query.containsUrl == true) return ClipboardResultDisplayMode.urlList;
  if (query.contentTypes.length == 1 &&
      query.contentTypes.contains(ClipboardContentType.code)) {
    return ClipboardResultDisplayMode.codeList;
  }
  if (query.contentTypes.length == 1 &&
      query.contentTypes.contains(ClipboardContentType.file)) {
    return ClipboardResultDisplayMode.fileList;
  }
  return ClipboardResultDisplayMode.list;
}

class _MemoryClipboardRepository implements ClipboardRepository {
  const _MemoryClipboardRepository(this.items);
  final List<ClipboardItem> items;

  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async => items.take(limit).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ClipboardItem?> _findItemInRepoOrHistory(
  String clipId,
  List<ClipboardItem> history,
  ClipboardRepository? repository,
) async {
  for (final item in history) {
    if (item.id == clipId) return item;
  }
  if (repository != null) {
    final items = await repository.getItems(limit: 2000);
    for (final item in items) {
      if (item.id == clipId) return item;
    }
  }
  return null;
}

/// Read-only tool: Fetches a single clipboard item by ID.
class GetClipboardItemTool implements AiTool {
  GetClipboardItemTool(this._clipboardHistory, [this._repository]);

  final List<ClipboardItem> _clipboardHistory;
  final ClipboardRepository? _repository;

  @override
  String get name => 'get_clipboard_item';

  @override
  String get description =>
      'Lấy chi tiết một mục clipboard cụ thể theo clip_id.';

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
    if (clipId.isEmpty) {
      return AiToolResult.error('Tham số clip_id không được để trống.');
    }

    final found = await _findItemInRepoOrHistory(
      clipId,
      _clipboardHistory,
      _repository,
    );

    if (found == null) {
      return AiToolResult.notFound(
        'Không tìm thấy mục clipboard có ID: "$clipId".',
      );
    }

    return AiToolResult.ok(
      '[clip:${found.id}] Loại: ${found.contentType.name}, Nội dung:\n${found.content}',
      found,
    );
  }
}

/// Read-only tool: Extracts URLs from content.
class ExtractUrlsTool implements AiTool {
  @override
  String get name => 'extract_urls';

  @override
  String get description =>
      'Trích xuất tất cả các đường dẫn URL hoặc endpoint từ văn bản.';

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
    final features = const ClipboardFeatureExtractor().extract(
      content: text,
      contentType: ClipboardContentType.text,
    );
    final matches = features.urls;
    return AiToolResult<UrlExtractionPayload>(
      status: matches.isEmpty ? AiToolStatus.empty : AiToolStatus.success,
      code: matches.isEmpty ? 'url.extract.empty' : 'url.extract.success',
      payload: UrlExtractionPayload(matches),
      legacyOutput: matches.isNotEmpty
          ? 'Đã trích xuất ${matches.length} URL:\n${matches.join('\n')}'
          : 'Không tìm thấy URL nào trong văn bản.',
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
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
      final visibleCollections = collections
          .where((collection) => !collection.isVault)
          .toList(growable: false);
      final list = visibleCollections
          .map((c) => '- [collection:${c.id}] ${c.name}')
          .join('\n');
      return AiToolResult.ok(
        visibleCollections.isNotEmpty
            ? 'Danh sách bộ sưu tập:\n$list'
            : 'Chưa có bộ sưu tập nào.',
        visibleCollections,
      );
    }
    return AiToolResult.ok('Danh sách bộ sưu tập hiện trống.');
  }
}

/// Mutating tool: Pins or unpins a clipboard item.
class PinClipboardTool implements AiTool {
  PinClipboardTool([this._repository, this._clipboardHistory = const []]);

  final ClipboardRepository? _repository;
  final List<ClipboardItem> _clipboardHistory;

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

    if (_repository == null) {
      return AiToolResult.error(
        'Không thể thao tác: Repository chưa được khởi tạo.',
      );
    }
    if (clipId.isEmpty) {
      return AiToolResult.error('Tham số clip_id không hợp lệ.');
    }

    final item = await _findItemInRepoOrHistory(
      clipId,
      _clipboardHistory,
      _repository,
    );
    if (item == null) {
      return AiToolResult.notFound(
        'Không tìm thấy mục clipboard [clip:$clipId] để ghim.',
      );
    }

    await _repository.setPinned(clipId, pinned);
    return AiToolResult.ok(
      'Đã ${pinned ? 'ghim' : 'bỏ ghim'} mục clipboard [clip:$clipId] thành công.',
    );
  }
}

/// Mutating tool: Adds a clipboard item to a collection.
class AddToCollectionTool implements AiTool {
  AddToCollectionTool([this._repository, this._clipboardHistory = const []]);

  final ClipboardRepository? _repository;
  final List<ClipboardItem> _clipboardHistory;

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

    if (_repository == null) {
      return AiToolResult.error(
        'Không thể thao tác: Repository chưa được khởi tạo.',
      );
    }
    if (clipId.isEmpty || collectionId.isEmpty) {
      return AiToolResult.error(
        'Tham số clip_id và collection_id không được để trống.',
      );
    }

    final item = await _findItemInRepoOrHistory(
      clipId,
      _clipboardHistory,
      _repository,
    );
    if (item == null) {
      return AiToolResult.notFound(
        'Không tìm thấy mục clipboard [clip:$clipId].',
      );
    }

    await _repository.addToCollection(clipId, collectionId);
    return AiToolResult.ok(
      'Đã thêm mục [clip:$clipId] vào bộ sưu tập [collection:$collectionId].',
    );
  }
}

/// Mutating tool: Deletes a clipboard item.
class DeleteClipboardItemTool implements AiTool {
  DeleteClipboardItemTool([
    this._repository,
    this._clipboardHistory = const [],
  ]);

  final ClipboardRepository? _repository;
  final List<ClipboardItem> _clipboardHistory;

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

    if (_repository == null) {
      return AiToolResult.error(
        'Không thể thao tác: Repository chưa được khởi tạo.',
      );
    }
    if (clipId.isEmpty) {
      return AiToolResult.error('Tham số clip_id không hợp lệ.');
    }

    final item = await _findItemInRepoOrHistory(
      clipId,
      _clipboardHistory,
      _repository,
    );
    if (item == null) {
      return AiToolResult.notFound(
        'Không tìm thấy mục clipboard [clip:$clipId] để xóa.',
      );
    }

    await _repository.deleteItem(clipId);
    return AiToolResult.ok('Đã xóa mục clipboard [clip:$clipId] thành công.');
  }
}
