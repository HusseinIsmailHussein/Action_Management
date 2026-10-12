import 'habit.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _prev(DateTime d) => DateTime(d.year, d.month, d.day - 1);

const _maxLookback = 3650; // ~10 years

/// Consecutive scheduled days completed, ending today. Days the habit isn't
/// scheduled don't break a streak, and today not being done *yet* doesn't either.
int currentStreak(Habit h, DateTime now) {
  var day = _day(now);
  if (h.isScheduled(day) && !h.doneOn(day)) day = _prev(day);
  var streak = 0;
  for (var i = 0; i < _maxLookback; i++) {
    if (h.isScheduled(day)) {
      if (!h.doneOn(day)) break;
      streak++;
    }
    day = _prev(day);
  }
  return streak;
}

/// Longest run of completed scheduled days in the habit's history.
int bestStreak(Habit h, DateTime now) {
  if (h.logs.isEmpty) return 0;
  final today = _day(now);
  var start = _day(h.createdAt);
  for (final key in h.logs.keys) {
    final d = DateTime.tryParse(key);
    if (d != null && d.isBefore(start)) start = _day(d);
  }
  var best = 0, run = 0;
  var day = start;
  for (var i = 0; i < _maxLookback && !day.isAfter(today); i++) {
    if (h.isScheduled(day)) {
      if (h.doneOn(day)) {
        run++;
        if (run > best) best = run;
      } else if (day != today) {
        run = 0; // an unfinished today doesn't end a run yet
      }
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return best;
}

/// Number of days with a completed check-in.
int totalCompletedDays(Habit h) =>
    h.logs.values.where((count) => count >= h.target).length;

/// Share (0..1) of scheduled days completed over the last [days] days
/// (not counting days before the habit was created).
double completionRate(Habit h, DateTime now, {int days = 30}) {
  final today = _day(now);
  final created = _day(h.createdAt);
  var scheduled = 0, done = 0;
  for (var i = 0; i < days; i++) {
    final d = DateTime(today.year, today.month, today.day - i);
    if (d.isBefore(created)) break;
    if (!h.isScheduled(d)) continue;
    scheduled++;
    if (h.doneOn(d)) done++;
  }
  return scheduled == 0 ? 0 : done / scheduled;
}
