enum RepeatUnit { day, week, month, year }

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _fmt(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

/// "Every [interval] [unit]s", optionally on chosen weekdays (weekly rules),
/// ending on a date ([until]) or after [count] occurrences (the current one included).
/// With [fromCompletion] the next date is counted from the day the task is
/// completed instead of from its due date.
class Recurrence {
  final RepeatUnit unit;
  final int interval;
  final bool fromCompletion;
  final Set<int> weekdays; // DateTime.monday..sunday; only used for weekly rules
  final DateTime? until; // last allowed date (inclusive)
  final int? count; // occurrences left, including the current one

  const Recurrence({
    required this.unit,
    this.interval = 1,
    this.fromCompletion = false,
    this.weekdays = const {},
    this.until,
    this.count,
  });

  bool get _weeklyOnDays => unit == RepeatUnit.week && weekdays.isNotEmpty;

  /// Pass `weekdays: const {}` to clear the weekdays.
  Recurrence copyWith({
    RepeatUnit? unit,
    int? interval,
    bool? fromCompletion,
    Set<int>? weekdays,
    DateTime? until,
    bool clearUntil = false,
    int? count,
    bool clearCount = false,
  }) =>
      Recurrence(
        unit: unit ?? this.unit,
        interval: interval ?? this.interval,
        fromCompletion: fromCompletion ?? this.fromCompletion,
        weekdays: weekdays ?? this.weekdays,
        until: clearUntil ? null : (until ?? this.until),
        count: clearCount ? null : (count ?? this.count),
      );

  /// The occurrence after [from], keeping the time of day.
  /// Month/year steps clamp to the month's last day (Jan 31 -> Feb 28).
  DateTime next(DateTime from) {
    if (_weeklyOnDays) return _nextOnWeekdays(from);
    return switch (unit) {
      RepeatUnit.day => DateTime(
          from.year, from.month, from.day + interval, from.hour, from.minute),
      RepeatUnit.week => DateTime(
          from.year, from.month, from.day + 7 * interval, from.hour, from.minute),
      RepeatUnit.month => _addMonths(from, interval),
      RepeatUnit.year => _addMonths(from, 12 * interval),
    };
  }

  /// Next chosen weekday after [from]; once the week is used up, jump
  /// [interval] weeks ahead (weeks start on Monday) to the first chosen day.
  DateTime _nextOnWeekdays(DateTime from) {
    final days = weekdays.toList()..sort();
    for (final d in days) {
      if (d > from.weekday) {
        return DateTime(from.year, from.month, from.day + (d - from.weekday),
            from.hour, from.minute);
      }
    }
    final delta = -(from.weekday - 1) + 7 * interval + (days.first - 1);
    return DateTime(from.year, from.month, from.day + delta, from.hour, from.minute);
  }

  /// For weekday rules: moves [due] forward to the first chosen weekday
  /// (so the task doesn't start on a day the rule excludes).
  DateTime alignDue(DateTime due) {
    if (!_weeklyOnDays || weekdays.contains(due.weekday)) return due;
    for (var i = 1; i < 7; i++) {
      final d = DateTime(due.year, due.month, due.day + i, due.hour, due.minute);
      if (weekdays.contains(d.weekday)) return d;
    }
    return due;
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day > lastDay ? lastDay : d.day, d.hour, d.minute);
  }

  /// The rule without its end condition: "Daily", "Weekly on Mon, Thu"...
  String get ruleLabel {
    if (_weeklyOnDays) {
      final days = (weekdays.toList()..sort()).map((d) => _weekdayNames[d - 1]).join(', ');
      return interval == 1 ? 'Weekly on $days' : 'Every $interval weeks on $days';
    }
    if (interval == 1) {
      return switch (unit) {
        RepeatUnit.day => 'Daily',
        RepeatUnit.week => 'Weekly',
        RepeatUnit.month => 'Monthly',
        RepeatUnit.year => 'Yearly',
      };
    }
    return 'Every $interval ${unit.name}s';
  }

  String get endLabel => until != null
      ? 'On ${_fmt(until!)}'
      : (count != null ? 'After $count ${count == 1 ? 'time' : 'times'}' : 'Never');

  String get label {
    var s = ruleLabel;
    if (until != null) s += ' · until ${_fmt(until!)}';
    if (count != null) s += ' · $count ${count == 1 ? 'time' : 'times'}';
    if (fromCompletion) s += ' · from completion';
    return s;
  }

  Map<String, dynamic> toJson() => {
        'unit': unit.index,
        'interval': interval,
        'fromCompletion': fromCompletion,
        'weekdays': (weekdays.toList()..sort()),
        'until': until?.toIso8601String(),
        'count': count,
      };

  factory Recurrence.fromJson(Map<String, dynamic> j) => Recurrence(
        unit: RepeatUnit.values[j['unit'] as int],
        interval: j['interval'] as int,
        fromCompletion: (j['fromCompletion'] ?? false) as bool,
        weekdays: {...List<int>.from((j['weekdays'] ?? const []) as List)},
        until: j['until'] == null ? null : DateTime.parse(j['until'] as String),
        count: j['count'] as int?,
      );

  @override
  bool operator ==(Object o) =>
      o is Recurrence &&
      o.unit == unit &&
      o.interval == interval &&
      o.fromCompletion == fromCompletion &&
      o.until == until &&
      o.count == count &&
      o.weekdays.length == weekdays.length &&
      o.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(
      unit, interval, fromCompletion, until, count, Object.hashAllUnordered(weekdays));
}

const kRepeatPresets = <Recurrence>[
  Recurrence(unit: RepeatUnit.day),
  Recurrence(unit: RepeatUnit.week),
  Recurrence(unit: RepeatUnit.month),
  Recurrence(unit: RepeatUnit.year),
];
