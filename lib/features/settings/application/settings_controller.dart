import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_settings_repository.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => LocalSettingsRepository());

/// Holds the current settings. main.dart loads them before the first frame and
/// passes them in, so the app never flashes the wrong theme on startup.
class AppSettingsController extends Notifier<AppSettings> {
  AppSettingsController([this._initial = const AppSettings()]);
  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  Future<void> setThemeMode(AppThemeMode mode) => _set(state.copyWith(themeMode: mode));

  Future<void> setAccent(int argb) => _set(state.copyWith(accent: argb));

  Future<void> _set(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);
