import 'package:clipflow/features/ai/presentation/widgets/ai_mobile_toolbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile toolbar keeps close, context, and history visible', (
    tester,
  ) async {
    var closeCount = 0;
    var contextCount = 0;
    var historyCount = 0;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox(
            width: 320,
            child: AiMobileToolbar(
              onClose: () => closeCount++,
              onChooseContext: () => contextCount++,
              onShowHistory: () => historyCount++,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('ai-mobile-close')), findsOneWidget);
    expect(find.byKey(const Key('ai-mobile-context')), findsOneWidget);
    expect(find.byKey(const Key('ai-mobile-history')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('ai-mobile-close')));
    await tester.tap(find.byKey(const Key('ai-mobile-context')));
    await tester.tap(find.byKey(const Key('ai-mobile-history')));

    expect((closeCount, contextCount, historyCount), (1, 1, 1));
  });
}
