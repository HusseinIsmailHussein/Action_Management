import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../tasks/presentation/add_task_sheet.dart';
import '../../tasks/presentation/task_detail_page.dart';
import '../../tasks/presentation/task_tile.dart';
import '../application/calendar_controller.dart';
import '../application/calendar_entry.dart';

/// Hour-by-hour view of the selected day. Tap an empty slot to add a task at that hour.
class DayTimeline extends ConsumerWidget {
  const DayTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(calendarControllerProvider);
    final ctrl = ref.read(calendarControllerProvider.notifier);
    final entries = ref.watch(selectedDayEntriesProvider);
    final allDay = entries.where((e) => !e.task.hasTime).toList();
    final timed = entries.where((e) => e.task.hasTime).toList();

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200) ctrl.shiftDay(1);
        if (v > 200) ctrl.shiftDay(-1);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          if (allDay.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('All day', style: Theme.of(context).textTheme.labelLarge),
            ),
            for (final e in allDay) TaskTile(task: e.task, projected: e.projected),
            const Divider(),
          ],
          for (var h = 0; h < 24; h++)
            _HourRow(
              hour: h,
              day: cal.selectedDay,
              entries: timed.where((e) => e.task.due!.hour == h).toList(),
            ),
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  final int hour;
  final DateTime day;
  final List<CalendarEntry> entries;
  const _HourRow({required this.hour, required this.day, required this.entries});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showAddTaskSheet(context,
          due: DateTime(day.year, day.month, day.day, hour), hasTime: true),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Text(
                  DateFormat.j().format(DateTime(2000, 1, 1, hour)),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            Expanded(
              child: Column(children: [for (final e in entries) _TimelineChip(entry: e)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  final CalendarEntry entry;
  const _TimelineChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    final color = priorityColor(task.priority);
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id))),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(0, 4, 12, 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: entry.projected ? 0.07 : 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(children: [
          if (entry.projected)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.repeat, size: 14),
            ),
          Expanded(
            child: Text(
              '${DateFormat.jm().format(task.due!)}${task.durationMinutes == null ? '' : ' – ${DateFormat.jm().format(task.due!.add(Duration(minutes: task.durationMinutes!)))}'}  ${task.title}',
              style: TextStyle(
                decoration: task.done ? TextDecoration.lineThrough : null,
                fontStyle: entry.projected ? FontStyle.italic : null,
                color: task.done ? Colors.grey : null,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
