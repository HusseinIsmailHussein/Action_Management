import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/search_launcher.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/gradient_fab.dart';
import '../../tasks/presentation/add_task_sheet.dart';
import '../../tasks/presentation/task_tile.dart';
import '../application/calendar_controller.dart';
import 'day_timeline.dart';
import 'month_grid.dart';

enum _Menu { month, day, today, search }

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(calendarControllerProvider);
    final ctrl = ref.read(calendarControllerProvider.notifier);
    final isMonth = cal.mode == CalendarMode.month;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMonth
            ? DateFormat.yMMMM().format(cal.focusedMonth)
            : DateFormat.MMMEd().format(cal.selectedDay)),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => isMonth ? ctrl.shiftMonth(-1) : ctrl.shiftDay(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => isMonth ? ctrl.shiftMonth(1) : ctrl.shiftDay(1),
          ),
          PopupMenuButton<_Menu>(
            onSelected: (m) {
              switch (m) {
                case _Menu.month:
                  ctrl.setMode(CalendarMode.month);
                case _Menu.day:
                  ctrl.setMode(CalendarMode.day);
                case _Menu.today:
                  ctrl.goToday();
                case _Menu.search:
                  ref.read(openSearchProvider)(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Menu.month, child: Text('Month view')),
              PopupMenuItem(value: _Menu.day, child: Text('Day view')),
              PopupMenuItem(value: _Menu.today, child: Text('Go to today')),
              PopupMenuItem(value: _Menu.search, child: Text('Search')),
            ],
          ),
        ],
      ),
      body: isMonth ? const _MonthBody() : const DayTimeline(),
      floatingActionButton: GradientFab(
        onPressed: () => showAddTaskSheet(context, due: cal.selectedDay),
      ),
    );
  }
}

class _MonthBody extends ConsumerWidget {
  const _MonthBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(calendarControllerProvider.select((s) => s.selectedDay));
    final entries = ref.watch(selectedDayEntriesProvider);
    final open = entries.where((e) => !e.task.done).length;

    return Column(children: [
      const AppCard(
        margin: EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.fromLTRB(8, 12, 8, 8),
        radius: 24,
        child: MonthGrid(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(children: [
          Text(DateFormat.MMMEd().format(day),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('$open open',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
      Expanded(
        child: entries.isEmpty
            ? const EmptyState(
                icon: Icons.event_available_rounded,
                title: 'Free day',
                subtitle: 'No tasks on this day.')
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: entries.length,
                itemBuilder: (_, i) =>
                    TaskTile(task: entries[i].task, projected: entries[i].projected),
              ),
      ),
    ]);
  }
}
