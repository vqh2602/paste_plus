import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._preferences);

  static const _key = 'clipflow.settings.v1';
  final SharedPreferences _preferences;

  AppSettings load() {
    final source = _preferences.getString(_key);
    if (source == null) return const AppSettings();
    try {
      return AppSettings.fromJson(source);
    } on Object {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) {
    return _preferences.setString(_key, settings.toJson());
  }
}
