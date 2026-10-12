import 'task.dart';

/// Hour (local time) at which reminders for all-day items fire.
const kAllDayReminderHour = 9;

/// Offered "minutes before" options. All-day items only get a subset.
List<int> reminderPresetsFor(bool hasTime) =>
    hasTime ? const [0, 5, 15, 30, 60, 1440] : const [0, 1440];

DateTime reminderFireTime({
  required DateTime due,
  required bool hasTime,
  required int minutes,
}) {
  final base = hasTime
      ? due
      : DateTime(due.year, due.month, due.day, kAllDayReminderHour);
  return base.subtract(Duration(minutes: minutes));
}

/// Every time a reminder should fire for [t] itself.
List<DateTime> reminderTimes(TaskItem t) {
  final due = t.due;
  if (due == null) return const [];
  return [
    for (final m in t.reminders)
      reminderFireTime(due: due, hasTime: t.hasTime, minutes: m)
  ];
}

List<DateTime> subtaskReminderTimes(Subtask s) {
  final due = s.due;
  if (due == null) return const [];
  return [
    for (final m in s.reminders)
      reminderFireTime(due: due, hasTime: s.hasTime, minutes: m)
  ];
}

/// [list] plus [minutes], sorted, without duplicates.
List<int> withReminder(List<int> list, int minutes) =>
    ({...list, minutes}.toList()..sort());

String reminderLabel(int? m, {required bool hasTime}) {
  if (m == null) return 'No reminder';
  if (m == 0) return hasTime ? 'At time of task' : 'On the day, 9:00 AM';
  if (m % 1440 == 0) {
    final d = m ~/ 1440;
    return d == 1 ? '1 day before' : '$d days before';
  }
  if (m % 60 == 0) {
    final h = m ~/ 60;
    return h == 1 ? '1 hour before' : '$h hours before';
  }
  return '$m min before';
}
