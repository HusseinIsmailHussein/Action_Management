import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/focus_providers.dart';
import '../domain/pomodoro.dart';

Future<void> showFocusSettingsSheet(BuildContext context) =>
    showModalBottomSheet(context: context, builder: (_) => const _SettingsSheet());

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  int _step(int v, int delta, int lo, int hi) => math.max(lo, math.min(hi, v + delta));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(focusSettingsProvider).value ?? const FocusSettings();
    final update = ref.read(focusSettingsProvider.notifier).save;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Timer settings',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          _StepperRow(
            label: 'Focus',
            value: '${s.focusMinutes} min',
            onMinus: () => update(s.copyWith(focusMinutes: _step(s.focusMinutes, -5, 5, 120))),
            onPlus: () => update(s.copyWith(focusMinutes: _step(s.focusMinutes, 5, 5, 120))),
          ),
          _StepperRow(
            label: 'Short break',
            value: '${s.shortBreakMinutes} min',
            onMinus: () =>
                update(s.copyWith(shortBreakMinutes: _step(s.shortBreakMinutes, -1, 1, 30))),
            onPlus: () =>
                update(s.copyWith(shortBreakMinutes: _step(s.shortBreakMinutes, 1, 1, 30))),
          ),
          _StepperRow(
            label: 'Long break',
            value: '${s.longBreakMinutes} min',
            onMinus: () =>
                update(s.copyWith(longBreakMinutes: _step(s.longBreakMinutes, -5, 5, 60))),
            onPlus: () =>
                update(s.copyWith(longBreakMinutes: _step(s.longBreakMinutes, 5, 5, 60))),
          ),
          _StepperRow(
            label: 'Long break after',
            value: '${s.longBreakEvery} sessions',
            onMinus: () =>
                update(s.copyWith(longBreakEvery: _step(s.longBreakEvery, -1, 2, 8))),
            onPlus: () =>
                update(s.copyWith(longBreakEvery: _step(s.longBreakEvery, 1, 2, 8))),
          ),
        ]),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          IconButton.filledTonal(
              onPressed: onMinus, icon: const Icon(Icons.remove_rounded)),
          SizedBox(
            width: 104,
            child: Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton.filledTonal(onPressed: onPlus, icon: const Icon(Icons.add_rounded)),
        ]),
      );
}
