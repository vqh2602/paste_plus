import 'package:clipflow/features/ai/domain/ai_agent_protocol.dart';
import 'package:clipflow/features/ai/presentation/widgets/ai_message_block_renderer.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/app/providers.dart';
import 'package:clipflow/core/services/clipboard_watcher.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_repository.dart';
import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ClipboardItem buildItem({
  required String id,
  required String content,
  ClipboardContentType type = ClipboardContentType.text,
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
    isPinned: false,
    isSensitive: false,
    copyCount: 1,
  );
}


/// Cards now watch live history, so the widget tree needs a repository and
/// watcher even for pure rendering assertions.
class _StubRepository implements ClipboardRepository {
  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async => const [];

  @override
  Future<List<ClipboardCollection>> getCollections() async => const [];

  @override
  Future<void> cleanup(AppSettings settings) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubWatcher implements ClipboardWatcher {
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
  Locale locale = const Locale('vi'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clipboardRepositoryProvider.overrideWithValue(_StubRepository()),
        clipboardWatcherProvider.overrideWithValue(_StubWatcher()),
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(preferences),
        ),
      ],
      child: CupertinoApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: AiMessageBlockRenderer(block: block),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('image results render a grid and never raw JSON', (tester) async {
    await pumpBlock(
      tester,
      AiClipboardGridBlock(
        resultSetId: 'set-1',
        items: [
          buildItem(id: 'a', content: '', type: ClipboardContentType.image),
          buildItem(id: 'b', content: '', type: ClipboardContentType.image),
        ],
      ),
    );

    expect(find.byType(AiClipboardImageGrid), findsOneWidget);
    expect(find.textContaining('{'), findsNothing);
    expect(find.textContaining('clip_id'), findsNothing);
    expect(find.textContaining('resultSetId'), findsNothing);
  });

  testWidgets('url results show the exact stored URL', (tester) async {
    await pumpBlock(
      tester,
      AiUrlListBlock(
        resultSetId: 'set-2',
        items: [
          buildItem(
            id: 'u1',
            content: 'https://github.com/flutter/flutter',
            type: ClipboardContentType.url,
          ),
        ],
        urlsByClipboardId: const {
          'u1': ['https://github.com/flutter/flutter'],
        },
      ),
    );

    expect(find.byType(AiClipboardUrlList), findsOneWidget);
    expect(
      find.textContaining('https://github.com/flutter/flutter'),
      findsWidgets,
    );
    expect(find.textContaining('"'), findsNothing);
  });

  testWidgets('localized title resolves per locale', (tester) async {
    const block = AiLocalizedTitleBlock(
      AiMessageTitle(kind: AiMessageTitleKind.imageResultCount, count: 18),
    );

    await pumpBlock(tester, block);
    expect(find.text('Tìm thấy 18 ảnh.'), findsOneWidget);

    await pumpBlock(tester, block, locale: const Locale('en'));
    expect(find.text('Found 18 images.'), findsOneWidget);

    await pumpBlock(tester, block, locale: const Locale('de'));
    expect(find.text('18 Bilder gefunden.'), findsOneWidget);
  });

  testWidgets('action receipt is localized and never shows a code',
      (tester) async {
    await pumpBlock(
      tester,
      const AiActionReceiptBlock(
        AiActionReceipt(
          code: 'clipboard.pin.success',
          affectedItemIds: ['a', 'b', 'c'],
          affectedCount: 3,
        ),
      ),
    );

    expect(find.text('Đã ghim 3 mục.'), findsOneWidget);
    expect(find.textContaining('clipboard.pin.success'), findsNothing);
  });

  testWidgets('error block shows a human message, not the raw code',
      (tester) async {
    await pumpBlock(
      tester,
      const AiErrorBlock(
        code: 'clipboard.reference.not_found',
        localizedMessageKey: 'clipboard.reference.not_found',
      ),
    );

    expect(find.textContaining('clipboard.reference.not_found'), findsNothing);
    expect(find.byType(AiErrorView), findsOneWidget);
  });
}

