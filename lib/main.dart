import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'core/navigation.dart';
import 'core/search_launcher.dart';
import 'core/notification_batch.dart';
import 'core/task_focus_time.dart';
import 'core/theme.dart';
import 'core/timer_alarm.dart';
import 'features/focus/application/focus_providers.dart';
import 'features/habits/presentation/habit_detail_page.dart';
import 'features/onboarding/application/onboarding_controller.dart';
import 'features/onboarding/data/local_onboarding_repository.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/tasks/data/local_task_repository.dart';
import 'features/search/presentation/search_page.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/shortcuts/application/shortcut_providers.dart';
import 'features/shortcuts/data/quick_actions_service.dart';
import 'features/settings/data/local_settings_repository.dart';
import 'features/settings/domain/app_settings.dart';
import 'features/tasks/application/reminder_providers.dart';
import 'features/tasks/data/local_notification_scheduler.dart';
import 'features/tasks/domain/reminder_scheduler.dart';
import 'features/tasks/presentation/task_detail_page.dart';

/// Opens the screen a tapped notification points at.
/// Payloads: "habit:<id>" for habits, otherwise a task id.
void _openFromNotification(String payload) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  if (payload.startsWith('habit:')) {
    nav.push(MaterialPageRoute(
        builder: (_) => HabitDetailPage(habitId: payload.substring('habit:'.length))));
  } else {
    nav.push(MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: payload)));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root: choose concrete implementations here.
  ReminderScheduler reminders = const NoopReminderScheduler();
  TimerAlarm alarm = const NoopTimerAlarm();
  NotificationBatch batch = const NoopNotificationBatch();
  try {
    final notifications =
        await LocalNotificationScheduler.create(onOpen: _openFromNotification);
    reminders = notifications; // task reminders
    alarm = notifications; // focus timer alarm
    batch = notifications; // habit reminders
  } catch (_) {
    // unsupported platform / setup issue: stay on the no-op implementations
  }

  // Load the theme settings before the first frame so there's no color flash.
  var settings = const AppSettings();
  try {
    settings = await LocalSettingsRepository().load();
  } catch (_) {
    // fall back to defaults
  }

  // Show the welcome flow only on a fresh install. People who already have
  // tasks (from an earlier version) skip it.
  var onboarded = false;
  try {
    onboarded = await LocalOnboardingRepository().isCompleted() ||
        (await LocalTaskRepository().load()).isNotEmpty;
  } catch (_) {
    onboarded = true; // if storage misbehaves, don't trap the user in the intro
  }

  runApp(ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(() => AppSettingsController(settings)),
      onboardingCompletedProvider.overrideWith(() => OnboardingController(onboarded)),
      shortcutServiceProvider.overrideWithValue(QuickActionsService()),
      openSearchProvider.overrideWithValue(
        (context) => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const GlobalSearchPage())),
      ),
      reminderSchedulerProvider.overrideWithValue(reminders),
      timerAlarmProvider.overrideWithValue(alarm),
      notificationBatchProvider.overrideWithValue(batch),
      // Lets the task screen show focus time without importing the focus feature.
      taskFocusSecondsProvider.overrideWith((ref, taskId) {
        final sessions = ref.watch(focusSessionsProvider).value ?? [];
        return sessions
            .where((s) => s.taskId == taskId)
            .fold<int>(0, (sum, s) => sum + s.seconds);
      }),
    ],
    child: const App(),
  ));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final accent = Color(settings.accent);
    return MaterialApp(
      title: 'TickApp',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: switch (settings.themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: ref.watch(onboardingCompletedProvider)
          ? const AppShell()
          : const OnboardingPage(),
    );
  }
}
