import 'package:clipflow/features/ai/data/ai_conversation_repository.dart';
import 'package:clipflow/features/ai/presentation/widgets/ai_conversation_history_action.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('more button does not trigger opening the conversation', (
    tester,
  ) async {
    var openCount = 0;
    var moreCount = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: AiConversationHistoryAction(
              conversation: const SavedAiConversation(
                messages: [],
                title: 'Test conversation',
              ),
              onOpen: () => openCount++,
              onMore: () => moreCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pump();

    expect(moreCount, 1);
    expect(openCount, 0);
  });
}
