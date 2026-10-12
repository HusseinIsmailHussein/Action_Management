import 'habit.dart';

abstract class HabitRepository {
  Future<List<Habit>> load();
  Future<void> save(List<Habit> habits);
}
