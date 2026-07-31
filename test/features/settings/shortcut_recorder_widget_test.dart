import 'package:clipflow/core/platform/shortcut_config.dart';
import 'package:clipflow/features/settings/presentation/widgets/shortcut_recorder_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

void main() {
  testWidgets('records the complete combination and waits for confirmation', (
    tester,
  ) async {
    HotKey? result;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async {
                result = await showCupertinoDialog<HotKey>(
                  context: context,
                  builder: (_) => const ShortcutRecorderDialog(
                    action: ShortcutAction.openPanel,
                  ),
                );
              },
              child: const Text('Record'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    var confirm = tester.widget<CupertinoDialogAction>(
      find.byKey(const Key('shortcut-recording-confirm')),
    );
    expect(confirm.onPressed, isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(result, isNull);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    confirm = tester.widget<CupertinoDialogAction>(
      find.byKey(const Key('shortcut-recording-confirm')),
    );
    expect(confirm.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('shortcut-recording-confirm')));
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(result, isNotNull);
    expect(result!.physicalKey, PhysicalKeyboardKey.keyK);
    expect(
      result!.modifiers,
      containsAll([HotKeyModifier.control, HotKeyModifier.shift]),
    );
  });

  testWidgets('cancel restores events through the row callbacks', (
    tester,
  ) async {
    var started = 0;
    var canceled = 0;
    var changed = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ShortcutRowWidget(
            title: 'Quick Panel',
            shortcut: 'Ctrl+Shift+V',
            action: ShortcutAction.openPanel,
            onRecordingStarted: () async => started++,
            onRecordingCanceled: () async => canceled++,
            onChanged: (_) async => changed++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ctrl+Shift+V'));
    await tester.pumpAndSettle();
    expect(started, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(canceled, 1);
    expect(changed, 0);
  });
}
