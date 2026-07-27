import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/core/platform/shortcut_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('settings serialize and persist with collections intact', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = SettingsRepository(preferences);
    final openShortcut = encodeShortcut(
      defaultShortcut(ShortcutAction.openPanel),
    );
    final changed = const AppSettings().copyWith(
      monitoringEnabled: false,
      retentionDays: 90,
      targetTranslationLanguage: 'ja',
      allowedTypes: {'text', 'url'},
      excludedApplications: ['Password App'],
      openPanelShortcut: openShortcut,
    );

    await repository.save(changed);
    final loaded = repository.load();

    expect(loaded.monitoringEnabled, isFalse);
    expect(loaded.retentionDays, 90);
    expect(loaded.targetTranslationLanguage, 'ja');
    expect(loaded.allowedTypes, {'text', 'url'});
    expect(loaded.excludedApplications, ['Password App']);
    expect(
      shortcutSignature(
        decodeShortcut(loaded.openPanelShortcut, ShortcutAction.openPanel),
      ),
      shortcutSignature(defaultShortcut(ShortcutAction.openPanel)),
    );
  });
}
