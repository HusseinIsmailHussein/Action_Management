import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../tasks/application/task_controller.dart';
import '../application/focus_providers.dart';
import '../domain/focus_session.dart';

String formatFocus(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

class FocusStatsCard extends ConsumerWidget {
  const FocusStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(focusTodayProvider);
    final week = ref.watch(focusWeekProvider);
    final sessions = ref.watch(focusSessionsProvider).value ?? [];
    final weekTotal = week.fold<int>(0, (sum, e) => sum + e.$2);

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Stat(label: 'Today', value: formatFocus(today.$1), color: AppAccent.of(context)),
          _Stat(label: 'Sessions', value: '${today.$2}', color: AppColors.green),
          _Stat(label: 'This week', value: formatFocus(weekTotal), color: AppColors.orange),
        ]),
        const SizedBox(height: 20),
        _WeekBars(week: week),
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Recent',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final s in sessions.take(4)) _RecentRow(session: s),
        ],
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}

class _WeekBars extends StatelessWidget {
  final List<(DateTime, int)> week;
  const _WeekBars({required this.week});

  @override
  Widget build(BuildContext context) {
    final maxSeconds = week.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final scheme = Theme.of(context).colorScheme;
    final accent = AppAccent.of(context);
    const maxBar = 72.0;

    return SizedBox(
      height: maxBar + 24,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < week.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                width: 22,
                height: maxSeconds == 0
                    ? 4
                    : (maxBar * week[i].$2 / maxSeconds).clamp(4.0, maxBar).toDouble(),
                decoration: BoxDecoration(
                  gradient: i == week.length - 1 && week[i].$2 > 0
                      ? accent.gradient
                      : null,
                  color: week[i].$2 == 0
                      ? scheme.outlineVariant.withValues(alpha: 0.5)
                      : (i == week.length - 1 ? null : accent.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat.E().format(week[i].$1).substring(0, 1),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == week.length - 1 ? FontWeight.w800 : FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _RecentRow extends ConsumerWidget {
  final FocusSession session;
  const _RecentRow({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = session.taskId == null ? null : ref.watch(taskByIdProvider(session.taskId!));
    final title = session.taskId == null ? 'Free focus' : (task?.title ?? 'Deleted task');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(Icons.timer_rounded, size: 18, color: AppAccent.of(context)),
        const SizedBox(width: 10),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(
          '${DateFormat.MMMd().add_jm().format(session.startedAt)} · ${formatFocus(session.seconds)}',
          style: TextStyle(
              fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
