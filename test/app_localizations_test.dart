import 'package:clipflow/l10n/app_localizations.dart';
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
    ]) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.settings, isNotEmpty);
      expect(l10n.delete, isNotEmpty);
      expect(l10n.aiTitle, isNotEmpty);
    }
  });
}
