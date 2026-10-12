import 'trashed_habit.dart';

abstract class HabitTrashRepository {
  Future<List<TrashedHabit>> load();
  Future<void> save(List<TrashedHabit> items);
}
