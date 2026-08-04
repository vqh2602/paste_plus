import 'package:clipflow/app/app.dart';
import 'package:clipflow/app/providers.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_content_type.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_item.dart';
import 'package:clipflow/features/clipboard_history/domain/clipboard_repository.dart';
import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClipboardRepository extends Fake implements ClipboardRepository {
  @override
  Future<List<ClipboardItem>> getItems({
    bool pinnedOnly = false,
    ClipboardContentType? type,
    String? collectionId,
    int limit = 2000,
  }) async => [];

  @override
  Future<List<ClipboardCollection>> getCollections() async => [];
}

void main() {
  testWidgets('ClipFlowApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsRepo = SettingsRepository(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          clipboardRepositoryProvider.overrideWithValue(
            _FakeClipboardRepository(),
          ),
        ],
        child: const ClipFlowApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(ClipFlowApp), findsOneWidget);
  });
}
