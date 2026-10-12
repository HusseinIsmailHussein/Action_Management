import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/date_utils.dart';
import '../../../core/notification_batch.dart';
import '../../../core/timer_alarm.dart';
import '../domain/reminder.dart';
import '../domain/reminder_scheduler.dart';
// `show TaskItem`: the plugin also defines a `Priority` enum.
import '../domain/task.dart' show TaskItem;

/// Notification id reserved for the focus timer alarm (task ids never equal it).
const focusAlarmId = 2147483647;

// Notification id ranges: task reminders [0, 1e9), habit reminders [1e9, 2e9).
const _habitIdBase = 1000000000;
const _habitIdEnd = 2000000000;

typedef _Pending = ({String key, DateTime at, String title, String body, String payload});

/// Schedules task reminders and the focus-timer alarm through one plugin instance.
class LocalNotificationScheduler implements ReminderScheduler, TimerAlarm, NotificationBatch {
  LocalNotificationScheduler._(this._plugin);
  final FlutterLocalNotificationsPlugin _plugin;

  // iOS allows at most 64 pending notifications: 36 task + 24 habit + 1 focus alarm.
  static const _maxPending = 36;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminders for tasks with a due date',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<LocalNotificationScheduler> create({
    required void Function(String payload) onOpen,
  }) async {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = r.payload;
        if (id != null) onOpen(id);
      },
    );

    // App was launched by tapping a reminder while closed.
    final launch = await plugin.getNotificationAppLaunchDetails();
    final launchId = launch?.didNotificationLaunchApp == true
        ? launch!.notificationResponse?.payload
        : null;
    if (launchId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onOpen(launchId));
    }
    return LocalNotificationScheduler._(plugin);
  }

  bool _askedExact = false;

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      // Exact alarms give on-time reminders; without them we fall back to inexact.
      if (!_askedExact && await android.canScheduleExactNotifications() != true) {
        _askedExact = true;
        await android.requestExactAlarmsPermission();
      }
      return granted;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  // Coalesce rapid calls (e.g. typing in a title): only the latest list is applied.
  bool _running = false;
  List<TaskItem>? _next;

  @override
  Future<void> sync(List<TaskItem> tasks) async {
    _next = tasks;
    if (_running) return;
    _running = true;
    try {
      while (_next != null) {
        final batch = _next!;
        _next = null;
        await _apply(batch);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _apply(List<TaskItem> tasks) async {
    // Clear old task reminders; habit reminders and the focus alarm live in other id ranges.
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id < _habitIdBase) await _plugin.cancel(id: p.id);
    }

    final now = DateTime.now();
    final upcoming = <_Pending>[];
    for (final t in tasks) {
      if (t.done) continue;
      for (final at in reminderTimes(t)) {
        if (at.isAfter(now)) {
          upcoming.add((
            key: '${t.id}|${at.millisecondsSinceEpoch}',
            at: at,
            title: t.title,
            body: 'Due ${formatDue(t.due!, hasTime: t.hasTime)}',
            payload: t.id,
          ));
        }
      }
      for (final s in t.subtasks) {
        if (s.done) continue;
        for (final at in subtaskReminderTimes(s)) {
          if (at.isAfter(now)) {
            upcoming.add((
              key: '${s.id}|${at.millisecondsSinceEpoch}',
              at: at,
              title: s.title,
              body: 'Subtask of ${t.title}',
              payload: t.id, // opens the parent task
            ));
          }
        }
      }
    }
    upcoming.sort((a, b) => a.at.compareTo(b.at));
    for (final p in upcoming.take(_maxPending)) {
      await _zoned(
        id: (p.key.hashCode & 0x7fffffff) % _habitIdBase,
        at: p.at,
        title: p.title,
        body: p.body,
        payload: p.payload,
      );
    }
  }

  Future<void> _zoned({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    String? payload,
  }) async {
    // One-shot absolute instant, so no local-timezone lookup is needed.
    final when = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: mode,
          payload: payload,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Exact alarms not permitted -> still notify, possibly a few minutes late.
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  // ---- TimerAlarm (focus timer) ----

  @override
  Future<void> schedule(DateTime at, {required String title, required String body}) =>
      _zoned(id: focusAlarmId, at: at, title: title, body: body);

  @override
  Future<void> cancel() => _plugin.cancel(id: focusAlarmId);

  // ---- NotificationBatch (habit reminders) ----

  bool _batchRunning = false;
  List<ScheduledNote>? _batchNext;

  @override
  Future<void> replaceGroup(String group, List<ScheduledNote> notes) async {
    if (group != 'habits') throw ArgumentError('Unknown notification group: $group');
    _batchNext = notes; // coalesce rapid calls: only the latest list is applied
    if (_batchRunning) return;
    _batchRunning = true;
    try {
      while (_batchNext != null) {
        final batch = _batchNext!;
        _batchNext = null;
        await _applyHabits(batch);
      }
    } finally {
      _batchRunning = false;
    }
  }

  Future<void> _applyHabits(List<ScheduledNote> notes) async {
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= _habitIdBase && p.id < _habitIdEnd) await _plugin.cancel(id: p.id);
    }
    final now = DateTime.now();
    for (final n in notes.where((n) => n.at.isAfter(now))) {
      await _zoned(
        id: _habitIdBase + (n.key.hashCode & 0x7fffffff) % _habitIdBase,
        at: n.at,
        title: n.title,
        body: n.body,
        payload: n.payload,
      );
    }
  }
}
