import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_custom_field_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_watch_photo_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/collection/presentation/watch_detail_page.dart';

Widget _wrap(
  Widget child, {
  required WatchRepository watchRepository,
  WearLogRepository? wearLogRepository,
}) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider.overrideWithValue(watchRepository),
      watchPhotoRepositoryProvider
          .overrideWithValue(InMemoryWatchPhotoRepository()),
      wearLogRepositoryProvider
          .overrideWithValue(wearLogRepository ?? InMemoryWearLogRepository()),
      customFieldRepositoryProvider
          .overrideWithValue(InMemoryCustomFieldRepository()),
    ],
    child: MaterialApp(home: child),
  );
}

class _SeededRepository extends InMemoryWatchRepository {
  _SeededRepository(this.watch);

  final Watch watch;

  @override
  Future<Watch?> getWatch(String id) async => id == watch.id ? watch : null;
}

void main() {
  const watch = Watch(
    id: 'w1',
    brand: 'Omega',
    model: 'Speedmaster',
    referenceNo: '311.30',
    movementType: MovementType.manual,
    caliber: '1861',
    diameter: 42,
    complications: ['Chronograph'],
    notes: 'Moonwatch.',
  );

  testWidgets('shows the four sub-tabs and the overview specs',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const WatchDetailPage(watchId: 'w1'),
        watchRepository: _SeededRepository(watch),
      ),
    );
    await tester.pumpAndSettle();

    // Tabs are present.
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Wear history'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);

    // Overview shows specs (title appears in AppBar + spec value).
    expect(find.text('Omega Speedmaster'), findsOneWidget);
    expect(find.text('311.30'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);

    // The Case / Complications / Notes sections sit below the fold; drag the
    // overview list up so their lazily-built rows are laid out, then assert.
    final list = find.byType(ListView);
    for (final text in ['42 mm', 'Chronograph', 'Moonwatch.']) {
      await tester.dragUntilVisible(
        find.text(text),
        list,
        const Offset(0, -120),
      );
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('placeholder tabs report coming soon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const WatchDetailPage(watchId: 'w1'),
        watchRepository: _SeededRepository(watch),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accuracy'));
    await tester.pumpAndSettle();

    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('one-tap wear logs today and reflects the worn state',
      (tester) async {
    final wearLog = InMemoryWearLogRepository();
    await tester.pumpWidget(
      _wrap(
        const WatchDetailPage(watchId: 'w1'),
        watchRepository: _SeededRepository(watch),
        wearLogRepository: wearLog,
      ),
    );
    await tester.pumpAndSettle();

    // Starts unworn: the action offers to wear it today.
    expect(find.byTooltip('Wear today'), findsOneWidget);
    expect(find.byTooltip('Worn today'), findsNothing);

    await tester.tap(find.byTooltip('Wear today'));
    await tester.pumpAndSettle();

    // The tap wrote a wear entry for today and the action now reads as worn.
    expect(await wearLog.getWatchIdsWornOn(DateTime.now()), {'w1'});
    expect(find.byTooltip('Worn today'), findsOneWidget);
    expect(find.text('Wearing Omega Speedmaster today'), findsOneWidget);
  });

  testWidgets('double-tapping in a day does not create a duplicate log',
      (tester) async {
    final wearLog = InMemoryWearLogRepository();
    await tester.pumpWidget(
      _wrap(
        const WatchDetailPage(watchId: 'w1'),
        watchRepository: _SeededRepository(watch),
        wearLogRepository: wearLog,
      ),
    );
    await tester.pumpAndSettle();

    // Log, then unmark: state round-trips back to "not worn" with no residue.
    await tester.tap(find.byTooltip('Wear today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Worn today'));
    await tester.pumpAndSettle();

    expect(await wearLog.getWatchIdsWornOn(DateTime.now()), isEmpty);
    expect(find.byTooltip('Wear today'), findsOneWidget);
  });

  testWidgets('handles a missing watch gracefully', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const WatchDetailPage(watchId: 'does-not-exist'),
        watchRepository: _SeededRepository(watch),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('This watch is no longer available.'), findsOneWidget);
  });
}
