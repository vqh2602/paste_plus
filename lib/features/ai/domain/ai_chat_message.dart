import '../../clipboard_history/domain/clipboard_item.dart';
import 'ai_feature_action.dart';

enum AiMessageRole { user, assistant, system }

class AiChatMessage {
  AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.thinkingContent,
    this.isThinking = false,
    this.featureGroup,
    this.selectedOption,
    this.clipboardContext,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String id;
  final AiMessageRole role;
  String content;
  String? thinkingContent;
  bool isThinking;
  final AiFeatureGroup? featureGroup;
  final String? selectedOption;
  final ClipboardItem? clipboardContext;
  final DateTime timestamp;

  AiChatMessage copyWith({
    String? content,
    String? thinkingContent,
    bool? isThinking,
  }) {
    return AiChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      isThinking: isThinking ?? this.isThinking,
      featureGroup: featureGroup,
      selectedOption: selectedOption,
      clipboardContext: clipboardContext,
      timestamp: timestamp,
    );
  }
}
