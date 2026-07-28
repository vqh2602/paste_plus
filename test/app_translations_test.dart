import 'package:clipflow/core/localization/app_translations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vietnamese and English expose the same translation keys', () {
    expect(
      AppTranslations.keys['vi']!.keys.toSet(),
      AppTranslations.keys['en']!.keys.toSet(),
    );
  });

  test('sidebar and settings labels never fall back to raw keys', () {
    const keys = [
      'library',
      'collections',
      'settings',
      'local_data_only',
      'settings_title',
      'tab_general',
      'tab_clipboard',
      'tab_privacy',
      'tab_storage',
      'tab_shortcuts',
      'tab_ai',
      'tab_about',
    ];

    for (final language in ['vi', 'en']) {
      AppTranslations.currentLanguage = language;
      for (final key in keys) {
        expect(key.tr, isNot(key), reason: '$language is missing "$key"');
      }
    }
  });
}
