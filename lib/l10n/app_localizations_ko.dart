// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aiTitle => 'AI 어시스턴트';

  @override
  String get aiThinking => '생각하는 중…';

  @override
  String get aiModelNotReady => 'AI 모델이 준비되지 않았습니다.';
}
