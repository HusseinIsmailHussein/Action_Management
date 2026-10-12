import 'recurrence.dart';
import 'tag.dart';
import 'task.dart';

/// The kinds of details quick add can pick out of typed text.
enum QuickKind { date, time, repeat, priority, tags, list, reminder, duration }

typedef QuickList = ({String id, String name});

/// What [parseQuickAdd] found. [title] is the text left over once the
/// recognised phrases are removed (empty if nothing was left).
class QuickAddResult {
  final String title;
  final DateTime? due; // the day, plus the time when [hasTime]
  final bool hasTime;
  final int? durationMinutes;
  final Priority? priority;
  final List<String> tags;
  final String? listId;
  final String? listName;
  final Recurrence? recurrence;
  final List<int> reminders; // minutes before due
  final Set<QuickKind> kinds; // which details were recognised

  const QuickAddResult({
    required this.title,
    this.due,
    this.hasTime = false,
    this.durationMinutes,
    this.priority,
    this.tags = const [],
    this.listId,
    this.listName,
    this.recurrence,
    this.reminders = const [],
    this.kinds = const {},
  });
}

// ---- vocabulary ----
const _wdFull = 'monday|tuesday|wednesday|thursday|friday|saturday|sunday';
const _wdAbbr = 'tues|tue|wed|thurs|thur|thu|fri|sat|sun|mon';
const _wdAny = '$_wdFull|$_wdAbbr';
const _monthRe =
    'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?';
const _numberWords = {
  'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
};

int _weekday(String w) => switch (w.toLowerCase().substring(0, 3)) {
      'mon' => DateTime.monday,
      'tue' => DateTime.tuesday,
      'wed' => DateTime.wednesday,
      'thu' => DateTime.thursday,
      'fri' => DateTime.friday,
      'sat' => DateTime.saturday,
      _ => DateTime.sunday,
    };

int _month(String m) => const [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ].indexOf(m.toLowerCase().substring(0, 3)) +
    1;

int _number(String w) => int.tryParse(w) ?? _numberWords[w.toLowerCase()] ?? 1;

RepeatUnit _unit(String u) {
  final x = u.toLowerCase();
  if (x.startsWith('d')) return RepeatUnit.day;
  if (x.startsWith('w')) return RepeatUnit.week;
  if (x.startsWith('m')) return RepeatUnit.month;
  return RepeatUnit.year; // year / yearly / annually
}

// ---- date helpers ----
DateTime _day(DateTime d, [int plus = 0]) => DateTime(d.year, d.month, d.day + plus);

/// A real date even when [d] is past the month's end (31 -> 30 / 28).
DateTime _safeDate(int y, int m, int d) {
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d > last ? last : d);
}

/// The next [weekday] from [today], today included.
DateTime _upcoming(DateTime today, int weekday) =>
    _day(today, (weekday - today.weekday + 7) % 7);

/// [weekday] in the following calendar week (weeks start on Monday).
DateTime _nextWeek(DateTime today, int weekday) {
  final toMonday = (DateTime.monday - today.weekday + 7) % 7;
  final nextMonday = _day(today, toMonday == 0 ? 7 : toMonday);
  return _day(nextMonday, weekday - 1);
}

/// This year's [month]/[day], or next year's if that has already passed.
DateTime _nextMonthDay(DateTime today, int month, int day) {
  final d = _safeDate(today.year, month, day);
  return d.isBefore(today) ? _safeDate(today.year + 1, month, day) : d;
}

bool _validMonthDay(int month, int day) => month >= 1 && month <= 12 && day >= 1 && day <= 31;

RegExp _rx(String pattern) => RegExp(pattern, caseSensitive: false);

/// Reads details out of a typed task, so "Dentist friday 3pm #health !high"
/// becomes a task titled "Dentist" with a date, time, tag and priority.
///
/// Understands: dates (today, tomorrow, friday, next monday, in 3 days, oct 15,
/// 10/15, on the 1st, next week/month, this weekend, end of month), times (5pm,
/// 17:30, at 9, noon, "tomorrow morning"), repeats (every day / 2 weeks / mon and thu,
/// weekdays, daily...), priority (!high !1 !!!), #tags, ~list, "remind me" /
/// "remind 30 min before", and "for 45 min" durations.
///
/// Kinds listed in [ignore] are left in the title untouched.
/// A time without a date means today (tomorrow if it has already passed).
QuickAddResult parseQuickAdd(
  String input,
  DateTime now, {
  List<QuickList> lists = const [],
  Set<QuickKind> ignore = const {},
}) {
  var s = ' $input '; // padding lets patterns anchor on whitespace at both ends
  final kinds = <QuickKind>{};
  final today = _day(now);

  bool on(QuickKind k) => !ignore.contains(k);

  /// Removes the first match that [accept] approves.
  bool take(RegExp re, bool Function(RegExpMatch m) accept) {
    for (final m in re.allMatches(s)) {
      if (accept(m)) {
        s = s.replaceRange(m.start, m.end, ' ');
        return true;
      }
    }
    return false;
  }

  // ---------- #tags ----------
  final tags = <String>[];
  if (on(QuickKind.tags)) {
    final found = RegExp(r'(?<=\s)#([A-Za-z0-9_\-]+)(?=[\s,.;!?])').allMatches(s).toList();
    for (final m in found.reversed) {
      final tag = normalizeTag(m.group(1)!);
      if (tag.isNotEmpty && !tags.contains(tag)) tags.insert(0, tag);
      s = s.replaceRange(m.start, m.end, ' ');
    }
    if (tags.isNotEmpty) kinds.add(QuickKind.tags);
  }

  // ---------- ~list ----------
  String? listId, listName;
  if (on(QuickKind.list) && lists.isNotEmpty) {
    final ok = take(RegExp(r'(?<=\s)~(?:"([^"]+)"|([A-Za-z0-9_\-]+))(?=[\s,.;!?])'), (m) {
      final raw = (m.group(1) ?? m.group(2))!.toLowerCase();
      final wanted = raw.replaceAll(RegExp(r'[_\-]'), ' ');
      var pool = lists
          .where((l) => l.name.toLowerCase() == raw || l.name.toLowerCase() == wanted)
          .toList();
      if (pool.isEmpty) {
        pool = lists.where((l) => l.name.toLowerCase().startsWith(wanted)).toList();
      }
      if (pool.length != 1) return false; // unknown or ambiguous: leave it in the title
      listId = pool.first.id;
      listName = pool.first.name;
      return true;
    });
    if (ok) kinds.add(QuickKind.list);
  }

  // ---------- !priority ----------
  Priority? priority;
  if (on(QuickKind.priority)) {
    var ok = take(_rx(r'(?<=\s)!(high|medium|med|low|none|[0-3])(?=[\s,.;!?])'), (m) {
      priority = switch (m.group(1)!.toLowerCase()) {
        'high' || '1' => Priority.high,
        'medium' || 'med' || '2' => Priority.medium,
        'low' || '3' => Priority.low,
        _ => Priority.none,
      };
      return true;
    });
    if (!ok) {
      ok = take(RegExp(r'(?<=\s)(!{2,3})(?=[\s,.;])'), (m) {
        priority = m.group(1)!.length == 3 ? Priority.high : Priority.medium;
        return true;
      });
    }
    if (ok) kinds.add(QuickKind.priority);
  }

  // ---------- repeat ----------
  Recurrence? repeat;
  if (on(QuickKind.repeat)) {
    final ok = take(_rx(r'\bevery\s+weekdays?\b'), (m) {
          repeat = const Recurrence(
              unit: RepeatUnit.week, weekdays: {1, 2, 3, 4, 5});
          return true;
        }) ||
        take(_rx(r'\bevery\s+weekends?\b'), (m) {
          repeat = const Recurrence(unit: RepeatUnit.week, weekdays: {6, 7});
          return true;
        }) ||
        take(_rx(r'\bevery\s+other\s+(day|week|month|year)s?\b'), (m) {
          repeat = Recurrence(unit: _unit(m.group(1)!), interval: 2);
          return true;
        }) ||
        take(_rx(r'\bevery\s+(\d{1,3})\s*(day|week|month|year)s?\b'), (m) {
          final n = int.parse(m.group(1)!);
          if (n < 1) return false;
          repeat = Recurrence(unit: _unit(m.group(2)!), interval: n);
          return true;
        }) ||
        take(_rx('\\bevery\\s+((?:$_wdAny)(?:\\s*(?:,|and|&)\\s*(?:$_wdAny))*)\\b'), (m) {
          final days = RegExp(_wdAny, caseSensitive: false)
              .allMatches(m.group(1)!)
              .map((x) => _weekday(x.group(0)!))
              .toSet();
          repeat = Recurrence(unit: RepeatUnit.week, weekdays: days);
          return true;
        }) ||
        take(_rx(r'\bevery\s+(day|week|month|year)\b'), (m) {
          repeat = Recurrence(unit: _unit(m.group(1)!));
          return true;
        }) ||
        take(_rx(r'\b(daily|weekly|monthly|yearly|annually)\b'), (m) {
          repeat = Recurrence(unit: _unit(m.group(1)!));
          return true;
        });
    if (ok) kinds.add(QuickKind.repeat);
  }

  // ---------- reminder ----------
  final reminders = <int>[];
  var reminderAtStart = false;
  if (on(QuickKind.reminder)) {
    final ok = take(
            _rx(r'\bremind(?:\s+me)?\s+(\d+)\s*(minutes?|mins?|hours?|hrs?|days?)\s+before\b'),
            (m) {
          final n = int.parse(m.group(1)!);
          final u = m.group(2)!.toLowerCase();
          reminders.add(u.startsWith('m') ? n : (u.startsWith('h') ? n * 60 : n * 1440));
          reminderAtStart = m.start <= 1;
          return true;
        }) ||
        take(_rx(r'\bremind\s+me\b'), (m) {
          reminders.add(0);
          reminderAtStart = m.start <= 1;
          return true;
        });
    if (ok) kinds.add(QuickKind.reminder);
  }

  // ---------- date ----------
  DateTime? date;
  DateTime? relative; // "in 30 minutes": a moment, not a day
  var tonight = false;
  if (on(QuickKind.date)) {
    final ok = take(_rx(r'\bday\s+after\s+tomorrow\b'), (m) {
          date = _day(today, 2);
          return true;
        }) ||
        take(_rx(r'\b(?:tomorrow|tmrw|tmr)\b'), (m) {
          date = _day(today, 1);
          return true;
        }) ||
        take(_rx(r'\b(today|tonight)\b'), (m) {
          date = today;
          tonight = m.group(1)!.toLowerCase() == 'tonight';
          return true;
        }) ||
        take(_rx('\\bnext\\s+($_wdAny)\\b'), (m) {
          date = _nextWeek(today, _weekday(m.group(1)!));
          return true;
        }) ||
        take(_rx(r'\bnext\s+week\b'), (m) {
          date = _nextWeek(today, DateTime.monday);
          return true;
        }) ||
        take(_rx(r'\bnext\s+month\b'), (m) {
          date = _safeDate(today.year, today.month + 1, today.day);
          return true;
        }) ||
        take(_rx(r'\bthis\s+weekend\b'), (m) {
          date = _upcoming(today, DateTime.saturday);
          return true;
        }) ||
        take(_rx(r'\bend\s+of\s+(?:the\s+)?month\b'), (m) {
          date = DateTime(today.year, today.month + 1, 0);
          return true;
        }) ||
        take(_rx('\\b(?:on\\s+|this\\s+)?($_wdFull)\\b'), (m) {
          date = _upcoming(today, _weekday(m.group(1)!));
          return true;
        }) ||
        take(_rx('\\b(?:on|this)\\s+($_wdAbbr)\\b'), (m) {
          date = _upcoming(today, _weekday(m.group(1)!));
          return true;
        }) ||
        take(
            _rx(r'\bin\s+(\d+|a|an|one|two|three|four|five|six|seven|eight|nine|ten)\s+(minutes?|mins?|hours?|hrs?|days?|weeks?|months?)\b'),
            (m) {
          final n = _number(m.group(1)!);
          final u = m.group(2)!.toLowerCase();
          if (u.startsWith('min') || u.startsWith('h')) {
            final r = now.add(u.startsWith('min') ? Duration(minutes: n) : Duration(hours: n));
            relative = DateTime(r.year, r.month, r.day, r.hour, r.minute);
          } else if (u.startsWith('d')) {
            date = _day(today, n);
          } else if (u.startsWith('w')) {
            date = _day(today, 7 * n);
          } else {
            date = _safeDate(today.year, today.month + n, today.day);
          }
          return true;
        }) ||
        take(_rx(r'\bon\s+the\s+(\d{1,2})(?:st|nd|rd|th)\b'), (m) {
          final day = int.parse(m.group(1)!);
          if (day < 1 || day > 31) return false;
          var d = _safeDate(today.year, today.month, day);
          if (d.isBefore(today)) d = _safeDate(today.year, today.month + 1, day);
          date = d;
          return true;
        }) ||
        take(_rx('\\b(?:on\\s+)?($_monthRe)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b'), (m) {
          final month = _month(m.group(1)!), day = int.parse(m.group(2)!);
          if (!_validMonthDay(month, day)) return false;
          date = _nextMonthDay(today, month, day);
          return true;
        }) ||
        take(_rx('\\b(?:on\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?($_monthRe)\\b'), (m) {
          final day = int.parse(m.group(1)!), month = _month(m.group(2)!);
          if (!_validMonthDay(month, day)) return false;
          date = _nextMonthDay(today, month, day);
          return true;
        }) ||
        take(_rx(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b'), (m) {
          final month = int.parse(m.group(1)!), day = int.parse(m.group(2)!);
          if (!_validMonthDay(month, day)) return false;
          final y = m.group(3);
          if (y == null) {
            date = _nextMonthDay(today, month, day);
          } else {
            final year = int.parse(y);
            date = _safeDate(year < 100 ? 2000 + year : year, month, day);
          }
          return true;
        });
    if (ok) kinds.add(QuickKind.date);
  }

  // ---------- time ----------
  int? hour, minute;
  if (on(QuickKind.time)) {
    final ok = take(_rx(r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m\.?(?![A-Za-z])'), (m) {
          final h = int.parse(m.group(1)!), min = int.parse(m.group(2) ?? '0');
          if (h < 1 || h > 12 || min > 59) return false;
          hour = m.group(3)!.toLowerCase() == 'p' ? h % 12 + 12 : h % 12;
          minute = min;
          return true;
        }) ||
        take(_rx(r'\b(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)\b'), (m) {
          hour = int.parse(m.group(1)!);
          minute = int.parse(m.group(2)!);
          return true;
        }) ||
        take(_rx(r'\bat\s+(\d{1,2})\b(?!\s*[/:%])'), (m) {
          final h = int.parse(m.group(1)!);
          if (h > 23) return false;
          // No am/pm given: 1-6 reads as afternoon, 7-11 as morning.
          hour = (h >= 1 && h <= 6) ? h + 12 : h;
          minute = 0;
          return true;
        }) ||
        take(_rx(r'\bnoon\b'), (m) {
          hour = 12;
          minute = 0;
          return true;
        }) ||
        take(_rx(r'\bmidnight\b'), (m) {
          hour = 0;
          minute = 0;
          return true;
        }) ||
        (date != null &&
            take(_rx(r'\b(?:in\s+the\s+|this\s+)?(morning|afternoon|evening|night)\b'), (m) {
              hour = switch (m.group(1)!.toLowerCase()) {
                'morning' => 9,
                'afternoon' => 15,
                'evening' => 18,
                _ => 21,
              };
              minute = 0;
              return true;
            }));
    if (ok) kinds.add(QuickKind.time);
  }
  if (tonight && hour == null) {
    hour = 20;
    minute = 0;
    kinds.add(QuickKind.time);
  }

  // ---------- put date and time together ----------
  DateTime? due;
  var hasTime = false;
  if (relative != null) {
    due = relative;
    hasTime = true;
  } else {
    final timeGiven = hour != null;
    DateTime? day = date;
    if (day == null && (timeGiven || repeat != null)) {
      day = today;
      if (timeGiven && !DateTime(day.year, day.month, day.day, hour!, minute ?? 0).isAfter(now)) {
        day = _day(today, 1); // today's time has already passed
      }
    }
    if (day != null) {
      var d = timeGiven ? DateTime(day.year, day.month, day.day, hour!, minute ?? 0) : day;
      // A weekday rule should start on one of its days.
      if (repeat != null && date == null) d = repeat!.alignDue(d);
      due = d;
      hasTime = timeGiven;
    }
  }
  // A reminder needs something to be relative to.
  if (reminders.isNotEmpty && due == null) {
    due = today;
    hasTime = false;
  }

  // ---------- duration ("for 45 min", only with a time) ----------
  int? duration;
  if (on(QuickKind.duration) && hasTime) {
    final ok = take(_rx(r'\bfor\s+(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\b'), (m) {
      final v = double.parse(m.group(1)!);
      final minutes = (m.group(2)!.toLowerCase().startsWith('h') ? v * 60 : v).round();
      if (minutes < 1 || minutes > 24 * 60) return false;
      duration = minutes;
      return true;
    });
    if (ok) kinds.add(QuickKind.duration);
  }

  // ---------- tidy the title ----------
  var title = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  title = title.replaceAll(RegExp(r'^[\s,;:\-]+|[\s,;:\-]+$'), '');
  String previous;
  do {
    previous = title;
    // Words left dangling by a removed phrase: "submit report by", "call at".
    title = title
        .replaceAll(RegExp(r'\s+(on|at|by|due|until|before|from|in|for|every)$', caseSensitive: false), '')
        .trim();
  } while (title != previous);
  if (reminderAtStart) {
    title = title.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '');
  }

  return QuickAddResult(
    title: title,
    due: due,
    hasTime: hasTime,
    durationMinutes: duration,
    priority: priority,
    tags: tags,
    listId: listId,
    listName: listName,
    recurrence: repeat,
    reminders: reminders,
    kinds: kinds,
  );
}
