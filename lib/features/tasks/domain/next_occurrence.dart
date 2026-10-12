import 'task.dart';

DateTime _shiftDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The task rolled forward to its next occurrence (open, subtasks reset and
/// their dates moved along), or null if it doesn't repeat or the series has
/// ended (last occurrence, or the next date is past the end date).
/// Date-based repeats skip ahead if overdue by several cycles so the next due
/// date is today or later; "after completion" repeats count from today.
TaskItem? nextOccurrence(TaskItem t, DateTime now) {
  final rule = t.recurrence;
  final due = t.due;
  if (rule == null || due == null) return null;
  if (rule.count != null && rule.count! <= 1) return null; // that was the last one

  final today = _dateOnly(now);
  DateTime next;
  if (rule.fromCompletion) {
    next = rule.next(DateTime(now.year, now.month, now.day, due.hour, due.minute));
  } else {
    next = rule.next(due);
    for (var i = 0; i < 1000 && next.isBefore(today); i++) {
      next = rule.next(next);
    }
  }
  if (rule.until != null && _dateOnly(next).isAfter(_dateOnly(rule.until!))) {
    return null; // the next one would be after the end date
  }

  final shift = DateTime.utc(next.year, next.month, next.day)
      .difference(DateTime.utc(due.year, due.month, due.day))
      .inDays;

  return t.copyWith(
    due: next,
    done: false,
    clearCompleted: true,
    recurrence: rule.count == null ? rule : rule.copyWith(count: rule.count! - 1),
    subtasks: [
      for (final s in t.subtasks)
        s.copyWith(
          done: false,
          due: s.due == null ? null : _shiftDays(s.due!, shift),
        ),
    ],
  );
}

/// Future occurrences of a repeating task (after its current due date) that
/// fall on days within [from]..[to] (date-only, inclusive), respecting the
/// end date / occurrence count. Used by the calendar to show repeats ahead of
/// time. "After completion" repeats can't be predicted, so they show nothing.
List<DateTime> occurrencesInRange(
  TaskItem t, {
  required DateTime from,
  required DateTime to,
}) {
  final rule = t.recurrence;
  final due = t.due;
  if (rule == null || due == null || rule.fromCompletion) return const [];

  final result = <DateTime>[];
  var occ = rule.next(due);
  var produced = 0; // the current occurrence is not counted here
  for (var i = 0; i < 5000; i++) {
    if (rule.count != null && produced >= rule.count! - 1) break;
    final day = _dateOnly(occ);
    if (day.isAfter(to)) break;
    if (rule.until != null && day.isAfter(_dateOnly(rule.until!))) break;
    produced++;
    if (!day.isBefore(from)) result.add(occ);
    occ = rule.next(occ);
  }
  return result;
}
