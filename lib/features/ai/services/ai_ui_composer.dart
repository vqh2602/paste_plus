import '../../clipboard_history/domain/clipboard_feature_extractor.dart';
import '../domain/ai_agent_protocol.dart';
import '../tools/ai_tool.dart';

class AiUiComposer {
  const AiUiComposer();

  List<AiMessageBlock> composeToolResult(AiToolResult result) {
    final payload = result.payload;
    if (payload is ClipboardSearchPayload) return _composeClipboardSearch(payload);
    if (payload is ClipboardMutationPayload) {
      return [
        AiActionReceiptBlock(
          AiActionReceipt(
            code: result.code,
            affectedItemIds: payload.itemIds,
            affectedCount: payload.affectedCount,
            collectionId: payload.collectionId,
          ),
        ),
      ];
    }
    if (payload is CollectionPayload) {
      return [AiCollectionListBlock(payload.collections)];
    }
    return [
      AiErrorBlock(code: result.code, localizedMessageKey: result.code),
    ];
  }

  List<AiMessageBlock> _composeClipboardSearch(ClipboardSearchPayload payload) {
    if (payload.items.isEmpty) {
      return const [
        AiLocalizedTitleBlock(AiMessageTitle(kind: AiMessageTitleKind.empty)),
      ];
    }
    final titleBlock = AiLocalizedTitleBlock(
      AiMessageTitle(
        kind: switch (payload.displayMode) {
          ClipboardResultDisplayMode.urlList =>
            AiMessageTitleKind.urlResultCount,
          ClipboardResultDisplayMode.imageGrid =>
            AiMessageTitleKind.imageResultCount,
          _ => AiMessageTitleKind.resultCount,
        },
        count: payload.total,
      ),
    );
    final resultBlock = switch (payload.displayMode) {
      ClipboardResultDisplayMode.imageGrid => AiClipboardGridBlock(
          resultSetId: payload.resultSetId,
          items: payload.items,
          hasMore: payload.hasMore,
        ),
      ClipboardResultDisplayMode.urlList => AiUrlListBlock(
          resultSetId: payload.resultSetId,
          items: payload.items,
          urlsByClipboardId: {
            for (final item in payload.items)
              item.id: const ClipboardFeatureExtractor()
                  .extract(
                    content: item.content,
                    contentType: item.contentType,
                    imagePath: item.imagePath,
                    metadataJson: item.metadataJson,
                    note: item.note,
                    sourceAppName: item.sourceAppName,
                  )
                  .urls,
          },
        ),
      _ => AiClipboardListBlock(
          resultSetId: payload.resultSetId,
          items: payload.items,
          hasMore: payload.hasMore,
        ),
    };
    return [titleBlock, resultBlock];
  }
}
