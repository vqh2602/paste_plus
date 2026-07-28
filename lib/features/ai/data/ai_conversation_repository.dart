import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../clipboard_history/domain/clipboard_item.dart';
import '../domain/ai_chat_message.dart';
import '../domain/ai_feature_action.dart';

class SavedAiConversation {
  const SavedAiConversation({
    required this.messages,
    this.clipboardContext,
    this.id = 'current',
    this.title = 'Hội thoại gần nhất',
    this.isPinned = false,
  });

  final List<AiChatMessage> messages;
  final ClipboardItem? clipboardContext;
  final String id;
  final String title;
  final bool isPinned;
}

class AiConversationRepository {
  const AiConversationRepository();

  static const _storageKey = 'clipflow.ai.conversation.v1';
  static const _archiveKey = 'clipflow.ai.sessions.v1';
  static const maxStoredMessages = 24;
  static const retention = Duration(days: 7);

  Future<SavedAiConversation> load() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_storageKey);
    if (source == null || source.isEmpty) {
      return const SavedAiConversation(messages: []);
    }

    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final messages = (json['messages'] as List<dynamic>? ?? const [])
          .map((entry) => _messageFromJson(entry as Map<String, dynamic>))
          .where(
            (message) =>
                message.content.trim().isNotEmpty &&
                message.timestamp.isAfter(DateTime.now().subtract(retention)),
          )
          .toList(growable: false);
      final contextJson = json['clipboardContext'];
      return SavedAiConversation(
        messages: messages,
        clipboardContext: contextJson is Map<String, dynamic>
            ? ClipboardItem.fromMap(contextJson).isSensitive
                  ? null
                  : ClipboardItem.fromMap(contextJson)
            : null,
      );
    } on Object {
      return const SavedAiConversation(messages: []);
    }
  }

  Future<void> save({
    required List<AiChatMessage> messages,
    required ClipboardItem? clipboardContext,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final recentMessages = messages
        .where(
          (message) =>
              !message.isThinking &&
              message.content.isNotEmpty &&
              message.clipboardContext?.isSensitive != true,
        )
        .toList(growable: false);
    final start = recentMessages.length > maxStoredMessages
        ? recentMessages.length - maxStoredMessages
        : 0;
    await preferences.setString(
      _storageKey,
      jsonEncode({
        'messages': recentMessages
            .skip(start)
            .map(_messageToJson)
            .toList(growable: false),
        'clipboardContext': clipboardContext?.isSensitive == true
            ? null
            : clipboardContext?.toMap(),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<List<SavedAiConversation>> loadSessions() async {
    final preferences = await SharedPreferences.getInstance();
    final source = preferences.getString(_archiveKey);
    if (source == null) return const [];
    try {
      final entries = jsonDecode(source) as List<dynamic>;
      final sessions = entries
          .map((entry) => _conversationFromJson(entry as Map<String, dynamic>))
          .where((session) => session.messages.isNotEmpty)
          .toList(growable: false);
      return sessions;
    } on Object {
      return const [];
    }
  }

  Future<void> archive({
    required List<AiChatMessage> messages,
    required ClipboardItem? clipboardContext,
  }) async {
    if (messages.isEmpty) return;
    final sessions = await loadSessions();
    final firstUser = messages.firstWhere(
      (message) => message.role == AiMessageRole.user,
      orElse: () => messages.first,
    );
    final title = firstUser.content.length > 48
        ? '${firstUser.content.substring(0, 48)}…'
        : firstUser.content;
    final session = SavedAiConversation(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      messages: messages,
      clipboardContext: clipboardContext?.isSensitive == true
          ? null
          : clipboardContext,
    );
    await _saveSessions([session, ...sessions].take(20).toList());
  }

  Future<void> deleteSession(String id) async {
    final sessions = await loadSessions();
    await _saveSessions(sessions.where((session) => session.id != id).toList());
  }

  Future<void> renameSession(String id, String title) async {
    final sessions = await loadSessions();
    await _saveSessions([
      for (final session in sessions)
        session.id == id
            ? SavedAiConversation(
                id: session.id,
                title: title,
                isPinned: session.isPinned,
                messages: session.messages,
                clipboardContext: session.clipboardContext,
              )
            : session,
    ]);
  }

  Future<void> togglePinned(String id) async {
    final sessions = await loadSessions();
    final updated = [
      for (final session in sessions)
        session.id == id
            ? SavedAiConversation(
                id: session.id,
                title: session.title,
                isPinned: !session.isPinned,
                messages: session.messages,
                clipboardContext: session.clipboardContext,
              )
            : session,
    ]..sort((a, b) => a.isPinned == b.isPinned ? 0 : (a.isPinned ? -1 : 1));
    await _saveSessions(updated);
  }

  Future<void> _saveSessions(List<SavedAiConversation> sessions) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _archiveKey,
      jsonEncode(sessions.map(_conversationToJson).toList(growable: false)),
    );
  }

  Map<String, Object?> _conversationToJson(SavedAiConversation session) => {
    'id': session.id,
    'title': session.title,
    'isPinned': session.isPinned,
    'messages': session.messages
        .where(
          (message) =>
              !message.isThinking &&
              message.content.isNotEmpty &&
              message.clipboardContext?.isSensitive != true,
        )
        .map(_messageToJson)
        .toList(growable: false),
    'clipboardContext': session.clipboardContext?.isSensitive == true
        ? null
        : session.clipboardContext?.toMap(),
  };

  SavedAiConversation _conversationFromJson(Map<String, dynamic> json) {
    final contextJson = json['clipboardContext'];
    return SavedAiConversation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Hội thoại',
      isPinned: json['isPinned'] as bool? ?? false,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .map((entry) => _messageFromJson(entry as Map<String, dynamic>))
          .where((message) => message.content.isNotEmpty)
          .toList(growable: false),
      clipboardContext: contextJson is Map<String, dynamic>
          ? ClipboardItem.fromMap(contextJson)
          : null,
    );
  }

  Map<String, Object?> _messageToJson(AiChatMessage message) => {
    'id': message.id,
    'role': message.role.name,
    'content': message.content,
    'featureGroup': message.featureGroup?.name,
    'selectedOption': message.selectedOption,
    'clipboardContext': message.clipboardContext?.toMap(),
    'timestamp': message.timestamp.millisecondsSinceEpoch,
  };

  AiChatMessage _messageFromJson(Map<String, dynamic> json) {
    final contextJson = json['clipboardContext'];
    return AiChatMessage(
      id: json['id'] as String? ?? '',
      role: AiMessageRole.values.firstWhere(
        (role) => role.name == json['role'],
        orElse: () => AiMessageRole.assistant,
      ),
      content: json['content'] as String? ?? '',
      featureGroup: AiFeatureGroup.values.cast<AiFeatureGroup?>().firstWhere(
        (group) => group?.name == json['featureGroup'],
        orElse: () => null,
      ),
      selectedOption: json['selectedOption'] as String?,
      clipboardContext: contextJson is Map<String, dynamic>
          ? ClipboardItem.fromMap(contextJson)
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
