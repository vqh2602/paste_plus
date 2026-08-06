import '../../clipboard_history/domain/clipboard_item.dart';
import '../../clipboard_history/domain/search_query.dart';
import '../domain/ai_agent_protocol.dart';

enum AiToolStatus {
  success,
  empty,
  rejected,
  notFound,
  invalidArguments,
  permissionDenied,
  failed,
}

sealed class AiToolPayload {
  const AiToolPayload();
}

class AiLegacyPayload extends AiToolPayload {
  const AiLegacyPayload(this.value);
  final dynamic value;
}

class ClipboardSearchPayload extends AiToolPayload {
  const ClipboardSearchPayload({
    required this.query,
    required this.items,
    required this.total,
    required this.hasMore,
    required this.resultSetId,
    required this.displayMode,
  });
  final ClipboardSearchQuery query;
  final List<ClipboardItem> items;
  final int total;
  final bool hasMore;
  final String resultSetId;
  final ClipboardResultDisplayMode displayMode;
}

class ClipboardMutationPayload extends AiToolPayload {
  const ClipboardMutationPayload({
    required this.action,
    required this.itemIds,
    required this.affectedCount,
    this.collectionId,
  });
  final String action;
  final List<String> itemIds;
  final int affectedCount;
  final String? collectionId;
}

class CollectionPayload extends AiToolPayload {
  const CollectionPayload(this.collections);
  final List<ClipboardCollection> collections;
}

class UrlExtractionPayload extends AiToolPayload {
  const UrlExtractionPayload(this.urls);
  final List<String> urls;
}

class AiToolResult<T extends AiToolPayload> {
  const AiToolResult({
    required this.status,
    required this.code,
    this.payload,
    this.debugMessage,
    this.legacyOutput,
  });

  factory AiToolResult.ok(String output, [dynamic data]) => AiToolResult<T>(
        status: AiToolStatus.success,
        code: 'tool.success',
        payload: AiLegacyPayload(data) as T?,
        legacyOutput: output,
      );

  factory AiToolResult.error(String message) => AiToolResult<T>(
        status: AiToolStatus.failed,
        code: 'tool.failed',
        debugMessage: message,
        legacyOutput: message,
      );

  factory AiToolResult.notFound(String message) => AiToolResult<T>(
        status: AiToolStatus.notFound,
        code: 'tool.not_found',
        debugMessage: message,
        legacyOutput: message,
      );

  factory AiToolResult.cancelled(String reason) => AiToolResult<T>(
        status: AiToolStatus.rejected,
        code: 'tool.rejected',
        debugMessage: reason,
        legacyOutput: reason,
      );

  final AiToolStatus status;
  final String code;
  final T? payload;
  final String? debugMessage;
  final String? legacyOutput;

  bool get success => status == AiToolStatus.success || status == AiToolStatus.empty;
  bool get cancelled => status == AiToolStatus.rejected;
  String get output => legacyOutput ?? code;
  dynamic get data => switch (payload) {
        AiLegacyPayload(:final value) => value,
        ClipboardSearchPayload(:final items) => items,
        CollectionPayload(:final collections) => collections,
        UrlExtractionPayload(:final urls) => urls,
        _ => payload,
      };

  Map<String, dynamic> toJson() => {
        'success': success,
        'code': code,
        'cancelled': cancelled,
      };
}

abstract interface class AiTool {
  String get name;
  String get description;
  bool get requiresConfirmation;
  Map<String, dynamic> get inputSchema;
  Future<AiToolResult> execute(Map<String, dynamic> arguments);
}
