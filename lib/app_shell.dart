import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/focus_request.dart';
import 'core/tab_request.dart';
import 'features/calendar/presentation/calendar_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/focus/presentation/focus_page.dart';
import 'features/habits/application/habit_controller.dart';
import 'features/habits/presentation/habit_form_sheet.dart';
import 'features/habits/presentation/habits_page.dart';
import 'features/shortcuts/application/shortcut_providers.dart';
import 'features/shortcuts/domain/shortcut_service.dart';
import 'features/tasks/application/task_controller.dart';
import 'features/tasks/presentation/add_task_sheet.dart';
import 'features/tasks/presentation/home_page.dart';

class AppTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  const AppTab(this.label, this.icon, this.selectedIcon, this.page);
}

/// To add a screen, add its label to AppTabs (core/tab_request.dart) and append one AppTab here.
const _tabs = <AppTab>[
  AppTab(AppTabs.home, Icons.home_outlined, Icons.home_rounded, DashboardPage()),
  AppTab(AppTabs.tasks, Icons.check_circle_outline_rounded, Icons.check_circle_rounded,
      HomePage()),
  AppTab(AppTabs.calendar, Icons.calendar_month_outlined, Icons.calendar_month_rounded,
      CalendarPage()),
  AppTab(AppTabs.habits, Icons.local_fire_department_outlined,
      Icons.local_fire_department_rounded, HabitsPage()),
  AppTab(AppTabs.focus, Icons.timer_outlined, Icons.timer_rounded, FocusPage()),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(shortcutServiceProvider).init(_onShortcut);
  }

  /// Home-screen shortcut (long-press the app icon). May arrive during start-up,
  /// so wait for the first frame before opening anything.
  void _onShortcut(ShortcutAction action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (action) {
        case ShortcutAction.newTask:
          showAddTaskSheet(context);
        case ShortcutAction.newHabit:
          _openTab(AppTabs.habits);
          showHabitForm(context);
        case ShortcutAction.focus:
          _openTab(AppTabs.focus);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Reminders are one-off notifications planned ahead, so extend them
  /// whenever the app is opened again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(taskControllerProvider.notifier).resyncReminders();
      ref.read(habitControllerProvider.notifier).resyncReminders();
    }
  }

  void _openTab(String label) {
    final i = _tabs.indexWhere((t) => t.label == label);
    if (i >= 0) setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    // "Focus on this task" from a task screen.
    ref.listen(focusRequestProvider, (_, id) {
      if (id != null) _openTab(AppTabs.focus);
    });
    // Tab switches requested from anywhere (e.g. dashboard shortcuts).
    ref.listen(tabRequestProvider, (_, label) {
      if (label == null) return;
      _openTab(label);
      ref.read(tabRequestProvider.notifier).clear();
    });

    return Scaffold(
      body: IndexedStack(index: _index, children: [for (final t in _tabs) t.page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
                icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
        ],
      ),
    );
  }
}
