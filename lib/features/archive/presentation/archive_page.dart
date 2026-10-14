import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../habits/domain/habit.dart';
import '../../habits/presentation/habit_icons.dart';
import '../../tasks/presentation/task_tile.dart';
import '../application/activity_providers.dart';

/// History of finished tasks and met habit goals, by day.
class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});
  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  static const _step = 30;
  static const _maxDays = 365;
  int _days = _step;

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final diff = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return DateFormat.MMMEd().format(day);
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(activityDaysProvider(_days));
    final chart = ref.watch(completionChartProvider);
    final today = ref.watch(completedTodayProvider);
    final week = ref.watch(completedThisWeekProvider);
    final month = ref.watch(completedThisMonthProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Row(
              children: [
                _Stat(value: '$today', label: 'Today', color: AppColors.blue),
                _Stat(
                  value: '$week',
                  label: 'This week',
                  color: AppColors.green,
                ),
                _Stat(
                  value: '$month',
                  label: 'This month',
                  color: AppColors.violet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks completed, last 14 days',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                _Bars(data: chart),
              ],
            ),
          ),
          if (days.isEmpty)
            const SizedBox(
              height: 280,
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Nothing finished yet',
                subtitle:
                    'Completed tasks and habit check-ins will show up here.',
              ),
            ),
          for (final d in days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Row(
                children: [
                  Text(
                    _dayLabel(d.day),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    [
                      if (d.tasks.isNotEmpty)
                        '${d.tasks.length} ${d.tasks.length == 1 ? 'task' : 'tasks'}',
                      if (d.habits.isNotEmpty)
                        '${d.habits.length} ${d.habits.length == 1 ? 'habit' : 'habits'}',
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            for (final t in d.tasks) TaskTile(task: t),
            if (d.habits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final h in d.habits) _HabitChip(habit: h)],
                ),
              ),
          ],
          if (_days < _maxDays)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: () => setState(() => _days += _step),
                  child: const Text('Show $_step more days'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _Bars extends StatelessWidget {
  final List<(DateTime, int)> data;
  const _Bars({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppAccent.of(context);
    const maxBar = 80.0;

    return SizedBox(
      height: maxBar + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (data[i].$2 > 0)
                    Text(
                      '${data[i].$2}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    width: 12,
                    height: maxCount == 0
                        ? 4
                        : (maxBar * data[i].$2 / maxCount)
                              .clamp(4.0, maxBar)
                              .toDouble(),
                    decoration: BoxDecoration(
                      color: data[i].$2 == 0
                          ? scheme.outlineVariant.withValues(alpha: 0.5)
                          : (i == data.length - 1
                                ? accent
                                : accent.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat.E().format(data[i].$1).substring(0, 1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == data.length - 1
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitChip extends StatelessWidget {
  final Habit habit;
  const _HabitChip({required this.habit});

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(habitIcon(habit.iconIndex), size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            habit.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.check_rounded, size: 14, color: color),
        ],
      ),
    );
  }
}
