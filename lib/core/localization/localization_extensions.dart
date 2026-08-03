import 'package:flutter/widgets.dart';
import 'package:clipflow/l10n/app_localizations.dart';

extension LocalizationX on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(
        Localizations.maybeLocaleOf(this) ?? const Locale('vi'),
      );
}
