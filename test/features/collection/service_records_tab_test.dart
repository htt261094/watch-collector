import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_service_record_repository.dart';
import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_record_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/service_records_tab.dart';
import 'package:watch_collection/features/pro/data/in_memory_pro_repository.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

import '../pro/fake_purchase_service.dart';
import 'fake_service_reminder_scheduler.dart';

void main() {
  Widget wrap({
    required ServiceRecordRepository repository,
    required FakeServiceReminderScheduler scheduler,
    required bool proUnlocked,
  }) {
    return ProviderScope(
      overrides: [
        serviceRecordRepositoryProvider.overrideWithValue(repository),
        serviceReminderSchedulerProvider.overrideWithValue(scheduler),
        proRepositoryProvider
            .overrideWithValue(InMemoryProRepository(proUnlocked: proUnlocked)),
        purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
      ],
      child: const MaterialApp(
        home: ServiceRecordsTab(watchId: 'w1', watchLabel: 'Seiko SPB143'),
      ),
    );
  }

  testWidgets('shows the empty state when there are no reminders',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        repository: InMemoryServiceRecordRepository(),
        scheduler: FakeServiceReminderScheduler(),
        proUnlocked: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No reminders yet'), findsOneWidget);
  });

  testWidgets('lists existing reminders with type and due date',
      (tester) async {
    final repo = InMemoryServiceRecordRepository();
    await repo.addRecord(
      'w1',
      type: ServiceRecordType.warranty,
      dueDate: DateTime(2027, 3, 4),
    );

    await tester.pumpWidget(
      wrap(
        repository: repo,
        scheduler: FakeServiceReminderScheduler(),
        proUnlocked: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Warranty'), findsOneWidget);
    expect(find.text('Due 2027-03-04'), findsOneWidget);
  });

  testWidgets('flags an overdue reminder', (tester) async {
    final repo = InMemoryServiceRecordRepository();
    await repo.addRecord(
      'w1',
      type: ServiceRecordType.service,
      dueDate: DateTime(2000, 1, 1),
    );

    await tester.pumpWidget(
      wrap(
        repository: repo,
        scheduler: FakeServiceReminderScheduler(),
        proUnlocked: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('a Pro user can add a reminder and it schedules a notification',
      (tester) async {
    final repo = InMemoryServiceRecordRepository();
    final scheduler = FakeServiceReminderScheduler();
    await tester.pumpWidget(
      wrap(repository: repo, scheduler: scheduler, proUnlocked: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Add reminder'), findsWidgets);

    // Pick a due date (defaults to today) and confirm.
    await tester.tap(find.widgetWithText(TextButton, 'Pick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(await repo.getRecordsForWatch('w1'), hasLength(1));
    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.permissionsRequested, isTrue);
  });

  testWidgets('a free user is routed to the paywall on Add', (tester) async {
    await tester.pumpWidget(
      wrap(
        repository: InMemoryServiceRecordRepository(),
        scheduler: FakeServiceReminderScheduler(),
        proUnlocked: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Pro'), findsOneWidget);
  });

  testWidgets('can delete a reminder via the overflow menu', (tester) async {
    final repo = InMemoryServiceRecordRepository();
    final id = await repo.addRecord(
      'w1',
      type: ServiceRecordType.service,
      dueDate: DateTime(2027, 1, 1),
    );
    final scheduler = FakeServiceReminderScheduler();

    await tester.pumpWidget(
      wrap(repository: repo, scheduler: scheduler, proUnlocked: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repo.getRecordsForWatch('w1'), isEmpty);
    expect(scheduler.cancelled, contains(id));
  });
}
