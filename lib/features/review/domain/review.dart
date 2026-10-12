import '../../focus/domain/focus_session.dart';
import '../../habits/domain/habit.dart';
import '../../tasks/domain/task.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

bool _inRange(DateTime d, DateTime start, DateTime end) {
  final x = _day(d);
  return !x.isBefore(start) && !x.isAfter(end);
}

/// A calendar week or month (dates, both ends inclusive).
class ReviewPeriod {
  final DateTime start;
  final DateTime end;
  final bool isMonth;
  final int weekStart; // DateTime.monday..sunday
  const ReviewPeriod._(this.start, this.end, this.isMonth, this.weekStart);

  factory ReviewPeriod.week(DateTime anchor, {int weekStart = DateTime.monday}) {
    final d = _day(anchor);
    final offset = (d.weekday - weekStart + 7) % 7;
    final start = DateTime(d.year, d.month, d.day - offset);
    return ReviewPeriod._(
        start, DateTime(start.year, start.month, start.day + 6), false, weekStart);
  }

  factory ReviewPeriod.month(DateTime anchor, {int weekStart = DateTime.monday}) =>
      ReviewPeriod._(DateTime(anchor.year, anchor.month, 1),
          DateTime(anchor.year, anchor.month + 1, 0), true, weekStart);

  /// The period [delta] weeks/months away (negative = earlier).
  ReviewPeriod shifted(int delta) => isMonth
      ? ReviewPeriod.month(DateTime(start.year, start.month + delta, 1),
          weekStart: weekStart)
      : ReviewPeriod.week(DateTime(start.year, start.month, start.day + 7 * delta),
          weekStart: weekStart);

  bool contains(DateTime d) => _inRange(d, start, end);

  /// True when the whole period lies after today.
  bool isInFuture(DateTime now) => start.isAfter(_day(now));

  int get dayCount =>
      DateTime.utc(end.year, end.month, end.day)
          .difference(DateTime.utc(start.year, start.month, start.day))
          .inDays +
      1;
}

class HabitReview {
  final Habit habit;
  final int scheduled; // scheduled days so far in the period
  final int done; // of those, days the goal was met
  const HabitReview({required this.habit, required this.scheduled, required this.done});
  double get rate => scheduled == 0 ? 0 : done / scheduled;
}

class ReviewData {
  final ReviewPeriod period;

  // Tasks
  final List<TaskItem> completed; // finished in the period, high priority first
  final int dueCount; // tasks that were due in the period
  final int dueDoneCount; // ...and are done
  final List<TaskItem> slipped; // due in the period, still open, date already passed
  final List<(DateTime, int)> perDay; // completed per day, whole period
  final (DateTime, int)? bestDay;

  // Habits
  final List<HabitReview> habits;

  // Focus
  final int focusSeconds;
  final int focusSessions;
  final List<(String, int)> focusByTask; // (task id, seconds), top 3

  // Looking ahead: open tasks due in the next period
  final List<TaskItem> upcoming; // soonest first (all of them)

  const ReviewData({
    required this.period,
    required this.completed,
    required this.dueCount,
    required this.dueDoneCount,
    required this.slipped,
    required this.perDay,
    required this.bestDay,
    required this.habits,
    required this.focusSeconds,
    required this.focusSessions,
    required this.focusByTask,
    required this.upcoming,
  });

  /// Share of tasks due in the period that got done; null if none were due.
  double? get completionRate => dueCount == 0 ? null : dueDoneCount / dueCount;

  /// Habit goals met out of those scheduled; null if no habit had a scheduled day.
  double? get habitRate {
    final scheduled = habits.fold<int>(0, (s, h) => s + h.scheduled);
    final done = habits.fold<int>(0, (s, h) => s + h.done);
    return scheduled == 0 ? null : done / scheduled;
  }
}

ReviewData buildReview({
  required List<TaskItem> tasks,
  required List<Habit> habits,
  required List<FocusSession> sessions,
  required ReviewPeriod period,
  required DateTime now,
}) {
  final today = _day(now);
  final start = period.start, end = period.end;

  bool finishedIn(TaskItem t, DateTime from, DateTime to) =>
      t.done && !t.wontDo && t.completedAt != null && _inRange(t.completedAt!, from, to);

  // ---- tasks ----
  final completed = tasks.where((t) => finishedIn(t, start, end)).toList()
    ..sort((a, b) {
      final p = b.priority.index.compareTo(a.priority.index);
      return p != 0 ? p : b.completedAt!.compareTo(a.completedAt!);
    });

  final due = tasks
      .where((t) => !t.wontDo && t.due != null && _inRange(t.due!, start, end))
      .toList();

  final slipped = due
      .where((t) => !t.done && _day(t.due!).isBefore(today))
      .toList()
    ..sort((a, b) => a.due!.compareTo(b.due!));

  final perDay = [
    for (var i = 0; i < period.dayCount; i++)
      () {
        final day = DateTime(start.year, start.month, start.day + i);
        return (day, tasks.where((t) => finishedIn(t, day, day)).length);
      }()
  ];
  (DateTime, int)? bestDay;
  for (final e in perDay) {
    if (e.$2 > 0 && (bestDay == null || e.$2 > bestDay.$2)) bestDay = e;
  }

  // ---- habits ----
  final habitReviews = <HabitReview>[];
  for (final h in habits) {
    final from = _day(h.createdAt).isAfter(start) ? _day(h.createdAt) : start;
    final to = end.isAfter(today) ? today : end;
    var scheduled = 0, done = 0;
    for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      if (h.isScheduled(d)) {
        scheduled++;
        if (h.doneOn(d)) done++;
      }
    }
    if (scheduled > 0) {
      habitReviews.add(HabitReview(habit: h, scheduled: scheduled, done: done));
    }
  }

  // ---- focus ----
  final inPeriod = sessions.where((s) => _inRange(s.startedAt, start, end)).toList();
  final byTask = <String, int>{};
  for (final s in inPeriod) {
    final id = s.taskId;
    if (id != null) byTask[id] = (byTask[id] ?? 0) + s.seconds;
  }
  final topTasks = byTask.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  // ---- next period ----
  final next = period.shifted(1);
  final upcoming = tasks
      .where((t) => !t.done && !t.wontDo && t.due != null && _inRange(t.due!, next.start, next.end))
      .toList()
    ..sort((a, b) => a.due!.compareTo(b.due!));

  return ReviewData(
    period: period,
    completed: completed,
    dueCount: due.length,
    dueDoneCount: due.where((t) => t.done).length,
    slipped: slipped,
    perDay: perDay,
    bestDay: bestDay,
    habits: habitReviews,
    focusSeconds: inPeriod.fold<int>(0, (s, e) => s + e.seconds),
    focusSessions: inPeriod.length,
    focusByTask: [for (final e in topTasks.take(3)) (e.key, e.value)],
    upcoming: upcoming,
  );
}
