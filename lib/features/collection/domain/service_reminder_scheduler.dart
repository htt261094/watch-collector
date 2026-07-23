import 'package:watch_collection/features/collection/domain/service_record.dart';

/// Schedules and cancels the local notifications that remind the user a service
/// is due or a warranty is about to expire (M6 — issue #16).
///
/// Kept as an abstraction so the presentation layer never depends on a concrete
/// notification plugin, and so tests can substitute a fake that simply records
/// which reminders were scheduled/cancelled.
abstract interface class ServiceReminderScheduler {
  /// Prepares the underlying notification system. Safe to call more than once;
  /// implementations must be idempotent.
  Future<void> init();

  /// Requests the OS permission needed to post notifications (Android 13+ /
  /// iOS). Returns whether permission is granted. Implementations that need no
  /// permission return true.
  Future<bool> requestPermissions();

  /// Schedules (or reschedules) the reminder for [record]. A reminder whose due
  /// date is in the past is not scheduled. [watchLabel] is woven into the
  /// notification text (e.g. "Seiko SPB143").
  Future<void> scheduleReminder(ServiceRecord record, {String? watchLabel});

  /// Cancels the reminder previously scheduled for the record with [recordId].
  Future<void> cancelReminder(String recordId);

  /// Cancels every scheduled service reminder.
  Future<void> cancelAll();
}

/// Maps a string record id to the stable 32-bit integer id the notification
/// system requires. Shared by implementations and tests so a record always maps
/// to the same notification.
int reminderNotificationId(String recordId) {
  // FNV-1a hash folded into a positive 31-bit int.
  var hash = 0x811c9dc5;
  for (final unit in recordId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
