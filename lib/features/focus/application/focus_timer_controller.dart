import 'dart:async';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/focus_request.dart';
import '../../../core/timer_alarm.dart';
import '../domain/focus_session.dart';
import '../domain/pomodoro.dart';
import 'focus_providers.dart';

enum TimerStatus { idle, running, paused }

class FocusTimerState {
  final FocusPhase phase;
  final TimerStatus status;
  final int totalSeconds;
  final int remainingSeconds;
  final String? taskId;
  final int completedFocusCount; // focus sessions finished in this run of the app
  final DateTime? endsAt; // set while running

  const FocusTimerState({
    required this.phase,
    required this.status,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.completedFocusCount,
    this.taskId,
    this.endsAt,
  });

  double get progress => totalSeconds == 0 ? 0 : 1 - remainingSeconds / totalSeconds;
  int get elapsedSeconds => totalSeconds - remainingSeconds;

  FocusTimerState copyWith({
    FocusPhase? phase,
    TimerStatus? status,
    int? totalSeconds,
    int? remainingSeconds,
    String? taskId,
    bool clearTask = false,
    int? completedFocusCount,
    DateTime? endsAt,
    bool clearEnds = false,
  }) =>
      FocusTimerState(
        phase: phase ?? this.phase,
        status: status ?? this.status,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        completedFocusCount: completedFocusCount ?? this.completedFocusCount,
        taskId: clearTask ? null : (taskId ?? this.taskId),
        endsAt: clearEnds ? null : (endsAt ?? this.endsAt),
      );
}

/// Pomodoro state machine. Time is derived from a wall-clock end time, so the
/// countdown stays correct if the app is backgrounded, and a notification is
/// scheduled for the end in case the app isn't on screen.
class FocusTimerController extends Notifier<FocusTimerState> {
  Timer? _ticker;

  FocusSettings get _settings =>
      ref.read(focusSettingsProvider).value ?? const FocusSettings();

  FocusTimerState _idle(FocusPhase phase, int count, String? taskId) {
    final seconds = _settings.secondsFor(phase);
    return FocusTimerState(
      phase: phase,
      status: TimerStatus.idle,
      totalSeconds: seconds,
      remainingSeconds: seconds,
      completedFocusCount: count,
      taskId: taskId,
    );
  }

  @override
  FocusTimerState build() {
    ref.onDispose(() => _ticker?.cancel());

    // New durations apply as soon as the timer is idle.
    ref.listen(focusSettingsProvider, (_, __) {
      if (state.status == TimerStatus.idle) {
        state = _idle(state.phase, state.completedFocusCount, state.taskId);
      }
    });

    // "Focus on this task" from the task screen.
    ref.listen(focusRequestProvider, (_, id) {
      if (id == null) return;
      if (state.status == TimerStatus.idle) state = state.copyWith(taskId: id);
      ref.read(focusRequestProvider.notifier).clear();
    });

    return _idle(FocusPhase.focus, 0, null);
  }

  void selectTask(String? id) {
    if (state.status != TimerStatus.idle) return;
    state = state.copyWith(taskId: id, clearTask: id == null);
  }

  void start() {
    if (state.status == TimerStatus.running) return;
    if (state.status == TimerStatus.idle) {
      ref.read(timerAlarmProvider).requestPermission().catchError((_) => false);
    }
    _run(state.remainingSeconds);
  }

  void resume() => start();

  void pause() {
    if (state.status != TimerStatus.running) return;
    _tick(); // settle remaining time (may complete the phase)
    if (state.status != TimerStatus.running) return;
    _ticker?.cancel();
    _cancelAlarm();
    state = state.copyWith(status: TimerStatus.paused, clearEnds: true);
  }

  /// Abandon the current phase and return to a fresh focus session.
  void stop() {
    _logPartialFocus();
    _halt();
    state = _idle(FocusPhase.focus, state.completedFocusCount, state.taskId);
  }

  /// Jump to the next phase of the cycle without counting this one as done.
  void skip() {
    _logPartialFocus();
    _halt();
    state = _idle(nextPhase(state.phase, state.completedFocusCount, _settings),
        state.completedFocusCount, state.taskId);
  }

  // ---- internals ----

  void _run(int seconds) {
    final endsAt = DateTime.now().add(Duration(seconds: seconds));
    state = state.copyWith(
        status: TimerStatus.running, endsAt: endsAt, remainingSeconds: seconds);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    final focusing = state.phase == FocusPhase.focus;
    ref
        .read(timerAlarmProvider)
        .schedule(
          endsAt,
          title: focusing ? 'Focus session complete' : 'Break is over',
          body: focusing
              ? 'Nice work! Time for a break.'
              : 'Ready for the next focus session?',
        )
        .catchError((_) {});
  }

  void _tick() {
    final end = state.endsAt;
    if (end == null) return;
    final left = (end.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    if (left <= 0) {
      _complete();
    } else if (left != state.remainingSeconds) {
      state = state.copyWith(remainingSeconds: left);
    }
  }

  void _complete() {
    _ticker?.cancel();
    final wasFocus = state.phase == FocusPhase.focus;
    final count = state.completedFocusCount + (wasFocus ? 1 : 0);
    if (wasFocus) {
      _log(state.totalSeconds,
          DateTime.now().subtract(Duration(seconds: state.totalSeconds)));
    }
    HapticFeedback.heavyImpact();
    state = _idle(nextPhase(state.phase, count, _settings), count, state.taskId);
  }

  void _halt() {
    _ticker?.cancel();
    _cancelAlarm();
  }

  void _cancelAlarm() => ref.read(timerAlarmProvider).cancel().catchError((_) {});

  /// Stopping or skipping a focus session keeps the time if it was at least a minute.
  void _logPartialFocus() {
    if (state.phase == FocusPhase.focus && state.elapsedSeconds >= 60) {
      _log(state.elapsedSeconds,
          DateTime.now().subtract(Duration(seconds: state.elapsedSeconds)));
    }
  }

  void _log(int seconds, DateTime startedAt) {
    ref.read(focusSessionsProvider.notifier).add(FocusSession(
          id: const Uuid().v4(),
          taskId: state.taskId,
          startedAt: startedAt,
          seconds: seconds,
        ));
  }
}

final focusTimerProvider =
    NotifierProvider<FocusTimerController, FocusTimerState>(FocusTimerController.new);
