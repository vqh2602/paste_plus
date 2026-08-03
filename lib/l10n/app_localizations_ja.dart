// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get aiTitle => 'AIアシスタント';

  @override
  String get aiThinking => '考えています…';

  @override
  String get aiModelNotReady => 'AIモデルの準備ができていません。';
}
