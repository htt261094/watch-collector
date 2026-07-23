import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_photo_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/distribution_chart.dart';
import 'package:watch_collection/features/collection/presentation/stats_page.dart';

/// A repository returning a fixed set of watches, so the derived brand and
/// movement distributions are deterministic.
class _FixedRepository extends InMemoryWatchRepository {
  _FixedRepository(this.watches);

  final List<Watch> watches;

  @override
  Future<List<Watch>> getWatches() async => List.unmodifiable(watches);
}

Widget _wrap(WatchRepository watchRepository) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider.overrideWithValue(watchRepository),
      watchPhotoRepositoryProvider
          .overrideWithValue(InMemoryWatchPhotoRepository()),
      wearLogRepositoryProvider.overrideWithValue(InMemoryWearLogRepository()),
    ],
    child: const MaterialApp(home: StatsPage()),
  );
}

void main() {
  testWidgets('renders a donut chart + legend for brand and movement',
      (tester) async {
    // A tall viewport so both distribution sections build (the list is lazy).
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FixedRepository(const [
      Watch(
          id: '1',
          brand: 'Seiko',
          model: 'SPB143',
          movementType: MovementType.auto),
      Watch(
          id: '2',
          brand: 'Seiko',
          model: 'SKX007',
          movementType: MovementType.auto),
      Watch(
          id: '3', brand: 'Seiko', model: '5', movementType: MovementType.auto),
      Watch(
          id: '4',
          brand: 'Casio',
          model: 'A168',
          movementType: MovementType.quartz),
    ]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Two distributions are drawn as donut charts (one per section).
    expect(find.byType(DistributionChart), findsNWidgets(2));
    expect(find.byType(PieChart), findsNWidgets(2));

    // Section headings are present.
    expect(find.text('By brand'), findsOneWidget);
    expect(find.text('By movement'), findsOneWidget);

    // Legend rows carry the exact figures. Seiko (3) and Casio (1) appear as
    // brand buckets; Automatic (3) and Quartz (1) as movement buckets.
    expect(find.text('Seiko'), findsOneWidget);
    expect(find.text('Casio'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Quartz'), findsOneWidget);

    // The dominant bucket's percentage is shown in the legend (3 of 4 = 75%).
    expect(find.text('75%'), findsNWidgets(2));
    expect(find.text('25%'), findsNWidgets(2));
  });

  testWidgets('shows the empty state when there are no watches',
      (tester) async {
    await tester.pumpWidget(_wrap(_FixedRepository(const [])));
    await tester.pumpAndSettle();

    expect(find.text('No stats yet'), findsOneWidget);
    expect(find.byType(DistributionChart), findsNothing);
  });
}
