import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/application/habit_controller.dart';
import '../../tasks/application/task_controller.dart';
import '../domain/sample_data.dart';

final sampleDataServiceProvider = Provider<SampleDataService>(SampleDataService.new);

/// Adds or removes the sample tasks and habits shown in the welcome flow.
class SampleDataService {
  final Ref ref;
  SampleDataService(this.ref);

  Future<void> add() async {
    // Wait for stored data to load first, otherwise it could overwrite the samples.
    await ref.read(taskControllerProvider.future);
    await ref.read(habitControllerProvider.future);
    final now = DateTime.now();
    await ref.read(taskControllerProvider.notifier).addAll(sampleTasks(now));
    await ref.read(habitControllerProvider.notifier).addAll(sampleHabits(now));
  }

  Future<void> remove() async {
    await ref.read(taskControllerProvider.future);
    await ref.read(habitControllerProvider.future);
    await ref
        .read(taskControllerProvider.notifier)
        .removeWhere((t) => t.id.startsWith(kSamplePrefix));
    await ref
        .read(habitControllerProvider.notifier)
        .removeWhere((h) => h.id.startsWith(kSamplePrefix));
  }
}

/// True while any sample task or habit is still around.
final hasSampleDataProvider = Provider<bool>((ref) {
  final tasks = ref.watch(taskControllerProvider).value ?? [];
  final habits = ref.watch(habitControllerProvider).value ?? [];
  return tasks.any((t) => t.id.startsWith(kSamplePrefix)) ||
      habits.any((h) => h.id.startsWith(kSamplePrefix));
});
