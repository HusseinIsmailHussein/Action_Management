import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One notification to show at a specific time.
class ScheduledNote {
  final String key; // unique within its group
  final DateTime at;
  final String title;
  final String body;
  final String? payload; // delivered back when the notification is tapped
  const ScheduledNote({
    required this.key,
    required this.at,
    required this.title,
    required this.body,
    this.payload,
  });
}

/// Replaces all pending notifications of a named group (e.g. 'habits') in one go,
/// leaving other groups untouched. main.dart plugs in the real implementation.
abstract class NotificationBatch {
  Future<bool> requestPermission();
  Future<void> replaceGroup(String group, List<ScheduledNote> notes);
}

class NoopNotificationBatch implements NotificationBatch {
  const NoopNotificationBatch();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> replaceGroup(String group, List<ScheduledNote> notes) async {}
}

final notificationBatchProvider =
    Provider<NotificationBatch>((ref) => const NoopNotificationBatch());
