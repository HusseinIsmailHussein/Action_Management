import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../focus/application/focus_providers.dart';
import '../../habits/application/habit_controller.dart';
import '../../tasks/application/filter_controller.dart';
import '../../tasks/application/list_controller.dart';
import '../../tasks/application/saved_filter_controller.dart';
import '../../tasks/application/task_controller.dart';
import '../data/share_plus_exporter.dart';
import '../domain/backup_bundle.dart';
import '../domain/backup_exporter.dart';

final backupExporterProvider = Provider<BackupExporter>((ref) => SharePlusExporter());

final backupServiceProvider = Provider<BackupService>(BackupService.new);

/// Reads every repository into a [BackupBundle] and writes one back.
class BackupService {
  final Ref ref;
  BackupService(this.ref);

  Future<BackupBundle> collect() async {
    final focus = ref.read(focusRepositoryProvider);
    return BackupBundle(
      tasks: await ref.read(taskRepositoryProvider).load(),
      lists: await ref.read(listRepositoryProvider).load(),
      savedFilters: await ref.read(savedFilterRepositoryProvider).load(),
      habits: await ref.read(habitRepositoryProvider).load(),
      focusSessions: await focus.loadSessions(),
      focusSettings: await focus.loadSettings(),
      exportedAt: DateTime.now(),
    );
  }

  /// Replaces ALL stored data with [bundle], then reloads the app's state
  /// (which also re-plans reminders).
  Future<void> restore(BackupBundle bundle) async {
    await ref.read(taskRepositoryProvider).save(bundle.tasks);
    await ref.read(listRepositoryProvider).save(bundle.lists);
    await ref.read(savedFilterRepositoryProvider).save(bundle.savedFilters);
    await ref.read(habitRepositoryProvider).save(bundle.habits);
    final focus = ref.read(focusRepositoryProvider);
    await focus.saveSessions(bundle.focusSessions);
    await focus.saveSettings(bundle.focusSettings);

    // UI state that might point at data that no longer exists.
    ref
        .read(selectedViewProvider.notifier)
        .select(const ViewSelection.smart(SmartView.today));
    ref.read(taskFilterProvider.notifier).clear();

    ref.invalidate(taskControllerProvider);
    ref.invalidate(listControllerProvider);
    ref.invalidate(savedFilterControllerProvider);
    ref.invalidate(habitControllerProvider);
    ref.invalidate(focusSessionsProvider);
    ref.invalidate(focusSettingsProvider);
  }
}
