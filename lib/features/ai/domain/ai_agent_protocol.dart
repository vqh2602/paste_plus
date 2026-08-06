import 'dart:async';

import '../../clipboard_history/domain/clipboard_item.dart';
import '../../clipboard_history/domain/search_query.dart';

enum ClipboardResultDisplayMode { list, imageGrid, urlList, codeList, fileList }

/// Localization intent for a title produced by the agent.
///
/// The agent never renders user-facing prose itself: it emits a semantic
/// [AiMessageTitle] and the Flutter layer resolves it against the app locale.
enum AiMessageTitleKind {
  resultCount,
  urlResultCount,
  imageResultCount,
  empty,
  savedResultSet,
  /// The selected clip is an image but the active model has no vision
  /// projector, so only OCR/metadata were used.
  imageNeedsVisionModel,
}

class AiMessageTitle {
  const AiMessageTitle({required this.kind, this.count = 0});

  final AiMessageTitleKind kind;
  final int count;
}

sealed class AiMessageBlock {
  const AiMessageBlock();
}

class AiTextBlock extends AiMessageBlock {
  const AiTextBlock(this.text);
  final String text;
}

/// A title that must be localized by the UI before display.
class AiLocalizedTitleBlock extends AiMessageBlock {
  const AiLocalizedTitleBlock(this.title);
  final AiMessageTitle title;
}

class AiClipboardListBlock extends AiMessageBlock {
  const AiClipboardListBlock({
    required this.resultSetId,
    required this.items,
    this.title,
    this.hasMore = false,
  });
  final String resultSetId;
  final List<ClipboardItem> items;
  final String? title;
  final bool hasMore;
}

class AiClipboardGridBlock extends AiMessageBlock {
  const AiClipboardGridBlock({
    required this.resultSetId,
    required this.items,
    this.title,
    this.crossAxisCount = 3,
    this.hasMore = false,
  });
  final String resultSetId;
  final List<ClipboardItem> items;
  final String? title;
  final int crossAxisCount;
  final bool hasMore;
}

class AiUrlListBlock extends AiMessageBlock {
  const AiUrlListBlock({
    required this.resultSetId,
    required this.items,
    required this.urlsByClipboardId,
    this.title,
  });
  final String resultSetId;
  final List<ClipboardItem> items;
  final Map<String, List<String>> urlsByClipboardId;
  final String? title;
}

class AiCollectionListBlock extends AiMessageBlock {
  const AiCollectionListBlock(this.collections);
  final List<ClipboardCollection> collections;
}

class AiActionReceiptBlock extends AiMessageBlock {
  const AiActionReceiptBlock(this.receipt);
  final AiActionReceipt receipt;
}

class AiErrorBlock extends AiMessageBlock {
  const AiErrorBlock({required this.code, required this.localizedMessageKey});
  final String code;
  final String localizedMessageKey;
}

class AiAssistantResponse {
  const AiAssistantResponse({required this.blocks, this.resultSetIds = const []});
  final List<AiMessageBlock> blocks;
  final List<String> resultSetIds;
}

class AiUserRequest {
  const AiUserRequest({
    required this.text,
    this.localeTag = 'vi',
    this.selectedClipboardIds = const [],
  });
  final String text;
  final String localeTag;
  final List<String> selectedClipboardIds;
}

class AiActionReceipt {
  const AiActionReceipt({
    required this.code,
    required this.affectedItemIds,
    required this.affectedCount,
    this.collectionId,
  });
  final String code;
  final List<String> affectedItemIds;
  final int affectedCount;
  final String? collectionId;
}

class AiConfirmationRequest {
  AiConfirmationRequest({
    required this.actionCode,
    required this.itemIds,
    required this.previewItems,
    this.collectionName,
  });
  final String actionCode;
  final List<String> itemIds;
  final List<ClipboardItem> previewItems;
  final String? collectionName;
  final Completer<bool> _completer = Completer<bool>();
  Future<bool> get decision => _completer.future;
  void complete(bool approved) {
    if (!_completer.isCompleted) _completer.complete(approved);
  }
}

sealed class AiAgentEvent {
  const AiAgentEvent();
}

class AiThinkingStarted extends AiAgentEvent {
  const AiThinkingStarted();
}

class AiThinkingDelta extends AiAgentEvent {
  const AiThinkingDelta(this.text);
  final String text;
}

class AiTextDelta extends AiAgentEvent {
  const AiTextDelta(this.text);
  final String text;
}

class AiToolStarted extends AiAgentEvent {
  const AiToolStarted({
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
  });
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> arguments;
}

class AiToolProgress extends AiAgentEvent {
  const AiToolProgress({
    required this.toolCallId,
    required this.messageCode,
    this.progress,
  });
  final String toolCallId;
  final String messageCode;
  final double? progress;
}

class AiUiBlockProduced extends AiAgentEvent {
  const AiUiBlockProduced(this.block);
  final AiMessageBlock block;
}

class AiConfirmationRequested extends AiAgentEvent {
  const AiConfirmationRequested(this.request);
  final AiConfirmationRequest request;
}

class AiActionCompleted extends AiAgentEvent {
  const AiActionCompleted(this.receipt);
  final AiActionReceipt receipt;
}

class AiAgentCompleted extends AiAgentEvent {
  const AiAgentCompleted({required this.response});
  final AiAssistantResponse response;
}

class AiAgentFailed extends AiAgentEvent {
  const AiAgentFailed({required this.code, this.debugMessage});
  final String code;
  final String? debugMessage;
}

abstract interface class AiAgentEngine {
  Stream<AiAgentEvent> execute(AiUserRequest request);
}

class AgentResultSet {
  const AgentResultSet({
    required this.id,
    required this.itemIds,
    required this.createdAt,
    required this.sourceTool,
    required this.query,
  });
  final String id;
  final List<String> itemIds;
  final DateTime createdAt;
  final String sourceTool;
  final ClipboardSearchQuery query;
}

class AiAgentSessionContext {
  const AiAgentSessionContext({
    this.resultSets = const {},
    this.activeResultSetId,
    this.selectedClipboardIds = const [],
  });
  final Map<String, AgentResultSet> resultSets;
  final String? activeResultSetId;
  final List<String> selectedClipboardIds;

  AgentResultSet? get activeResultSet =>
      activeResultSetId == null ? null : resultSets[activeResultSetId];

  AiAgentSessionContext remember(AgentResultSet resultSet) =>
      AiAgentSessionContext(
        resultSets: {...resultSets, resultSet.id: resultSet},
        activeResultSetId: resultSet.id,
        selectedClipboardIds: selectedClipboardIds,
      );
}

enum ClipboardReferenceSelectionType { all, first, last, positions }

class ClipboardReference {
  const ClipboardReference({
    this.selectionType = ClipboardReferenceSelectionType.all,
    this.count = 1,
    this.positions = const [],
  });
  final ClipboardReferenceSelectionType selectionType;
  final int count;
  final List<int> positions;
}

class ClipboardReferenceResolver {
  const ClipboardReferenceResolver();

  List<String> resolve({
    required ClipboardReference reference,
    required AiAgentSessionContext session,
  }) {
    final ids = session.activeResultSet?.itemIds ?? session.selectedClipboardIds;
    return switch (reference.selectionType) {
      ClipboardReferenceSelectionType.all => List.of(ids),
      ClipboardReferenceSelectionType.first => ids.take(reference.count).toList(),
      ClipboardReferenceSelectionType.last => ids.isEmpty ? const [] : [ids.last],
      ClipboardReferenceSelectionType.positions => [
          for (final position in reference.positions)
            if (position > 0 && position <= ids.length) ids[position - 1],
        ],
    };
  }
}

String redactClipboardPreview(ClipboardItem item, {int maxLength = 180}) {
  if (item.isSensitive) return '••••••';
  var value = item.content
      .replaceAll(
        RegExp(
          r'(token|password|secret|api[_-]?key)\s*[:=]\s*[^\s,;]+',
          caseSensitive: false,
        ),
        r'$1=••••••',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return value.length <= maxLength ? value : '${value.substring(0, maxLength)}…';
}
