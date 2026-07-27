import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._repository) : super(_repository.load());

  final SettingsRepository _repository;

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    state = change(state);
    await _repository.save(state);
  }
}
