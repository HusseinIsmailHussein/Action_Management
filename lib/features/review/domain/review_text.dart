import 'review.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _short(DateTime d) => '${_months[d.month - 1].substring(0, 3)} ${d.day}';
String _long(DateTime d) => '${_weekdays[d.weekday - 1]}, ${_short(d)}';

String _duration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String _percent(double r) => '${(r * 100).round()}%';

/// "Weekly review: Oct 5 - Oct 11" / "Monthly review: October 2026".
String reviewHeading(ReviewPeriod p) => p.isMonth
    ? 'Monthly review: ${_months[p.start.month - 1]} ${p.start.year}'
    : 'Weekly review: ${_short(p.start)} - ${_short(p.end)}, ${p.end.year}';

/// A plain-text summary of [data] that reads well in a message or note.
/// [titleOf] turns a task id into its title (used for the focus section).
String formatReviewText(ReviewData data, {required String Function(String) titleOf}) {
  final p = data.period;
  final unit = p.isMonth ? 'month' : 'week';
  final out = StringBuffer(reviewHeading(p))..writeln();

  out
    ..writeln()
    ..writeln('Tasks')
    ..writeln('- Completed: ${data.completed.length}');
  if (data.completionRate != null) {
    out.writeln('- Due tasks done: ${data.dueDoneCount} of ${data.dueCount} '
        '(${_percent(data.completionRate!)})');
  }
  if (data.bestDay != null) {
    out.writeln('- Best day: ${_long(data.bestDay!.$1)} '
        '(${_plural(data.bestDay!.$2, 'task', 'tasks')})');
  }

  if (data.completed.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Wins');
    for (final t in data.completed.take(5)) {
      out.writeln('✓ ${t.title}');
    }
    if (data.completed.length > 5) out.writeln('  +${data.completed.length - 5} more');
  }

  if (data.slipped.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Slipped (${data.slipped.length})');
    for (final t in data.slipped.take(8)) {
      out.writeln('- ${t.title} (due ${_short(t.due!)})');
    }
    if (data.slipped.length > 8) out.writeln('  +${data.slipped.length - 8} more');
  }

  if (data.habits.isNotEmpty) {
    out
      ..writeln()
      ..writeln(data.habitRate == null
          ? 'Habits'
          : 'Habits: ${_percent(data.habitRate!)} of goals met');
    for (final h in data.habits) {
      out.writeln('- ${h.habit.name}: ${h.done}/${h.scheduled}');
    }
  }

  if (data.focusSessions > 0) {
    out
      ..writeln()
      ..writeln('Focus: ${_duration(data.focusSeconds)} in '
          '${_plural(data.focusSessions, 'session', 'sessions')}');
    for (final e in data.focusByTask) {
      out.writeln('- ${titleOf(e.$1)}: ${_duration(e.$2)}');
    }
  }

  if (data.upcoming.isNotEmpty) {
    out
      ..writeln()
      ..writeln('Next $unit: ${_plural(data.upcoming.length, 'task', 'tasks')} planned');
    for (final t in data.upcoming.take(5)) {
      out.writeln('- ${t.title} (${_long(t.due!)})');
    }
    if (data.upcoming.length > 5) out.writeln('  +${data.upcoming.length - 5} more');
  }

  return out.toString().trimRight();
}
