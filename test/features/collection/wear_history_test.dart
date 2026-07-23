import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_page.dart';
import 'package:watch_collection/features/collection/presentation/wear_history_tab.dart';

Widget _wrap(
  Widget child, {
  required WatchRepository watchRepository,
  required WearLogRepository wearLogRepository,
}) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider.overrideWithValue(watchRepository),
      wearLogRepositoryProvider.overrideWithValue(wearLogRepository),
    ],
    child: MaterialApp(home: child),
  );
}

InMemoryWatchRepository _watchesWith(List<Watch> watches) {
  final repo = InMemoryWatchRepository();
  for (final w in watches) {
    repo.saveWatch(w);
  }
  return repo;
}

void main() {
  group('InMemoryWearLogRepository', () {
    test('mirrors the drift semantics for history + edit/delete', () async {
      final repo = InMemoryWearLogRepository();
      await repo.logWear('w1', DateTime(2026, 7, 20));
      await repo.logWear('w1', DateTime(2026, 7, 23));
      await repo.logWear('w2', DateTime(2026, 7, 22));

      // Per-watch, most recent first.
      final w1 = await repo.getEntriesForWatch('w1');
      expect(w1.map((e) => e.wornOn),
          [DateTime(2026, 7, 23), DateTime(2026, 7, 20)]);

      // Whole collection, most recent first.
      final all = await repo.getAllEntries();
      expect(all.map((e) => e.watchId), ['w1', 'w2', 'w1']);

      // Edit moves the day and trims the note.
      await repo.updateEntry(w1.last.id,
          wornOn: DateTime(2026, 7, 25), note: '  gym  ');
      final edited = await repo.getEntriesForWatch('w1');
      expect(edited.first.wornOn, DateTime(2026, 7, 25));
      expect(edited.first.note, 'gym');

      // Delete removes just that record.
      await repo.deleteEntry(edited.first.id);
      expect(await repo.getEntriesForWatch('w1'), hasLength(1));
    });

    test('updateEntry keeps one entry per watch per day on collision',
        () async {
      final repo = InMemoryWearLogRepository();
      await repo.logWear('w1', DateTime(2026, 7, 20));
      await repo.logWear('w1', DateTime(2026, 7, 21));
      final entries = await repo.getEntriesForWatch('w1');
      final toMove =
          entries.firstWhere((e) => e.wornOn == DateTime(2026, 7, 20));

      await repo.updateEntry(toMove.id, wornOn: DateTime(2026, 7, 21));

      expect(await repo.getEntriesForWatch('w1'), hasLength(1));
    });
  });

  group('WearHistoryTab', () {
    testWidgets('shows logged wears with a summary', (tester) async {
      final wearLog = InMemoryWearLogRepository();
      await wearLog.logWear('w1', DateTime(2026, 7, 20));
      await wearLog.logWear('w1', DateTime(2026, 7, 23));

      await tester.pumpWidget(
        _wrap(
          const WearHistoryTab(watchId: 'w1'),
          watchRepository:
              _watchesWith(const [Watch(id: 'w1', brand: 'A', model: 'B')]),
          wearLogRepository: wearLog,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Times worn'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // total wears
      expect(find.text('23 Jul 2026'), findsOneWidget);
      expect(find.text('20 Jul 2026'), findsOneWidget);
    });

    testWidgets('empty state prompts to log a wear', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const WearHistoryTab(watchId: 'w1'),
          watchRepository:
              _watchesWith(const [Watch(id: 'w1', brand: 'A', model: 'B')]),
          wearLogRepository: InMemoryWearLogRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No wears logged yet'), findsOneWidget);
    });

    testWidgets('delete removes a wear record', (tester) async {
      final wearLog = InMemoryWearLogRepository();
      await wearLog.logWear('w1', DateTime(2026, 7, 20));

      await tester.pumpWidget(
        _wrap(
          const WearHistoryTab(watchId: 'w1'),
          watchRepository:
              _watchesWith(const [Watch(id: 'w1', brand: 'A', model: 'B')]),
          wearLogRepository: wearLog,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await wearLog.getEntriesForWatch('w1'), isEmpty);
      expect(find.text('No wears logged yet'), findsOneWidget);
    });
  });

  group('WearHistoryPage', () {
    testWidgets('lists wears across watches, labelled by watch',
        (tester) async {
      final wearLog = InMemoryWearLogRepository();
      await wearLog.logWear('w1', DateTime(2026, 7, 20));
      await wearLog.logWear('w2', DateTime(2026, 7, 23));

      await tester.pumpWidget(
        _wrap(
          const WearHistoryPage(),
          watchRepository: _watchesWith(const [
            Watch(id: 'w1', brand: 'Seiko', model: 'SPB143'),
            Watch(id: 'w2', brand: 'Casio', model: 'A168'),
          ]),
          wearLogRepository: wearLog,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Seiko SPB143'), findsOneWidget);
      expect(find.text('Casio A168'), findsOneWidget);
      expect(find.text('23 Jul 2026'), findsOneWidget);
      expect(find.text('20 Jul 2026'), findsOneWidget);
    });
  });
}
