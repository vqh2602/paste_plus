import 'package:flutter/widgets.dart';
import 'package:clipflow/l10n/app_localizations.dart';

extension LocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
