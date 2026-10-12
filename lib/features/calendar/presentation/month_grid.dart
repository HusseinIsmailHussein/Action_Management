import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/date_utils.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_tile.dart';
import '../application/calendar_controller.dart';

class MonthGrid extends ConsumerWidget {
  const MonthGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(calendarControllerProvider);
    final ctrl = ref.read(calendarControllerProvider.notifier);
    final byDay = ref.watch(tasksByDayProvider);
    final scheme = Theme.of(context).colorScheme;
    final month = cal.focusedMonth;
    final offset = (DateTime(month.year, month.month, 1).weekday - kFirstWeekday + 7) % 7;
    final weeks = ((offset + daysInMonth(month)) / 7).ceil();
    final today = dateOnly(DateTime.now());

    Widget cell(int dayNumber) {
      if (dayNumber < 1 || dayNumber > daysInMonth(month)) {
        return const SizedBox(height: 52);
      }
      final date = DateTime(month.year, month.month, dayNumber);
      // Up to three dots, colored by the priority of the day's open tasks.
      final dots = [
        for (final e in (byDay[date] ?? []).where((e) => !e.task.done).take(3))
          e.task.priority == Priority.none
              ? scheme.primary
              : priorityColor(e.task.priority)
      ];
      return _DayCell(
        date: date,
        selected: isSameDay(date, cal.selectedDay),
        isToday: isSameDay(date, today),
        dots: dots,
        onTap: () => ctrl.selectDay(date),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200) ctrl.shiftMonth(1);
        if (v > 200) ctrl.shiftMonth(-1);
      },
      child: Column(children: [
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    // 2024-01-01 is a Monday
                    DateFormat.E()
                        .format(DateTime(2024, 1, 1 + (kFirstWeekday - 1) + i))
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ]),
        for (var w = 0; w < weeks; w++)
          Row(children: [
            for (var c = 0; c < 7; c++) Expanded(child: cell(w * 7 + c - offset + 1)),
          ]),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool selected, isToday;
  final List<Color> dots;
  final VoidCallback onTap;
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.dots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color? fill = selected
        ? scheme.primary
        : isToday
            ? scheme.primaryContainer
            : null;
    final Color? textColor = selected
        ? scheme.onPrimary
        : isToday
            ? scheme.onPrimaryContainer
            : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: selected || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 5,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final c in dots)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
