import 'package:clipflow/features/settings/data/settings_repository.dart';
import 'package:clipflow/features/settings/domain/app_settings.dart';
import 'package:clipflow/core/platform/shortcut_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses Gemma 4 E2B when no AI model has been selected', () {
    expect(const AppSettings().selectedAiModel, AppSettings.defaultAiModel);
    expect(
      AppSettings.fromJson('{}').selectedAiModel,
      AppSettings.defaultAiModel,
    );
    expect(
      AppSettings.fromJson('{"selectedAiModel":""}').selectedAiModel,
      AppSettings.defaultAiModel,
    );
  });

  test('uses the configured ImgBB API key by default', () {
    expect(const AppSettings().imgBbApiKey, '670005d0dea70dbc4350f1ff1ad1dc33');
  });

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
      cloudImageHost: 'freeimage',
      freeImageApiKey: '6d207e02198a847aa98d0a2a901485a5',
      imgBbApiKey: 'custom-imgbb-key',
      allowedTypes: {'text', 'url'},
      excludedApplications: ['Password App'],
      openPanelShortcut: openShortcut,
      localSharingEnabled: true,
      deviceDisplayName: 'Work Mac',
      autoConnectTrustedDevices: false,
      syncPinnedItemsOnly: true,
      sharingMaxImageMb: 42,
      allConnectionsPaused: true,
      vaultEnabled: true,
      vaultWipeAfterFiveFailures: true,
    );

    await repository.save(changed);
    final loaded = repository.load();

    expect(loaded.monitoringEnabled, isFalse);
    expect(loaded.retentionDays, 90);
    expect(loaded.targetTranslationLanguage, 'ja');
    expect(loaded.cloudImageHost, 'freeimage');
    expect(loaded.freeImageApiKey, '6d207e02198a847aa98d0a2a901485a5');
    expect(loaded.imgBbApiKey, 'custom-imgbb-key');
    expect(loaded.allowedTypes, {'text', 'url'});
    expect(loaded.excludedApplications, ['Password App']);
    expect(loaded.localSharingEnabled, isTrue);
    expect(loaded.deviceDisplayName, 'Work Mac');
    expect(loaded.autoConnectTrustedDevices, isFalse);
    expect(loaded.syncPinnedItemsOnly, isTrue);
    expect(loaded.sharingMaxImageMb, 42);
    expect(loaded.allConnectionsPaused, isTrue);
    expect(loaded.vaultEnabled, isTrue);
    expect(loaded.vaultWipeAfterFiveFailures, isTrue);
    expect(
      shortcutSignature(
        decodeShortcut(loaded.openPanelShortcut, ShortcutAction.openPanel),
      ),
      shortcutSignature(defaultShortcut(ShortcutAction.openPanel)),
    );
  });
}
