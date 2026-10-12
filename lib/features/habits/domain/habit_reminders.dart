import 'day_key.dart';
import 'habit.dart';

typedef HabitReminder = ({Habit habit, DateTime at, String key});

/// Upcoming reminder times for all habits that have one: scheduled days only,
/// skipping days already completed and times already past. Soonest first,
/// limited to [limit] (the OS caps pending notifications), looking [days] ahead.
List<HabitReminder> upcomingHabitReminders(
  List<Habit> habits,
  DateTime now, {
  int days = 14,
  int limit = 24,
}) {
  final out = <HabitReminder>[];
  for (final h in habits) {
    final minutes = h.reminderAt;
    if (minutes == null) continue;
    for (var i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (!h.isScheduled(day) || h.doneOn(day)) continue;
      final at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
      if (!at.isAfter(now)) continue;
      out.add((habit: h, at: at, key: '${h.id}|${dayKey(day)}'));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out.take(limit).toList();
}
