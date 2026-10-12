import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/date_utils.dart';
import '../../tasks/application/task_controller.dart';
import '../../tasks/domain/next_occurrence.dart';
import 'calendar_entry.dart';

enum CalendarMode { month, day }

class CalendarState {
  final DateTime selectedDay;
  final DateTime focusedMonth; // first day of the month on screen
  final CalendarMode mode;
  const CalendarState(
      {required this.selectedDay, required this.focusedMonth, required this.mode});

  CalendarState copyWith(
          {DateTime? selectedDay, DateTime? focusedMonth, CalendarMode? mode}) =>
      CalendarState(
        selectedDay: selectedDay ?? this.selectedDay,
        focusedMonth: focusedMonth ?? this.focusedMonth,
        mode: mode ?? this.mode,
      );
}

class CalendarController extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final today = dateOnly(DateTime.now());
    return CalendarState(
        selectedDay: today,
        focusedMonth: DateTime(today.year, today.month),
        mode: CalendarMode.month);
  }

  void selectDay(DateTime d) => state = state.copyWith(
      selectedDay: dateOnly(d), focusedMonth: DateTime(d.year, d.month));

  void shiftMonth(int delta) => state = state.copyWith(
      focusedMonth: DateTime(state.focusedMonth.year, state.focusedMonth.month + delta));

  void shiftDay(int delta) {
    final s = state.selectedDay;
    selectDay(DateTime(s.year, s.month, s.day + delta));
  }

  void goToday() => selectDay(DateTime.now());
  void setMode(CalendarMode m) => state = state.copyWith(mode: m);
}

final calendarControllerProvider =
    NotifierProvider<CalendarController, CalendarState>(CalendarController.new);

/// Days the UI may need: the focused month plus the selected day.
/// Repeats are only projected inside this window.
final visibleRangeProvider = Provider<(DateTime, DateTime)>((ref) {
  final cal = ref.watch(calendarControllerProvider);
  final monthStart = cal.focusedMonth;
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
  final from = cal.selectedDay.isBefore(monthStart) ? cal.selectedDay : monthStart;
  final to = cal.selectedDay.isAfter(monthEnd) ? cal.selectedDay : monthEnd;
  return (from, to);
});

/// Entries grouped by day (date-only keys): real tasks plus projected future
/// repeats. Open entries first, then by time.
final tasksByDayProvider = Provider<Map<DateTime, List<CalendarEntry>>>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final (rangeFrom, rangeTo) = ref.watch(visibleRangeProvider);
  final today = dateOnly(DateTime.now());
  // Repeats never project into the past: completing rolls forward to today or later.
  final projectFrom = rangeFrom.isBefore(today) ? today : rangeFrom;

  final map = <DateTime, List<CalendarEntry>>{};
  void add(DateTime day, CalendarEntry e) =>
      map.putIfAbsent(dateOnly(day), () => []).add(e);

  for (final t in tasks) {
    if (t.due == null) continue;
    add(t.due!, CalendarEntry(t));
    if (t.recurrence != null && !t.done) {
      for (final occ in occurrencesInRange(t, from: projectFrom, to: rangeTo)) {
        add(occ, CalendarEntry(t.copyWith(due: occ), projected: true));
      }
    }
  }

  for (final list in map.values) {
    list.sort((a, b) {
      if (a.task.done != b.task.done) return a.task.done ? 1 : -1;
      return a.task.due!.compareTo(b.task.due!);
    });
  }
  return map;
});

final selectedDayEntriesProvider = Provider<List<CalendarEntry>>((ref) {
  final day = ref.watch(calendarControllerProvider.select((s) => s.selectedDay));
  return ref.watch(tasksByDayProvider)[day] ?? [];
});
