/// A finished (or stopped-early) focus period.
class FocusSession {
  final String id;
  final String? taskId; // null = free focus
  final DateTime startedAt;
  final int seconds;

  const FocusSession({
    required this.id,
    this.taskId,
    required this.startedAt,
    required this.seconds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'startedAt': startedAt.toIso8601String(),
        'seconds': seconds,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'] as String,
        taskId: j['taskId'] as String?,
        startedAt: DateTime.parse(j['startedAt'] as String),
        seconds: j['seconds'] as int,
      );
}
