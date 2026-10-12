import 'task.dart';

/// Turns task reminders into OS notifications. Swap the implementation
/// (e.g. push notifications from a server) without touching UI or state.
abstract class ReminderScheduler {
  /// Asks the OS for notification permission. Returns true if granted.
  Future<bool> requestPermission();

  /// Makes the OS schedule match [tasks]: idempotent, safe to call often.
  Future<void> sync(List<TaskItem> tasks);
}

/// Used in tests, on unsupported platforms, or if setup failed.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> sync(List<TaskItem> tasks) async {}
}
