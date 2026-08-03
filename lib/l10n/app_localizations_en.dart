// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aiTitle => 'AI Assistant';

  @override
  String get aiThinking => 'Thinking…';

  @override
  String get aiModelNotReady => 'The AI model is not ready.';
}
