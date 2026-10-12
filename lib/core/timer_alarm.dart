import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One-off alarm that fires a notification even if the app is in the background.
/// Used by the focus timer; main.dart plugs in the real implementation.
abstract class TimerAlarm {
  Future<bool> requestPermission();
  Future<void> schedule(DateTime at, {required String title, required String body});
  Future<void> cancel();
}

class NoopTimerAlarm implements TimerAlarm {
  const NoopTimerAlarm();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> schedule(DateTime at, {required String title, required String body}) async {}
  @override
  Future<void> cancel() async {}
}

final timerAlarmProvider = Provider<TimerAlarm>((ref) => const NoopTimerAlarm());
