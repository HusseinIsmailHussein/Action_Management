import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/focus_repository.dart';
import '../domain/focus_session.dart';
import '../domain/pomodoro.dart';

class LocalFocusRepository implements FocusRepository {
  static const _sessionsKey = 'focus_sessions_v1';
  static const _settingsKey = 'focus_settings_v1';

  @override
  Future<List<FocusSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => FocusSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveSessions(List<FocusSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _sessionsKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  @override
  Future<FocusSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return const FocusSettings();
    return FocusSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveSettings(FocusSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }
}
