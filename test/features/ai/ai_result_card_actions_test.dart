import 'package:clipflow/app/providers.dart';
import 'package:clipflow/features/ai/domain/ai_agent_protocol.dart';
import 'package:clipflow/features/ai/presentation/widgets/ai_message_block_renderer.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/core/services/clipboard_watcher.dart';
import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:clipflow/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem buildItem({
  required String id,
  String content = 'https://example.com/a',
  ClipboardContentType type = ClipboardContentType.url,
  bool pinned = false,
}) {
  final now = DateTime(2026, 8, 5);
  return ClipboardItem(
    id: id,
    content: content,
    normalizedContent: content.toLowerCase(),
    contentHash: 'hash-$id',
    contentType: type,
    createdAt: now,
    updatedAt: now,
    lastCopiedAt: now,
    isPinned: pinned,
    isSensitive: false,
    copyCount: 1,
    containsUrl: true,
  );
}

/// Minimal repository so tapping an action exercises the real callback path
/// without needing a database or platform channels.
class RecordingRepository implements ClipboardRepository {
  final List<String> calls = [];
  List<ClipboardItem> items = const [];

  @override
  Future<void> setPinned(String id, bool pinned) async {
    calls.add('setPinned');
  }

  @override
  Future<void> deleteItem(String id) async {
    calls.add('deleteItem');
  }

  @override
  Future<void> markCopied(String id) async {
    calls.add('markCopied');
  }

  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async => items;

  @override
  Future<List<ClipboardCollection>> getCollections() async => const [];

  @override
  Future<ClipboardItem?> store(
    ClipboardPayload payload,
    AppSettings settings,
  ) async => null;

  @override
  Future<void> cleanup(AppSettings settings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// No-op watcher so the history controller can be constructed in tests.
class FakeWatcher implements ClipboardWatcher {
  @override
  Stream<ClipboardPayload> watch() => const Stream.empty();

  @override
  Future<ClipboardPayload?> readCurrent() async => null;

  @override
  Future<void> write(ClipboardPayload payload) async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

Future<void> pumpBlock(
  WidgetTester tester,
  AiMessageBlock block, {
  Size surface = const Size(420, 700),
  RecordingRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clipboardRepositoryProvider.overrideWithValue(
          repository ?? RecordingRepository(),
        ),
        clipboardWatcherProvider.overrideWithValue(FakeWatcher()),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(preferences),
        ),
      ],
      child: CupertinoApp(
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: AiMessageBlockRenderer(block: block),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('long result lists scroll inside a bounded viewport', (
    tester,
  ) async {
    final items = [for (var i = 0; i < 30; i++) buildItem(id: 'item-$i')];
    await pumpBlock(
      tester,
      AiClipboardListBlock(resultSetId: 'set-1', items: items),
    );

    expect(find.byType(AiResultViewport), findsOneWidget);

    // The block must stay compact instead of pinning 30 cards into the chat.
    final height = tester.getSize(find.byType(AiResultViewport)).height;
    expect(height, lessThanOrEqualTo(320));

    final scrollable = find.descendant(
      of: find.byType(AiResultViewport),
      matching: find.byType(Scrollable),
    );
    expect(scrollable, findsWidgets);

    final before = tester.getTopLeft(find.byType(AiResultViewport));
    await tester.drag(scrollable.first, const Offset(0, -200));
    await tester.pump();
    // Scrolling inside the viewport must not move the block itself.
    expect(tester.getTopLeft(find.byType(AiResultViewport)), before);
  });

  testWidgets('action icons are laid out and hit-testable, not clipped', (
    tester,
  ) async {
    await pumpBlock(
      tester,
      AiClipboardListBlock(
        resultSetId: 'set-2',
        items: [buildItem(id: 'only')],
      ),
    );

    for (final icon in [
      CupertinoIcons.doc_on_doc,
      CupertinoIcons.arrow_right_square,
      CupertinoIcons.pin,
      CupertinoIcons.folder_badge_plus,
      CupertinoIcons.delete,
    ]) {
      final finder = find.byIcon(icon);
      expect(finder, findsOneWidget, reason: 'missing icon $icon');

      final size = tester.getSize(finder);
      expect(size.width, greaterThan(0), reason: '$icon collapsed');
      expect(size.height, greaterThan(0), reason: '$icon collapsed');

      // Guard the layout that broke the buttons: the icon must sit fully
      // inside its own scrollable action row, not spill outside the card.
      final row = find.ancestor(
        of: finder,
        matching: find.byType(SingleChildScrollView),
      );
      expect(row, findsWidgets, reason: '\$icon has no scrollable row');
      final iconRect = tester.getRect(finder);
      final rowRect = tester.getRect(row.first);
      expect(
        rowRect.top <= iconRect.top + 0.5 &&
            rowRect.bottom >= iconRect.bottom - 0.5,
        isTrue,
        reason: '\$icon is vertically clipped: icon=\$iconRect row=\$rowRect',
      );
    }
  });

  testWidgets('image grid cells reserve room for the action row', (
    tester,
  ) async {
    await pumpBlock(
      tester,
      AiClipboardGridBlock(
        resultSetId: 'set-3',
        items: [
          for (var i = 0; i < 6; i++)
            buildItem(
              id: 'img-$i',
              content: '',
              type: ClipboardContentType.image,
            ),
        ],
      ),
    );

    expect(find.byType(AiClipboardImageGrid), findsOneWidget);
    expect(find.byType(AiResultViewport), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Every card must still expose a tappable delete action.
    expect(find.byIcon(CupertinoIcons.delete), findsNWidgets(6));
  });

  testWidgets('narrow cards keep all actions reachable', (tester) async {
    await pumpBlock(
      tester,
      AiClipboardListBlock(
        resultSetId: 'set-4',
        items: [buildItem(id: 'narrow')],
      ),
      surface: const Size(240, 600),
    );

    expect(tester.takeException(), isNull);
    expect(find.byIcon(CupertinoIcons.delete), findsOneWidget);
  });

  testWidgets(
    'card reflects live pinned state instead of the stale agent snapshot',
    (tester) async {
      final stale = buildItem(id: 'live');
      final repository = RecordingRepository();
      await pumpBlock(
        tester,
        AiClipboardListBlock(resultSetId: 'set-5', items: [stale]),
        repository: repository,
      );

      // Snapshot says unpinned.
      expect(find.byIcon(CupertinoIcons.pin), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.pin_fill), findsNothing);

      // History reports the item as pinned; the card must follow, otherwise the
      // pin button looks like it did nothing.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AiMessageBlockRenderer)),
      );
      repository.items = [stale.copyWith(isPinned: true)];
      await container.read(historyControllerProvider.notifier).reload();
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.pin_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.pin), findsNothing);
    },
  );

  testWidgets(
    'deleting an item removes it from the result list and shows notice',
    (tester) async {
      final item1 = buildItem(id: 'item-to-delete', content: 'Item 1');
      final item2 = buildItem(id: 'item-to-keep', content: 'Item 2');
      final repository = RecordingRepository();
      repository.items = [item1, item2];

      await pumpBlock(
        tester,
        AiClipboardListBlock(resultSetId: 'set-del', items: [item1, item2]),
        repository: repository,
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      // Tap delete on item 1
      await tester.tap(find.byIcon(CupertinoIcons.delete).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Item 1 should be removed from the UI list
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 2'), findsOneWidget);

      // Notice should be shown
      expect(find.text('Đã xóa mục'), findsOneWidget);

      // Flush remaining toast timer (1.8s)
      await tester.pump(const Duration(seconds: 2));
    },
  );
}

