import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_reminder_scheduler.dart';

void main() {
  group('ServiceRecordType', () {
    test('round-trips through its storage key', () {
      for (final type in ServiceRecordType.values) {
        expect(ServiceRecordType.fromStorage(type.storageKey), type);
      }
    });

    test('unknown/legacy keys default to service', () {
      expect(ServiceRecordType.fromStorage(null), ServiceRecordType.service);
      expect(ServiceRecordType.fromStorage('nonsense'),
          ServiceRecordType.service,);
    });
  });

  group('ServiceRecord', () {
    ServiceRecord recordDue(DateTime due) => ServiceRecord(
          id: 'r1',
          watchId: 'w1',
          type: ServiceRecordType.service,
          dueDate: due,
        );

    test('formats the due date as ISO yyyy-MM-dd', () {
      expect(recordDue(DateTime(2026, 3, 4)).formattedDueDate, '2026-03-04');
    });

    test('isOverdue is true for a past due date', () {
      final now = DateTime(2026, 7, 23);
      expect(recordDue(DateTime(2026, 7, 22)).isOverdue(now), isTrue);
    });

    test('isOverdue is false for today and the future', () {
      final now = DateTime(2026, 7, 23, 15);
      expect(recordDue(DateTime(2026, 7, 23)).isOverdue(now), isFalse);
      expect(recordDue(DateTime(2026, 7, 24)).isOverdue(now), isFalse);
    });

    test('hasCardPhoto reflects the stored path', () {
      expect(recordDue(DateTime(2026, 1, 1)).hasCardPhoto, isFalse);
      final withPhoto = ServiceRecord(
        id: 'r1',
        watchId: 'w1',
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2026, 1, 1),
        cardPhotoPath: '/path/card.jpg',
      );
      expect(withPhoto.hasCardPhoto, isTrue);
    });
  });

  group('reminderNotificationId', () {
    test('is stable for the same id', () {
      expect(reminderNotificationId('abc'), reminderNotificationId('abc'));
    });

    test('differs for different ids and stays a positive 31-bit int', () {
      final a = reminderNotificationId('record-a');
      final b = reminderNotificationId('record-b');
      expect(a, isNot(b));
      for (final id in [a, b]) {
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7fffffff));
      }
    });
  });
}
