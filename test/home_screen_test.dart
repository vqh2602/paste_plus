import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clipflow/app/providers.dart';
import 'package:clipflow/core/services/clipboard_watcher.dart';
import 'package:clipflow/core/ui/cupertino_components.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_payload.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_repository.dart';
import 'package:clipflow/features/clipboard_history/domain/content_classifier.dart';
import 'package:clipflow/features/clipboard_history/presentation/home_screen.dart';
import 'package:clipflow/features/clipboard_history/presentation/history_controller.dart';
import 'package:clipflow/features/clipboard_history/presentation/widgets/sidebar_widget.dart';
import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

class InMemoryClipboardRepository
    implements ClipboardRepository, EditableClipboardRepository {
  Uint8List? lastEditedImageBytes;
  final collections = <ClipboardCollection>[];
  final collectionItems = <String, Set<String>>{};
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
  Future<void> addToCollection(String itemId, String collectionId) async {
    collectionItems.putIfAbsent(collectionId, () => {}).add(itemId);
  }

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
  Future<List<ClipboardCollection>> getCollections() async => collections;

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
              (type == null || item.contentType == type) &&
              (collectionId == null ||
                  (collectionItems[collectionId]?.contains(item.id) ?? false)),
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
  Future<ClipboardItem> updateItemContent(
    ClipboardItem item, {
    required String content,
    Uint8List? imageBytes,
  }) async {
    lastEditedImageBytes = imageBytes;
    final index = items.indexWhere((entry) => entry.id == item.id);
    final updated = item.copyWith(
      content: content.trim(),
      normalizedContent: content.trim(),
      contentType: imageBytes == null
          ? ContentClassifier.classify(content)
          : ClipboardContentType.image,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> updateNote(String id, String? note) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      items[index] = items[index].copyWith(note: note, clearNote: note == null);
    }
  }

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
    child: const CupertinoApp(
      locale: Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(),
    ),
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
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('clipboard menu is compact and opens a full preview', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('clipboard-action-menu'));
    expect(menu, findsOneWidget);
    expect(tester.getSize(menu).width, lessThanOrEqualTo(238));
    expect(tester.getSize(menu).height, lessThan(400));
    expect(find.text('Mở'), findsOneWidget);
    expect(find.text('Dán dưới dạng văn bản thuần'), findsOneWidget);
    expect(find.text('Xem trước'), findsOneWidget);
    expect(find.text('Chỉnh sửa'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('clipboard-action-preview')),
    );
    await tester.tap(find.byKey(const Key('clipboard-action-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clipboard-preview-dialog')), findsOneWidget);
    expect(find.text('19 ký tự'), findsOneWidget);
    expect(find.text('1 từ'), findsOneWidget);
    expect(find.text('1 dòng'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clipboard-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-preview-dialog')), findsNothing);
  });

  testWidgets('paste as plain text writes only text to the clipboard', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clipboard-action-paste_plain')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(watcher.current?.text, 'https://flutter.dev');
    expect(watcher.current?.imageBytes, isNull);
    expect(repository.items.single.copyCount, 2);
  });

  testWidgets('text conversion opens a compact submenu and copies result', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pumpAndSettle();
    expect(find.text('Chuyển đổi văn bản'), findsOneWidget);
    expect(find.text('Làm sạch liên kết'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clipboard-action-text_transform')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('text-transform-menu')), findsOneWidget);
    expect(find.text('Định dạng JSON'), findsOneWidget);
    expect(find.text('Mã hóa Base64'), findsOneWidget);
    expect(find.text('Băm MD5'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('text-transform-urlEncode')),
    );
    await tester.tap(find.byKey(const Key('text-transform-urlEncode')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(watcher.current?.text, 'https%3A%2F%2Fflutter.dev');
    expect(find.text('Đã sao chép kết quả chuyển đổi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Link Cleaner removes tracking parameters', (tester) async {
    repository.items[0] = repository.items[0].copyWith(
      content: 'https://flutter.dev/docs?utm_source=test&page=2&fbclid=x',
      normalizedContent:
          'https://flutter.dev/docs?utm_source=test&page=2&fbclid=x',
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clipboard-action-link_cleaner')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(watcher.current?.text, 'https://flutter.dev/docs?page=2');
    expect(find.text('Đã sao chép liên kết sạch'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('valid math expression shows its instant result', (tester) async {
    repository.items[0] = repository.items[0].copyWith(
      content: '2 + 3 * (4 - 1)',
      normalizedContent: '2 + 3 * (4 - 1)',
      contentType: ClipboardContentType.text,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Kết quả: 11'), findsWidgets);
  });

  testWidgets('clipboard edit updates the existing item', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clipboard-action-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('clipboard-edit-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('clipboard-edit-field')),
      'hello edited clipboard',
    );
    await tester.tap(find.byKey(const Key('clipboard-edit-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.items, hasLength(1));
    expect(repository.items.single.id, 'item-1');
    expect(repository.items.single.content, 'hello edited clipboard');
    expect(repository.items.single.contentType, ClipboardContentType.text);
    expect(find.text('Đã cập nhật clipboard'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('image edit rotates and saves the transformed image', (
    tester,
  ) async {
    final source = img.Image(width: 3, height: 2);
    final imageFile = File(
      '${Directory.systemTemp.path}/clipflow-edit-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    imageFile.writeAsBytesSync(img.encodePng(source));
    addTearDown(() {
      if (imageFile.existsSync()) {
        imageFile.deleteSync();
      }
    });
    repository.items
      ..clear()
      ..add(
        ClipboardItem(
          id: 'editable-image',
          content: '',
          normalizedContent: '',
          contentHash: 'editable-image-hash',
          contentType: ClipboardContentType.image,
          createdAt: DateTime(2026, 8, 25),
          updatedAt: DateTime(2026, 8, 25),
          lastCopiedAt: DateTime(2026, 8, 25),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
          imagePath: imageFile.path,
        ),
      );

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Chia sẻ'), findsOneWidget);
    expect(find.text('Dán dưới dạng văn bản thuần'), findsNothing);
    expect(find.text('Mở'), findsNothing);
    await tester.tap(find.byKey(const Key('clipboard-action-edit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final footer = find.byKey(const Key('clipboard-edit-footer'));
    expect(footer, findsOneWidget);
    expect(tester.widget<Text>(footer).data, '3 × 2 px');
    await tester.tap(find.byKey(const Key('clipboard-edit-rotate-right')));
    await tester.pump();
    expect(find.text('2 × 3 px'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clipboard-edit-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final saved = img.decodeImage(repository.lastEditedImageBytes!);
    expect(saved, isNotNull);
    expect(saved!.width, 2);
    expect(saved.height, 3);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('image preview shows its actual pixel dimensions', (
    tester,
  ) async {
    final imageFile = File(
      '${Directory.current.path}/assets/branding/clipflow_app_icon.png',
    );
    expect(imageFile.existsSync(), isTrue);
    repository.items
      ..clear()
      ..add(
        ClipboardItem(
          id: 'image-item',
          content: '',
          normalizedContent: '',
          contentHash: 'image-hash',
          contentType: ClipboardContentType.image,
          createdAt: DateTime(2026, 8, 25),
          updatedAt: DateTime(2026, 8, 25),
          lastCopiedAt: DateTime(2026, 8, 25),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
          imagePath: imageFile.path,
        ),
      );

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('item-more-button')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('clipboard-action-preview')));
    await tester.pump(const Duration(milliseconds: 200));

    final dimensions = find.byKey(
      const Key('clipboard-preview-image-dimensions'),
    );
    expect(dimensions, findsOneWidget);
    expect(tester.widget<Text>(dimensions).data, '1254 × 1254 px');
  });

  testWidgets('collection options use the compact anchored menu', (
    tester,
  ) async {
    repository.collections.add(
      ClipboardCollection(
        id: 'work',
        name: 'Work',
        icon: 'folder',
        createdAt: DateTime(2026, 8, 25),
        updatedAt: DateTime(2026, 8, 25),
        sortOrder: 0,
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final collectionTile = find.widgetWithText(SidebarTileWidget, 'Work');
    final optionsButton = find.descendant(
      of: collectionTile,
      matching: find.byIcon(CupertinoIcons.ellipsis),
    );
    await tester.tap(optionsButton);
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('collection-action-menu'));
    expect(menu, findsOneWidget);
    expect(tester.getSize(menu).width, lessThanOrEqualTo(238));
    expect(tester.getSize(menu).height, lessThan(120));
    expect(find.text('Đổi tên'), findsOneWidget);
    expect(find.text('Xóa collection'), findsOneWidget);
  });

  testWidgets('dragging a clipboard item onto a collection adds it', (
    tester,
  ) async {
    final collection = ClipboardCollection(
      id: 'work',
      name: 'Work',
      icon: 'folder',
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
      sortOrder: 0,
    );
    repository.collections.add(collection);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final item = find.byKey(const Key('clipboard-item'));
    final target = find.byKey(const Key('collection-drop-target-work'));
    final start = tester.getCenter(item);
    final end = tester.getCenter(target);
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await tester.pump();

    expect(
      tester
          .widget<SidebarTileWidget>(
            find.widgetWithText(SidebarTileWidget, 'Work'),
          )
          .highlighted,
      isTrue,
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.collectionItems['work'], contains('item-1'));
    expect(find.text('Đã thêm vào collection "Work"'), findsOneWidget);
    expect(
      tester
          .widget<SidebarTileWidget>(
            find.widgetWithText(SidebarTileWidget, 'Work'),
          )
          .highlighted,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('quick panel item options use the compact menu', (tester) async {
    tester.view.physicalSize = const Size(1400, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(quickPanel: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick-item-more-button')));
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('clipboard-action-menu'));
    expect(menu, findsOneWidget);
    expect(tester.getSize(menu).width, lessThanOrEqualTo(238));
    expect(find.text('Sao chép & Dán'), findsOneWidget);
    expect(find.text('Mở'), findsOneWidget);
    expect(find.text('Dán dưới dạng văn bản thuần'), findsOneWidget);
    expect(find.text('Chỉnh sửa'), findsOneWidget);
    expect(find.text('Xem trước'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);
  });

  testWidgets('quick cards show metadata after their source app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final imagePath =
        '${Directory.current.path}/assets/branding/clipflow_app_icon.png';
    repository.items
      ..clear()
      ..addAll([
        ClipboardItem(
          id: 'text-item',
          content: 'hello',
          normalizedContent: 'hello',
          contentHash: 'text-hash',
          contentType: ClipboardContentType.text,
          createdAt: DateTime(2026, 8, 25),
          updatedAt: DateTime(2026, 8, 25),
          lastCopiedAt: DateTime(2026, 8, 25),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
          sourceAppName: 'ChatGPT',
        ),
        ClipboardItem(
          id: 'image-item',
          content: '',
          normalizedContent: '',
          contentHash: 'image-hash',
          contentType: ClipboardContentType.image,
          createdAt: DateTime(2026, 8, 25),
          updatedAt: DateTime(2026, 8, 25),
          lastCopiedAt: DateTime(2026, 8, 25),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
          sourceAppName: 'Finder',
          imagePath: imagePath,
        ),
        ClipboardItem(
          id: 'color-item',
          content: 'rgba(255, 0, 128, 0.5)',
          normalizedContent: 'rgba(255, 0, 128, 0.5)',
          contentHash: 'color-hash',
          contentType: ClipboardContentType.color,
          createdAt: DateTime(2026, 8, 25),
          updatedAt: DateTime(2026, 8, 25),
          lastCopiedAt: DateTime(2026, 8, 25),
          isPinned: false,
          isSensitive: false,
          copyCount: 1,
          sourceAppName: 'Design Tool',
        ),
      ]);

    await tester.pumpWidget(app(quickPanel: true));
    await tester.pumpAndSettle();

    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Finder'), findsOneWidget);
    expect(find.text('Design Tool'), findsOneWidget);
    expect(find.text('5 ký tự'), findsOneWidget);

    final dimensions = find.byKey(
      const Key('quick-card-image-metadata-image-item'),
    );
    expect(dimensions, findsOneWidget);
    expect(tester.widget<Text>(dimensions).data, '1254 × 1254 px');

    final colorFormat = find.byKey(
      const Key('quick-card-color-metadata-color-item'),
    );
    expect(colorFormat, findsOneWidget);
    expect(tester.widget<Text>(colorFormat).data, 'RGBA');
  });

  testWidgets('main detail shows the same clipboard metadata', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ClipboardItem item({
      required String id,
      required String content,
      required ClipboardContentType type,
      String? imagePath,
    }) => ClipboardItem(
      id: id,
      content: content,
      normalizedContent: content,
      contentHash: '$id-hash',
      contentType: type,
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
      lastCopiedAt: DateTime(2026, 8, 25),
      isPinned: false,
      isSensitive: false,
      copyCount: 1,
      sourceAppName: 'ChatGPT',
      imagePath: imagePath,
    );

    Future<void> show(ClipboardItem clipboardItem) async {
      await tester.pumpWidget(const SizedBox());
      repository.items
        ..clear()
        ..add(clipboardItem);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
    }

    await show(
      item(id: 'main-text', content: 'hello', type: ClipboardContentType.text),
    );
    expect(find.text('Chi tiết'), findsOneWidget);
    expect(find.text('5 ký tự'), findsOneWidget);

    await show(
      item(
        id: 'main-image',
        content: '',
        type: ClipboardContentType.image,
        imagePath:
            '${Directory.current.path}/assets/branding/clipflow_app_icon.png',
      ),
    );
    final dimensions = find.byKey(const Key('detail-pane-image-metadata'));
    expect(dimensions, findsOneWidget);
    expect(tester.widget<Text>(dimensions).data, '1254 × 1254 px');

    await show(
      item(
        id: 'main-color',
        content: '#ff0080',
        type: ClipboardContentType.color,
      ),
    );
    final colorFormat = find.byKey(const Key('detail-pane-color-metadata'));
    expect(colorFormat, findsOneWidget);
    expect(tester.widget<Text>(colorFormat).data, 'HEX');
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
    await tester.ensureVisible(
      find.byKey(const Key('clipboard-action-delete')),
    );
    await tester.tap(find.byKey(const Key('clipboard-action-delete')));
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

  testWidgets(
    'mobile sidebar is inset and closes after tab or collection selection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.collections.add(
        ClipboardCollection(
          id: 'mobile-collection',
          name: 'Mobile collection',
          icon: 'folder',
          createdAt: DateTime(2026, 7, 31),
          updatedAt: DateTime(2026, 7, 31),
          sortOrder: 10,
        ),
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-sidebar-button')));
      await tester.pumpAndSettle();

      final sheet = tester.getSize(
        find.byKey(const Key('mobile-sidebar-sheet')),
      );
      expect(sheet.width, lessThan(390));

      await tester.tap(find.text('Liên kết'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile-sidebar-sheet')), findsNothing);

      await tester.tap(find.byKey(const Key('mobile-sidebar-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SidebarTileWidget>(
              find.widgetWithText(SidebarTileWidget, 'Liên kết'),
            )
            .selected,
        isTrue,
      );

      await tester.tap(find.text('Mobile collection'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mobile-sidebar-sheet')), findsNothing);

      await tester.tap(find.byKey(const Key('mobile-sidebar-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SidebarTileWidget>(
              find.widgetWithText(SidebarTileWidget, 'Mobile collection'),
            )
            .selected,
        isTrue,
      );
    },
  );

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
