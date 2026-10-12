import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../tasks/application/task_controller.dart';
import '../application/focus_providers.dart';
import '../application/focus_timer_controller.dart';
import '../domain/pomodoro.dart';
import 'focus_settings_sheet.dart';
import 'focus_stats_card.dart';
import 'task_picker_sheet.dart';
import 'timer_ring.dart';

Color phaseColor(BuildContext context, FocusPhase p) => switch (p) {
      FocusPhase.focus => AppAccent.of(context),
      FocusPhase.shortBreak => AppColors.green,
      FocusPhase.longBreak => AppColors.teal,
    };

String _mmss(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

class FocusPage extends ConsumerWidget {
  const FocusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(focusTimerProvider);
    final ctrl = ref.read(focusTimerProvider.notifier);
    final settings = ref.watch(focusSettingsProvider).value ?? const FocusSettings();
    final color = phaseColor(context, t.phase);
    final task = t.taskId == null ? null : ref.watch(taskByIdProvider(t.taskId!));
    final idle = t.status == TimerStatus.idle;
    final running = t.status == TimerStatus.running;

    final cycleDone = t.phase == FocusPhase.longBreak
        ? settings.longBreakEvery
        : t.completedFocusCount % settings.longBreakEvery;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showFocusSettingsSheet(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          AppCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(t.phase.label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 20),
              TimerRing(
                progress: t.progress,
                color: color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_mmss(t.remainingSeconds),
                      style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  Text(
                    idle ? 'Ready' : (running ? 'In progress' : 'Paused'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < settings.longBreakEvery; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < cycleDone ? color : color.withValues(alpha: 0.18),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: idle
                    ? () => showTaskPicker(context,
                        current: t.taskId, onSelected: ctrl.selectTask)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    IconBadge(icon: Icons.task_alt_rounded, color: color, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task?.title ?? 'Pick a task (optional)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: task == null ? FontWeight.w400 : FontWeight.w600),
                      ),
                    ),
                    if (idle) const Icon(Icons.expand_more_rounded),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton.filledTonal(
                  iconSize: 28,
                  tooltip: 'Stop',
                  onPressed: idle && t.phase == FocusPhase.focus ? null : ctrl.stop,
                  icon: const Icon(Icons.stop_rounded),
                ),
                const SizedBox(width: 24),
                _PlayButton(
                  color: color,
                  running: running,
                  onPressed: running ? ctrl.pause : ctrl.start,
                ),
                const SizedBox(width: 24),
                IconButton.filledTonal(
                  iconSize: 28,
                  tooltip: 'Skip',
                  onPressed: ctrl.skip,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          const FocusStatsCard(),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final Color color;
  final bool running;
  final VoidCallback onPressed;
  const _PlayButton({required this.color, required this.running, required this.onPressed});

  @override
  Widget build(BuildContext context) => Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          gradient: color.gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(
              running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      );
}
