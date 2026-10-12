import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/date_utils.dart';
import '../data/local_focus_repository.dart';
import '../domain/focus_repository.dart';
import '../domain/focus_session.dart';
import '../domain/pomodoro.dart';

final focusRepositoryProvider =
    Provider<FocusRepository>((ref) => LocalFocusRepository());

class FocusSettingsController extends AsyncNotifier<FocusSettings> {
  FocusRepository get _repo => ref.read(focusRepositoryProvider);

  @override
  Future<FocusSettings> build() => _repo.loadSettings();

  Future<void> save(FocusSettings s) async {
    state = AsyncData(s);
    await _repo.saveSettings(s);
  }
}

final focusSettingsProvider =
    AsyncNotifierProvider<FocusSettingsController, FocusSettings>(
        FocusSettingsController.new);

class FocusSessionsController extends AsyncNotifier<List<FocusSession>> {
  FocusRepository get _repo => ref.read(focusRepositoryProvider);

  @override
  Future<List<FocusSession>> build() => _repo.loadSessions();

  /// Newest first; keeps the last 1000.
  Future<void> add(FocusSession s) async {
    final next = <FocusSession>[s, ...(state.value ?? <FocusSession>[])].take(1000).toList();
    state = AsyncData(next);
    await _repo.saveSessions(next);
  }
}

final focusSessionsProvider =
    AsyncNotifierProvider<FocusSessionsController, List<FocusSession>>(
        FocusSessionsController.new);

/// (seconds focused today, number of sessions today)
final focusTodayProvider = Provider<(int, int)>((ref) {
  final sessions = ref.watch(focusSessionsProvider).value ?? [];
  final now = DateTime.now();
  final today = sessions.where((s) => isSameDay(s.startedAt, now)).toList();
  return (today.fold<int>(0, (sum, s) => sum + s.seconds), today.length);
});

/// Focused seconds for each of the last 7 days, oldest first.
final focusWeekProvider = Provider<List<(DateTime, int)>>((ref) {
  final sessions = ref.watch(focusSessionsProvider).value ?? [];
  final now = DateTime.now();
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final day = DateTime(now.year, now.month, now.day - i);
        final secs = sessions
            .where((s) => isSameDay(s.startedAt, day))
            .fold<int>(0, (sum, s) => sum + s.seconds);
        return (day, secs);
      }()
  ];
});
