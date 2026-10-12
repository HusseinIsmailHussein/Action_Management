import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/notification_batch.dart';
import '../data/local_habit_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_reminders.dart';
import '../domain/habit_repository.dart';
import 'habit_trash_controller.dart';

final habitRepositoryProvider =
    Provider<HabitRepository>((ref) => LocalHabitRepository());

class HabitController extends AsyncNotifier<List<Habit>> {
  HabitRepository get _repo => ref.read(habitRepositoryProvider);
  List<Habit> get _current => state.value ?? [];

  @override
  Future<List<Habit>> build() async {
    final habits = await _repo.load();
    _syncReminders(habits);
    return habits;
  }

  /// Reminders are one-off notifications for the next couple of weeks, so they
  /// are re-planned on every change and whenever the app comes to the foreground.
  void _syncReminders(List<Habit> habits) {
    final notes = [
      for (final r in upcomingHabitReminders(habits, DateTime.now()))
        ScheduledNote(
          key: r.key,
          at: r.at,
          title: r.habit.name,
          body: r.habit.target > 1
              ? 'Goal today: ${r.habit.target} times'
              : 'Time to check in and keep your streak going.',
          payload: 'habit:${r.habit.id}',
        ),
    ];
    ref.read(notificationBatchProvider).replaceGroup('habits', notes).catchError((_) {});
  }

  /// Re-plan after the app returns to the foreground (no-op until loaded).
  void resyncReminders() {
    if (state.hasValue) _syncReminders(_current);
  }

  Future<void> _commit(List<Habit> next) async {
    state = AsyncData(next);
    await _repo.save(next);
    _syncReminders(next);
  }

  Future<void> add({
    required String name,
    required int iconIndex,
    required int color,
    required Set<int> weekdays,
    required int target,
    int? reminderAt,
  }) =>
      _commit([
        ..._current,
        Habit(
          id: const Uuid().v4(),
          name: name.trim(),
          iconIndex: iconIndex,
          color: color,
          weekdays: weekdays,
          target: target,
          reminderAt: reminderAt,
          createdAt: DateTime.now(),
        ),
      ]);

  Future<void> addAll(Iterable<Habit> items) {
    final existing = _current.map((h) => h.id).toSet();
    return _commit([..._current, ...items.where((h) => !existing.contains(h.id))]);
  }

  Future<void> removeWhere(bool Function(Habit) test) =>
      _commit(_current.where((h) => !test(h)).toList());

  /// Single entry point for changing any field of a habit.
  Future<void> edit(String id, Habit Function(Habit) change) =>
      _commit([for (final h in _current) h.id == id ? change(h) : h]);

  /// Deletes a habit, keeping a copy (with its history) in the trash for 30 days.
  Future<void> remove(String id) async {
    final matches = _current.where((h) => h.id == id);
    final habit = matches.isEmpty ? null : matches.first;
    // Update the list right away; the trash copy follows.
    final commit = _commit(_current.where((h) => h.id != id).toList());
    if (habit != null) await ref.read(habitTrashProvider.notifier).add(habit);
    await commit;
  }

  /// Puts a deleted habit back (used by "Undo" and the trash screen).
  Future<void> restore(Habit habit) async {
    final commit = _commit([..._current.where((h) => h.id != habit.id), habit]);
    await ref.read(habitTrashProvider.notifier).discard(habit.id);
    await commit;
  }

  /// The check button: toggles a once-a-day habit, otherwise counts up and
  /// wraps back to zero after the goal is reached (a quick undo).
  Future<void> tap(String id, DateTime day) => edit(id, (h) {
        final c = h.countOn(day);
        if (h.target == 1) return h.withCount(day, c >= 1 ? 0 : 1);
        return h.withCount(day, c >= h.target ? 0 : c + 1);
      });

  /// Mark a whole day done, or clear it (used to back-fill past days).
  Future<void> toggleDay(String id, DateTime day) =>
      edit(id, (h) => h.withCount(day, h.doneOn(day) ? 0 : h.target));

  Future<void> clearDay(String id, DateTime day) =>
      edit(id, (h) => h.withCount(day, 0));
}

final habitControllerProvider =
    AsyncNotifierProvider<HabitController, List<Habit>>(HabitController.new);

final habitByIdProvider = Provider.family<Habit?, String>((ref, id) {
  final habits = ref.watch(habitControllerProvider).value ?? [];
  for (final h in habits) {
    if (h.id == id) return h;
  }
  return null;
});

/// Habits scheduled today vs. the rest.
final habitGroupsProvider =
    Provider<({List<Habit> today, List<Habit> other})>((ref) {
  final habits = ref.watch(habitControllerProvider).value ?? [];
  final now = DateTime.now();
  return (
    today: habits.where((h) => h.isScheduled(now)).toList(),
    other: habits.where((h) => !h.isScheduled(now)).toList(),
  );
});

/// (completed, scheduled) habits for today.
final habitProgressProvider = Provider<(int, int)>((ref) {
  final today = ref.watch(habitGroupsProvider).today;
  final now = DateTime.now();
  return (today.where((h) => h.doneOn(now)).length, today.length);
});
