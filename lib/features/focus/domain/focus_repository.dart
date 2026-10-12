import 'focus_session.dart';
import 'pomodoro.dart';

abstract class FocusRepository {
  Future<List<FocusSession>> loadSessions();
  Future<void> saveSessions(List<FocusSession> sessions);
  Future<FocusSettings> loadSettings();
  Future<void> saveSettings(FocusSettings settings);
}
