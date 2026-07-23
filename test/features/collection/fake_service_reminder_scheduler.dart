import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_reminder_scheduler.dart';

/// Test double for [ServiceReminderScheduler] that records interactions instead
/// of touching any real notification plugin.
class FakeServiceReminderScheduler implements ServiceReminderScheduler {
  final List<ServiceRecord> scheduled = [];
  final List<String> cancelled = [];
  bool initCalled = false;
  bool permissionsRequested = false;
  bool cancelAllCalled = false;

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<bool> requestPermissions() async {
    permissionsRequested = true;
    return true;
  }

  @override
  Future<void> scheduleReminder(
    ServiceRecord record, {
    String? watchLabel,
  }) async {
    scheduled.add(record);
  }

  @override
  Future<void> cancelReminder(String recordId) async {
    cancelled.add(recordId);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
  }
}
