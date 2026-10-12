import 'package:intl/intl.dart';

/// Change to DateTime.sunday for a Sunday-first calendar.
const kFirstWeekday = DateTime.monday;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

String formatDue(DateTime due, {required bool hasTime}) {
  final date = DateFormat.MMMd().format(due);
  return hasTime ? '$date, ${DateFormat.jm().format(due)}' : date;
}

/// "Today", "Tomorrow", "Yesterday" or "Oct 9", plus the time if there is one.
String friendlyDue(DateTime due, {required bool hasTime, DateTime? now}) {
  final n = now ?? DateTime.now();
  // UTC math so daylight-saving shifts can't skew the day difference.
  final diff = DateTime.utc(due.year, due.month, due.day)
      .difference(DateTime.utc(n.year, n.month, n.day))
      .inDays;
  final day = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => DateFormat.MMMd().format(due),
  };
  return hasTime ? '$day, ${DateFormat.jm().format(due)}' : day;
}

/// [day] with [old]'s time of day kept when [keepTime], otherwise date-only.
DateTime withDay(DateTime? old, DateTime day, {required bool keepTime}) =>
    keepTime && old != null
        ? DateTime(day.year, day.month, day.day, old.hour, old.minute)
        : dateOnly(day);

/// The day of [old] (or today) at the given time.
DateTime withTime(DateTime? old, int hour, int minute) {
  final base = old ?? DateTime.now();
  return DateTime(base.year, base.month, base.day, hour, minute);
}
