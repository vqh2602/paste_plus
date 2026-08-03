import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/features/ai/tools/ai_tool_registry.dart';
import 'package:clipflow/features/ai/tools/impl/clipboard_tools.dart';

import 'package:flutter_test/flutter_test.dart';

class FakeToolRepository implements ClipboardRepository {
  final List<ClipboardItem> items = [
    ClipboardItem(
      id: 'clip_123',
      content: 'Sample text 123',
      normalizedContent: 'sample text 123',
      contentHash: 'hash123',
      contentType: ClipboardContentType.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCopiedAt: DateTime.now(),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
    ),
    ClipboardItem(
      id: 'clip_abc',
      content: 'Sample text abc',
      normalizedContent: 'sample text abc',
      contentHash: 'hashabc',
      contentType: ClipboardContentType.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCopiedAt: DateTime.now(),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
    ),
    ClipboardItem(
      id: 'clip_test',
      content: 'Sample text test',
      normalizedContent: 'sample text test',
      contentHash: 'hashtest',
      contentType: ClipboardContentType.text,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastCopiedAt: DateTime.now(),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
    ),
  ];

  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async => items;

  @override
  Future<void> setPinned(String id, bool pinned) async {}

  @override
  Future<void> addToCollection(String itemId, String collectionId) async {}

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<ClipboardItem?> store(ClipboardPayload payload, AppSettings settings) async => null;

  @override
  Future<void> markCopied(String id) async {}

  @override
  Future<void> updateMetadata(String id, String metadataJson) async {}

  @override
  Future<void> clearHistory({bool includePinned = false}) async {}

  @override
  Future<List<ClipboardCollection>> getCollections() async => [];

  @override
  Future<ClipboardCollection> createCollection(String name) async => ClipboardCollection(
    id: 'col_1', name: name, icon: 'folder', createdAt: DateTime.now(), updatedAt: DateTime.now(), sortOrder: 0,
  );

  @override
  Future<void> upsertCollection(ClipboardCollection collection) async {}

  @override
  Future<void> renameCollection(String id, String name) async {}

  @override
  Future<void> deleteCollection(String id) async {}

  @override
  Future<void> removeFromCollection(String itemId, String collectionId) async {}

  @override
  Future<Set<String>> collectionIdsForItem(String itemId) async => {};

  @override
  Future<void> cleanup(AppSettings settings) async {}

  @override
  Future<int> approximateStorageBytes() async => 0;
}

void main() {
  late AiToolRegistry registry;
  late FakeToolRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeToolRepository();
    registry = AiToolRegistry();
    registry.register(SearchClipboardTool(fakeRepo.items, fakeRepo));
    registry.register(GetClipboardItemTool(fakeRepo.items, fakeRepo));
    registry.register(ExtractUrlsTool());
    registry.register(ListCollectionsTool(fakeRepo));
    registry.register(PinClipboardTool(fakeRepo, fakeRepo.items));
    registry.register(AddToCollectionTool(fakeRepo, fakeRepo.items));
    registry.register(DeleteClipboardItemTool(fakeRepo, fakeRepo.items));
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

    test('mutating tool is blocked (fail-closed) when no confirmation callback provided', () async {
      // Fix #9: Without a callback, mutating tools must be cancelled, not executed
      final result = await registry.execute(
        'delete_clipboard_item',
        {'clip_id': 'clip_abc'},
        // No onConfirmationRequested provided
      );

      expect(result.success, isFalse);
      expect(result.cancelled, isTrue);
      expect(result.output, contains('xác nhận'));
    });

    test('mutating tool is blocked when callback is null regardless of tool type', () async {
      // All mutating tools must fail-closed — test pin and add_to_collection
      for (final toolName in ['pin_clipboard', 'add_to_collection']) {
        final result = await registry.execute(
          toolName,
          {'clip_id': 'clip_test', 'collection_id': 'col_1', 'pinned': true},
        );
        expect(result.cancelled, isTrue,
            reason: '$toolName should be blocked without confirmation callback');
      }
    });
  });
}
