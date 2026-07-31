import 'dart:async';

import 'package:clipflow/app/providers.dart';
import 'package:clipflow/core/services/clipboard_watcher.dart';
import 'package:clipflow/core/ui/cupertino_components.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/presentation/home_screen.dart';
import 'package:clipflow/features/clipboard_history/presentation/history_controller.dart';
import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockClipboardWatcher implements ClipboardWatcher {
  final controller = StreamController<ClipboardPayload>.broadcast();
  ClipboardPayload? current;

  @override
  Future<ClipboardPayload?> readCurrent() async => current;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<ClipboardPayload> watch() => controller.stream;

  @override
  Future<void> write(ClipboardPayload payload) async {
    current = payload;
  }

  Future<void> dispose() => controller.close();
}

class InMemoryClipboardRepository implements ClipboardRepository {
  final items = <ClipboardItem>[
    ClipboardItem(
      id: 'item-1',
      content: 'https://flutter.dev',
      normalizedContent: 'https://flutter.dev',
      contentHash: 'hash',
      contentType: ClipboardContentType.url,
      createdAt: DateTime(2026, 7, 27),
      updatedAt: DateTime(2026, 7, 27),
      lastCopiedAt: DateTime(2026, 7, 27),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
    ),
  ];

  @override
  Future<void> addToCollection(String itemId, String collectionId) async {}

  @override
  Future<int> approximateStorageBytes() async => 0;

  @override
  Future<void> cleanup(AppSettings settings) async {}

  @override
  Future<void> clearHistory({bool includePinned = false}) async {
    items.removeWhere((item) => includePinned || !item.isPinned);
  }

  @override
  Future<ClipboardCollection> createCollection(String name) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertCollection(ClipboardCollection collection) async {}

  @override
  Future<void> deleteCollection(String id) async {}

  @override
  Future<void> deleteItem(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<Set<String>> collectionIdsForItem(String itemId) async => {};

  @override
  Future<List<ClipboardCollection>> getCollections() async => [];

  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async {
    return items
        .where(
          (item) =>
              (!pinnedOnly || item.isPinned) &&
              (type == null || item.contentType == type),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<void> markCopied(String id) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final item = items.removeAt(index);
    items.insert(
      0,
      item.copyWith(
        lastCopiedAt: DateTime.now(),
        copyCount: item.copyCount + 1,
      ),
    );
  }

  @override
  Future<void> removeFromCollection(String itemId, String collectionId) async {}

  @override
  Future<void> renameCollection(String id, String name) async {}

  @override
  Future<void> setPinned(String id, bool pinned) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(isPinned: pinned);
  }

  @override
  Future<void> updateMetadata(String id, String metadataJson) async {}

  @override
  Future<ClipboardItem?> store(
    ClipboardPayload payload,
    AppSettings settings,
  ) async => null;
}

void main() {
  late InMemoryClipboardRepository repository;
  late SettingsRepository settingsRepository;
  late MockClipboardWatcher watcher;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = InMemoryClipboardRepository();
    settingsRepository = SettingsRepository(
      await SharedPreferences.getInstance(),
    );
    await settingsRepository.save(
      const AppSettings(
        hasCompletedOnboarding: true,
        monitoringEnabled: false,
        ignoreSensitive: false,
      ),
    );
    watcher = MockClipboardWatcher();
  });

  tearDown(() async {
    await watcher.dispose();
  });

  Widget app({bool quickPanel = false}) => ProviderScope(
    overrides: [
      clipboardRepositoryProvider.overrideWithValue(repository),
      clipboardWatcherProvider.overrideWithValue(watcher),
      settingsRepositoryProvider.overrideWithValue(settingsRepository),
      if (quickPanel) quickPanelModeProvider.overrideWith((ref) => true),
    ],
    child: const CupertinoApp(home: HomeScreen()),
  );

  testWidgets('renders clipboard item and filters search instantly', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-item')), findsOneWidget);
    expect(find.textContaining('flutter.dev'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('history-search')),
      'không-tồn-tại',
    );
    await tester.pump();
    expect(find.text('Không tìm thấy kết quả'), findsOneWidget);
  });

  testWidgets('pin button persists pinned state', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pin-button')));
    await tester.pumpAndSettle();
    final pinned = await repository.getItems(pinnedOnly: true);
    expect(pinned, hasLength(1));
  });

  testWidgets('main history header shows AI button when AI is enabled', (
    tester,
  ) async {
    await settingsRepository.save(
      const AppSettings(
        hasCompletedOnboarding: true,
        monitoringEnabled: false,
        ignoreSensitive: false,
        aiEnabled: true,
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-ai-button')), findsOneWidget);
  });

  testWidgets('content filter supports multiple checked types', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('type-filter-text')));
    await tester.tap(find.byKey(const Key('type-filter-url')));
    await tester.pump();

    expect(
      tester
          .widget<CupertinoChoicePill>(
            find.byKey(const Key('type-filter-text')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<CupertinoChoicePill>(find.byKey(const Key('type-filter-url')))
          .selected,
      isTrue,
    );

    await tester.tap(find.text('Áp dụng bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-filter-button')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CupertinoChoicePill>(
            find.byKey(const Key('type-filter-text')),
          )
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<CupertinoChoicePill>(find.byKey(const Key('type-filter-url')))
          .selected,
      isTrue,
    );
  });

  testWidgets('delete action requires confirmation and removes item', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa mục này?'), findsOneWidget);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Xóa'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(await repository.getItems(), isEmpty);
    expect(find.text('Clipboard của bạn đang trống'), findsOneWidget);
  });

  testWidgets('quick panel renders a horizontal Paste-style card and copies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository.items.add(
      ClipboardItem(
        id: 'item-2',
        content: 'https://example.com/khong-khop',
        normalizedContent: 'https://example.com/khong-khop',
        contentHash: 'hash-2',
        contentType: ClipboardContentType.url,
        createdAt: DateTime(2026, 7, 27),
        updatedAt: DateTime(2026, 7, 27),
        lastCopiedAt: DateTime(2026, 7, 27),
        isPinned: false,
        isSensitive: false,
        copyCount: 1,
      ),
    );

    await tester.pumpWidget(app(quickPanel: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-panel-search')), findsOneWidget);
    expect(
      tester
          .widget<CupertinoChoicePill>(
            find.byKey(const Key('quick-section-all')),
          )
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('quick-type-text')), findsNothing);
    await tester.tap(find.byKey(const Key('quick-type-url')));
    await tester.tap(find.byKey(const Key('quick-type-image')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoChoicePill>(find.byKey(const Key('quick-type-url')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<CupertinoChoicePill>(
            find.byKey(const Key('quick-type-image')),
          )
          .selected,
      isTrue,
    );
    expect(find.byKey(const Key('quick-active-type-url')), findsNothing);
    expect(find.byKey(const Key('quick-active-type-image')), findsNothing);
    await tester.tap(find.byKey(const Key('quick-type-image')));
    await tester.pumpAndSettle();
    expect(find.text('Riêng tư & cục bộ'), findsNothing);
    expect(find.text('Liên kết'), findsAtLeast(1));
    await tester.enterText(
      find.byKey(const Key('quick-panel-search')),
      'flutter.dev',
    );
    await tester.pump();
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pump();
    await tester.tap(find.textContaining('flutter.dev').last);
    await tester.pumpAndSettle();
    expect(watcher.current?.text, 'https://flutter.dev');
    expect(find.byKey(const Key('quick-panel-search')), findsNothing);
    expect(find.byKey(const Key('history-search')), findsOneWidget);
    expect(find.text('https://example.com/khong-khop'), findsOneWidget);
  });

  test('copy keeps the visible item order until an explicit reload', () async {
    repository.items.add(
      ClipboardItem(
        id: 'item-2',
        content: 'Second item',
        normalizedContent: 'Second item',
        contentHash: 'hash-2',
        contentType: ClipboardContentType.text,
        createdAt: DateTime(2026, 7, 26),
        updatedAt: DateTime(2026, 7, 26),
        lastCopiedAt: DateTime(2026, 7, 26),
        isPinned: false,
        isSensitive: false,
        copyCount: 1,
      ),
    );
    final controller = ClipboardHistoryController(
      repository,
      watcher,
      () => const AppSettings(monitoringEnabled: false),
    );
    addTearDown(controller.dispose);
    await controller.reload();

    expect(controller.state.items.map((item) => item.id), ['item-1', 'item-2']);
    expect(controller.state.hasExplicitSelection, isFalse);
    controller.select(controller.state.items.first.id);
    expect(controller.state.hasExplicitSelection, isTrue);
    await controller.copy(controller.state.items[1]);

    expect(controller.state.items.map((item) => item.id), ['item-1', 'item-2']);
    expect(repository.items.map((item) => item.id), ['item-2', 'item-1']);
  });
}
