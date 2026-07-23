import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/collection_stats.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/domain/wear_entry.dart';
import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/stats_page.dart';

WearEntry _entry(String watchId, DateTime day) => WearEntry(
      id: '$watchId-${day.toIso8601String()}',
      watchId: watchId,
      wornOn: day,
    );

Widget _wrap({
  required WatchRepository watchRepository,
  required WearLogRepository wearLogRepository,
}) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider.overrideWithValue(watchRepository),
      wearLogRepositoryProvider.overrideWithValue(wearLogRepository),
    ],
    child: const MaterialApp(home: StatsPage()),
  );
}

void main() {
  group('computeCollectionStats', () {
    const seiko = Watch(
      id: 'w1',
      brand: 'Seiko',
      model: 'SPB143',
      movementType: MovementType.auto,
      purchasePrice: 1200,
    );
    const casio = Watch(
      id: 'w2',
      brand: 'Casio',
      model: 'A168',
      movementType: MovementType.quartz,
      purchasePrice: 60,
    );
    const orient = Watch(
      id: 'w3',
      brand: 'Seiko',
      model: 'Alpinist',
      movementType: MovementType.auto,
      // no price
    );

    test('totals, cost-per-wear, most/least worn, wears this year', () {
      final now = DateTime(2026, 7, 23);
      final entries = [
        // Seiko: 3 wears, 2 this year.
        _entry('w1', DateTime(2026, 7, 20)),
        _entry('w1', DateTime(2026, 7, 21)),
        _entry('w1', DateTime(2025, 12, 31)),
        // Casio: 1 wear this year.
        _entry('w2', DateTime(2026, 1, 5)),
        // Orient (w3): never worn.
      ];

      final stats = computeCollectionStats(
        const [seiko, casio, orient],
        entries,
        now: now,
      );

      expect(stats.totalWatches, 3);
      expect(stats.totalWears, 4);
      expect(stats.wearsThisYear, 3);

      // Most worn is Seiko (3); least worn is the never-worn Orient (0).
      expect(stats.mostWorn!.watch.id, 'w1');
      expect(stats.mostWorn!.wearCount, 3);
      expect(stats.leastWorn!.watch.id, 'w3');
      expect(stats.leastWorn!.wearCount, 0);

      // Cost-per-wear: Seiko 1200/3 = 400, Casio 60/1 = 60.
      final byId = {for (final s in stats.perWatch) s.watch.id: s};
      expect(byId['w1']!.costPerWear, 400);
      expect(byId['w2']!.costPerWear, 60);
      // No price -> null; never worn -> null.
      expect(byId['w3']!.costPerWear, isNull);
      expect(byId['w1']!.wearsThisYear, 2);
    });

    test('distribution by brand and movement, ordered by count', () {
      final stats = computeCollectionStats(
        const [seiko, casio, orient],
        const [],
        now: DateTime(2026, 7, 23),
      );

      // Two Seikos, one Casio.
      expect(stats.byBrand.first.label, 'Seiko');
      expect(stats.byBrand.first.count, 2);
      expect(stats.byBrand.map((c) => c.label), ['Seiko', 'Casio']);

      // Two automatics, one quartz.
      expect(stats.byMovement.first.label, 'Automatic');
      expect(stats.byMovement.first.count, 2);
    });

    test('movement type left blank falls into Unspecified bucket', () {
      const noMovement = Watch(id: 'x', brand: 'Timex', model: 'Q');
      final stats = computeCollectionStats(
        const [noMovement],
        const [],
        now: DateTime(2026, 7, 23),
      );
      expect(stats.byMovement.single.label, kUnspecifiedMovementLabel);
    });

    test('empty collection has no most/least worn', () {
      final stats = computeCollectionStats(const [], const []);
      expect(stats.isEmpty, isTrue);
      expect(stats.mostWorn, isNull);
      expect(stats.leastWorn, isNull);
    });

    test('single watch is not reported as least worn', () {
      final stats = computeCollectionStats(
        const [seiko],
        [_entry('w1', DateTime(2026, 7, 20))],
        now: DateTime(2026, 7, 23),
      );
      expect(stats.mostWorn!.watch.id, 'w1');
      expect(stats.leastWorn, isNull);
    });
  });

  group('formatMoney', () {
    test('adds thousands separators and trims whole numbers', () {
      expect(formatMoney(400), '400');
      expect(formatMoney(1200), '1,200');
      expect(formatMoney(1234567), '1,234,567');
    });

    test('keeps up to two decimals', () {
      expect(formatMoney(59.5), '59.50');
      expect(formatMoney(33.333), '33.33');
    });
  });

  group('StatsPage', () {
    testWidgets('renders totals and cost-per-wear', (tester) async {
      // InMemoryWatchRepository seeds Seiko (id 1) and Casio (id 2).
      final watches = InMemoryWatchRepository();
      await watches.saveWatch(
        const Watch(
          id: '1',
          brand: 'Seiko',
          model: 'SPB143',
          movementType: MovementType.auto,
          purchasePrice: 1000,
        ),
      );
      final wearLog = InMemoryWearLogRepository();
      await wearLog.logWear('1', DateTime.now());

      await tester.pumpWidget(
        _wrap(watchRepository: watches, wearLogRepository: wearLog),
      );
      await tester.pumpAndSettle();

      expect(find.text('Watches'), findsOneWidget);
      expect(find.text('Total wears'), findsOneWidget);
      expect(find.text('Cost per wear'), findsOneWidget);
      expect(find.text('Worn most'), findsOneWidget);
      // 1000 / 1 wear = 1,000 per wear.
      expect(find.text('1,000'), findsWidgets);
    });

    testWidgets('empty collection shows the empty state', (tester) async {
      final watches = InMemoryWatchRepository();
      for (final w in await watches.getWatches()) {
        await watches.deleteWatch(w.id);
      }

      await tester.pumpWidget(
        _wrap(
          watchRepository: watches,
          wearLogRepository: InMemoryWearLogRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No stats yet'), findsOneWidget);
    });
  });
}
