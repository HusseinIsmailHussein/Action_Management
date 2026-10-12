import '../../habits/domain/habit.dart';
import '../../tasks/domain/task.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _finishedOn(TaskItem t, DateTime day) =>
    t.done && t.completedAt != null && _sameDay(t.completedAt!, day);

/// What was finished on one day.
class ActivityDay {
  final DateTime day;
  final List<TaskItem> tasks; // most recently finished first
  final List<Habit> habits; // habits whose daily goal was met
  const ActivityDay({required this.day, required this.tasks, required this.habits});
}

/// Days within the last [days] days (newest first) on which a task was
/// finished or a habit goal was met. Days with nothing are left out.
List<ActivityDay> buildActivity(
  List<TaskItem> tasks,
  List<Habit> habits,
  DateTime now, {
  required int days,
}) {
  final today = _day(now);
  final out = <ActivityDay>[];
  for (var i = 0; i < days; i++) {
    final day = DateTime(today.year, today.month, today.day - i);
    final done = tasks.where((t) => _finishedOn(t, day)).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final met = habits.where((h) => h.doneOn(day)).toList();
    if (done.isNotEmpty || met.isNotEmpty) {
      out.add(ActivityDay(day: day, tasks: done, habits: met));
    }
  }
  return out;
}

/// Tasks completed on each of the last [days] days, oldest first.
/// "Won't do" tasks don't count as completed.
List<(DateTime, int)> completedPerDay(
  List<TaskItem> tasks,
  DateTime now, {
  required int days,
}) {
  final today = _day(now);
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final day = DateTime(today.year, today.month, today.day - i);
        return (day, tasks.where((t) => !t.wontDo && _finishedOn(t, day)).length);
      }()
  ];
}

/// Tasks completed from [from] to [to] (dates, inclusive). Won't-do tasks excluded.
int completedBetween(List<TaskItem> tasks, DateTime from, DateTime to) {
  final start = _day(from), end = _day(to);
  return tasks.where((t) {
    if (!t.done || t.wontDo || t.completedAt == null) return false;
    final d = _day(t.completedAt!);
    return !d.isBefore(start) && !d.isAfter(end);
  }).length;
}
