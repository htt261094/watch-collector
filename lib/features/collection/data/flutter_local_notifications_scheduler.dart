import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_reminder_scheduler.dart';

/// [ServiceReminderScheduler] backed by `flutter_local_notifications`.
///
/// Reminders fire at 9am (device local time) on the record's due date. Past-due
/// records are skipped — a notification for a date that has already passed would
/// never fire. Scheduling uses the inexact alarm mode so the app does not need
/// the Android 12+ "exact alarm" special permission.
class FlutterLocalNotificationsScheduler implements ServiceReminderScheduler {
  FlutterLocalNotificationsScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'service_reminders';
  static const _channelName = 'Service & warranty reminders';
  static const _channelDescription =
      'Reminders for upcoming watch services and warranty expiries.';

  /// The hour of the day (local time) a reminder fires on its due date.
  static const _reminderHour = 9;

  @override
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Fall back to UTC if the device timezone can't be resolved — reminders
      // still fire, just anchored to UTC rather than local time.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  @override
  Future<void> scheduleReminder(
    ServiceRecord record, {
    String? watchLabel,
  }) async {
    await init();

    // Always clear any previous reminder for this record so an edit that moves
    // the due date into the past leaves nothing stale scheduled.
    await cancelReminder(record.id);

    final when = _reminderInstant(record.dueDate);
    if (when == null) return;

    await _plugin.zonedSchedule(
      reminderNotificationId(record.id),
      _title(record),
      _body(record, watchLabel),
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: record.watchId,
    );
  }

  @override
  Future<void> cancelReminder(String recordId) async {
    await init();
    await _plugin.cancel(reminderNotificationId(recordId));
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// The instant a reminder should fire, or null when it is already in the past.
  tz.TZDateTime? _reminderInstant(DateTime dueDate) {
    final scheduled = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      _reminderHour,
    );
    final now = tz.TZDateTime.now(tz.local);
    return scheduled.isAfter(now) ? scheduled : null;
  }

  String _title(ServiceRecord record) {
    return switch (record.type) {
      ServiceRecordType.service => 'Service due',
      ServiceRecordType.warranty => 'Warranty expiring',
    };
  }

  String _body(ServiceRecord record, String? watchLabel) {
    final subject = (watchLabel == null || watchLabel.trim().isEmpty)
        ? 'your watch'
        : watchLabel.trim();
    final note = record.note?.trim();
    final base = switch (record.type) {
      ServiceRecordType.service =>
        'Service for $subject is due on ${record.formattedDueDate}.',
      ServiceRecordType.warranty =>
        'The warranty for $subject ends on ${record.formattedDueDate}.',
    };
    return (note == null || note.isEmpty) ? base : '$base $note';
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
  }
}
