import '../../clipboard_history/domain/clipboard_item.dart';
import 'ai_feature_action.dart';
import 'ai_agent_protocol.dart';

enum AiMessageRole { user, assistant, system }

class AiChatMessage {
  AiChatMessage({
    required this.id,
    required this.role,
    String? content,
    List<AiMessageBlock>? blocks,
    this.thinkingContent,
    this.isThinking = false,
    this.featureGroup,
    this.selectedOption,
    this.clipboardContext,
    this.resultSetIds = const [],
    DateTime? timestamp,
  }) : blocks = blocks ??
            (content == null || content.isEmpty
                ? <AiMessageBlock>[]
                : <AiMessageBlock>[AiTextBlock(content)]),
       timestamp = timestamp ?? DateTime.now();

  final String id;
  final AiMessageRole role;
  List<AiMessageBlock> blocks;
  String? thinkingContent;
  bool isThinking;
  final AiFeatureGroup? featureGroup;
  final String? selectedOption;
  final ClipboardItem? clipboardContext;
  final DateTime timestamp;
  final List<String> resultSetIds;

  String get plainText => blocks
      .whereType<AiTextBlock>()
      .map((block) => block.text)
      .join('\n');

  String get content => plainText;
  set content(String value) {
    final structured = blocks.where((block) => block is! AiTextBlock).toList();
    blocks = [if (value.isNotEmpty) AiTextBlock(value), ...structured];
  }

  AiChatMessage copyWith({
    String? content,
    String? thinkingContent,
    bool? isThinking,
    ClipboardItem? clipboardContext,
    List<AiMessageBlock>? blocks,
    List<String>? resultSetIds,
  }) {
    return AiChatMessage(
      id: id,
      role: role,
      blocks: blocks ??
          (content == null ? List.of(this.blocks) : <AiMessageBlock>[AiTextBlock(content)]),
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isThinking: isThinking ?? this.isThinking,
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      clipboardContext: clipboardContext ?? this.clipboardContext,
      resultSetIds: resultSetIds ?? this.resultSetIds,
      timestamp: timestamp,
    );
  }
}
