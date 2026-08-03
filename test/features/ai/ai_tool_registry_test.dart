import 'package:clipflow/features/ai/tools/ai_tool_registry.dart';
import 'package:clipflow/features/ai/tools/impl/clipboard_tools.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late AiToolRegistry registry;

  setUp(() {
    registry = AiToolRegistry();
    registry.register(SearchClipboardTool([]));
    registry.register(GetClipboardItemTool([]));
    registry.register(ExtractUrlsTool());
    registry.register(ListCollectionsTool());
    registry.register(PinClipboardTool());
    registry.register(AddToCollectionTool());
    registry.register(DeleteClipboardItemTool());
  });

  group('AiToolRegistry', () {
    test('registers and retrieves tools correctly', () {
      expect(registry.getTool('search_clipboard'), isNotNull);
      expect(registry.getTool('pin_clipboard'), isNotNull);
      expect(registry.getTool('unknown_tool'), isNull);

      final definitions = registry.toToolDefinitions();
      expect(definitions.length, 7);
    });

    test('read-only tool executes without requesting confirmation', () async {
      var confirmationRequested = false;

      final result = await registry.execute(
        'extract_urls',
        {'text': 'Check this link https://flutter.dev for docs.'},
        onConfirmationRequested: (tool, args) async {
          confirmationRequested = true;
          return true;
        },
      );

      expect(confirmationRequested, isFalse);
      expect(result.success, isTrue);
      expect(result.output, contains('https://flutter.dev'));
    });

    test('mutating tool requests confirmation and respects cancellation', () async {
      var confirmationRequested = false;

      // User rejects pin tool
      final cancelledResult = await registry.execute(
        'pin_clipboard',
        {'clip_id': 'clip_123', 'pinned': true},
        onConfirmationRequested: (tool, args) async {
          confirmationRequested = true;
          return false;
        },
      );

      expect(confirmationRequested, isTrue);
      expect(cancelledResult.success, isFalse);
      expect(cancelledResult.cancelled, isTrue);
      expect(cancelledResult.output, contains('từ chối'));

      // User approves pin tool
      final approvedResult = await registry.execute(
        'pin_clipboard',
        {'clip_id': 'clip_123', 'pinned': true},
        onConfirmationRequested: (tool, args) async {
          return true;
        },
      );

      expect(approvedResult.success, isTrue);
      expect(approvedResult.output, contains('ghim'));
    });
  });
}
