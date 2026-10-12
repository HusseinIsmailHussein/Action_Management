import 'day_key.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A recurring habit with its check-in history.
/// [logs] maps a day key to how many times it was done that day;
/// a day is complete when the count reaches [target].
class Habit {
  final String id;
  final String name;
  final int iconIndex; // index into the app's icon list (presentation)
  final int color; // ARGB
  final Set<int> weekdays; // DateTime.monday..sunday; all 7 = every day
  final int target; // times per day
  final int? reminderAt; // minutes after midnight; null = no reminder
  final Map<String, int> logs;
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.name,
    this.iconIndex = 0,
    required this.color,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.target = 1,
    this.reminderAt,
    this.logs = const {},
    required this.createdAt,
  });

  bool get isDaily => weekdays.length == 7;

  String get frequencyLabel {
    if (isDaily) return 'Every day';
    final days = weekdays.toList()..sort();
    return days.map((d) => _dayNames[d - 1]).join(', ');
  }

  bool isScheduled(DateTime d) => weekdays.contains(d.weekday);
  int countOn(DateTime d) => logs[dayKey(d)] ?? 0;
  bool doneOn(DateTime d) => countOn(d) >= target;

  /// Copy with the check-in count for [day] set (0 removes the entry).
  Habit withCount(DateTime day, int count) {
    final next = Map<String, int>.of(logs);
    if (count <= 0) {
      next.remove(dayKey(day));
    } else {
      next[dayKey(day)] = count;
    }
    return copyWith(logs: next);
  }

  Habit copyWith({
    String? name,
    int? iconIndex,
    int? color,
    Set<int>? weekdays,
    int? target,
    int? reminderAt,
    bool clearReminder = false,
    Map<String, int>? logs,
  }) =>
      Habit(
        id: id,
        name: name ?? this.name,
        iconIndex: iconIndex ?? this.iconIndex,
        color: color ?? this.color,
        weekdays: weekdays ?? this.weekdays,
        target: target ?? this.target,
        reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
        logs: logs ?? this.logs,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconIndex': iconIndex,
        'color': color,
        'weekdays': (weekdays.toList()..sort()),
        'target': target,
        'reminderAt': reminderAt,
        'logs': logs,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        iconIndex: (j['iconIndex'] ?? 0) as int,
        color: j['color'] as int,
        weekdays: {...List<int>.from((j['weekdays'] ?? const [1, 2, 3, 4, 5, 6, 7]) as List)},
        target: (j['target'] ?? 1) as int,
        reminderAt: j['reminderAt'] as int?,
        logs: ((j['logs'] ?? const {}) as Map)
            .map((k, v) => MapEntry(k as String, v as int)),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
