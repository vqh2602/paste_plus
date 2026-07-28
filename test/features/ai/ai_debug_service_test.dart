import 'package:clipflow/core/services/ai_debug_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI debug unlocks only after ten app icon taps', () {
    final controller = AiDebugController();

    for (var tap = 1; tap < 10; tap++) {
      expect(controller.registerAppIconTap(), isFalse);
      expect(controller.state.isEnabled, isFalse);
    }

    expect(controller.registerAppIconTap(), isTrue);
    expect(controller.state.isEnabled, isTrue);
    expect(controller.state.entries, hasLength(1));
  });

  test('AI debug records details only while enabled', () {
    final controller = AiDebugController();
    controller.log(
      level: AiDebugLevel.info,
      stage: 'context',
      message: 'disabled log',
      details: 'secret context',
    );
    expect(controller.state.entries, isEmpty);

    for (var tap = 0; tap < 10; tap++) {
      controller.registerAppIconTap();
    }
    controller.clear();
    controller.log(
      level: AiDebugLevel.success,
      stage: 'response',
      requestId: 'request-1',
      message: 'completed',
      details: 'full AI output',
    );

    expect(controller.state.entries, hasLength(1));
    expect(controller.exportText(), contains('full AI output'));
    expect(controller.exportText(), contains('request:request-1'));
  });
}
