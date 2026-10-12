import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  static const _key = 'app_settings_v1';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
