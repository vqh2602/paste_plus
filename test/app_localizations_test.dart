import 'package:clipflow/l10n/app_localizations.dart';
import 'package:clipflow/features/settings/presentation/widgets/general_settings_section.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated localization supports every configured app locale', () {
    for (final locale in const [
      Locale('en'),
      Locale('vi'),
      Locale('ja'),
      Locale('ko'),
      Locale('de'),
      Locale('zh'),
    ]) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.settings, isNotEmpty);
      expect(l10n.delete, isNotEmpty);
      expect(l10n.aiTitle, isNotEmpty);
      expect(l10n.emoji, isNotEmpty);
      expect(l10n.jwt, isNotEmpty);
      expect(l10n.text_transform, isNotEmpty);
    }

    final chinese = lookupAppLocalizations(const Locale('zh'));
    expect(chinese.settings, '设置');
    expect(chinese.app_language, '应用程序语言');

    expect(
      supportedAppLanguageItems().keys.toSet(),
      AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toSet(),
    );
  });
}
