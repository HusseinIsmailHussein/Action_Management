import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local_habit_trash_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_trash_repository.dart';
import '../domain/trashed_habit.dart';

final habitTrashRepositoryProvider =
    Provider<HabitTrashRepository>((ref) => LocalHabitTrashRepository());

/// Deleted habits, newest first. Entries older than 30 days are dropped on load.
/// Restoring goes through HabitController.restore, which also leaves the trash.
class HabitTrashController extends AsyncNotifier<List<TrashedHabit>> {
  HabitTrashRepository get _repo => ref.read(habitTrashRepositoryProvider);

  @override
  Future<List<TrashedHabit>> build() async {
    final all = await _repo.load();
    final kept = habitsWithoutExpired(all, DateTime.now());
    if (kept.length != all.length) await _repo.save(kept);
    return kept;
  }

  Future<void> _set(List<TrashedHabit> next) async {
    state = AsyncData(next);
    await _repo.save(next);
  }

  Future<void> add(Habit habit) async {
    final current = await future; // wait for the stored list to load first
    await _set([
      TrashedHabit(habit: habit, deletedAt: DateTime.now()),
      ...current.where((t) => t.habit.id != habit.id),
    ]);
  }

  Future<void> discard(String habitId) async {
    final current = await future;
    await _set(current.where((t) => t.habit.id != habitId).toList());
  }

  Future<void> empty() => _set(<TrashedHabit>[]);
}

final habitTrashProvider =
    AsyncNotifierProvider<HabitTrashController, List<TrashedHabit>>(
        HabitTrashController.new);
