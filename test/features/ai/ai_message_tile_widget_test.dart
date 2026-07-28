import 'package:clipflow/core/ui/cupertino_components.dart';
import 'package:clipflow/features/ai/domain/ai_chat_message.dart';
import 'package:clipflow/features/ai/presentation/widgets/ai_message_tile_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders markdown and copies one clipboard result without metadata',
    (tester) async {
      String? copied;
      final message = AiChatMessage(
        id: 'assistant',
        role: AiMessageRole.assistant,
        content: '''Đã tìm thấy **1 kết quả**:

1. **URL** — Safari
   https://flutter.dev''',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: AiMessageTileWidget(
              message: message,
              onCopy: (value) => copied = value,
              onPaste: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('**'), findsNothing);
      expect(find.textContaining('1 kết quả'), findsOneWidget);
      expect(find.textContaining('https://flutter.dev'), findsOneWidget);

      final resultBlock = find.byKey(const ValueKey('ai-response-block-1'));
      await tester.tap(
        find.descendant(
          of: resultBlock,
          matching: find.byType(CupertinoIconControl),
        ),
      );
      expect(copied, 'https://flutter.dev');
    },
  );

  testWidgets('renders and copies fenced code without markdown fences', (
    tester,
  ) async {
    String? copied;
    final message = AiChatMessage(
      id: 'code',
      role: AiMessageRole.assistant,
      content: '```dart\nfinal value = 42;\n```',
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: AiMessageTileWidget(
            message: message,
            onCopy: (value) => copied = value,
            onPaste: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('final value = 42;'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ai-response-block-0')),
        matching: find.byType(CupertinoIconControl),
      ),
    );
    expect(copied, 'final value = 42;');
  });
}
