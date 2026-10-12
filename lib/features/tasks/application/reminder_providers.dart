import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/reminder_scheduler.dart';

/// Defaults to a no-op; main.dart overrides it with the real scheduler.
final reminderSchedulerProvider =
    Provider<ReminderScheduler>((ref) => const NoopReminderScheduler());
