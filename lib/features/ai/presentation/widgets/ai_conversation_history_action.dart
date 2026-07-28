import 'package:flutter/cupertino.dart';

import '../../data/ai_conversation_repository.dart';

class AiConversationHistoryAction extends StatelessWidget {
  const AiConversationHistoryAction({
    super.key,
    required this.conversation,
    required this.onOpen,
    required this.onMore,
  });

  final SavedAiConversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              padding: const EdgeInsets.only(left: 48, right: 8),
              onPressed: onOpen,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (conversation.isPinned) ...[
                    const Icon(CupertinoIcons.pin_fill, size: 14),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            minimumSize: const Size(48, 48),
            onPressed: onMore,
            child: const Icon(CupertinoIcons.ellipsis, size: 18),
          ),
        ],
      ),
    );
  }
}
