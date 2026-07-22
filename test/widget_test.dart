import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_home_page.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';

class _StubWatchRepository implements WatchRepository {
  @override
  Future<List<Watch>> getWatches() async {
    return const [
      Watch(
        id: '1',
        brand: 'Rolex',
        model: 'Submariner',
        movementType: MovementType.auto,
      ),
    ];
  }

  @override
  Future<Watch?> getWatch(String id) async => null;

  @override
  Future<void> saveWatch(Watch watch) async {}

  @override
  Future<void> deleteWatch(String id) async {}
}

/// Wraps the home page with in-memory repositories so no real database is
/// opened during the test.
Widget _harness(WatchRepository watches) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider.overrideWithValue(watches),
      wearLogRepositoryProvider.overrideWithValue(InMemoryWearLogRepository()),
    ],
    child: const MaterialApp(home: CollectionHomePage()),
  );
}

void main() {
  testWidgets('renders watches as gallery cards', (tester) async {
    await tester.pumpWidget(_harness(_StubWatchRepository()));

    // Initially the FutureProvider is loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the future resolve.
    await tester.pumpAndSettle();

    // Brand and model render on the card.
    expect(find.text('Rolex'), findsOneWidget);
    expect(find.text('Submariner'), findsOneWidget);
    // The prominent wear-today toggle is offered.
    expect(find.text('Wear today'), findsOneWidget);
    // The add-watch FAB is present.
    expect(
      find.widgetWithText(FloatingActionButton, 'Add watch'),
      findsOneWidget,
    );
  });

  testWidgets('shows an empty state when there are no watches', (tester) async {
    await tester.pumpWidget(_harness(_EmptyRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No watches yet'), findsOneWidget);
  });

  testWidgets('marking a watch worn today updates the card and strip',
      (tester) async {
    await tester.pumpWidget(_harness(_StubWatchRepository()));
    await tester.pumpAndSettle();

    // Not worn yet: the outlined "Wear today" button, no badge/strip.
    expect(find.text('Wear today'), findsOneWidget);
    expect(find.text('Worn today'), findsNothing);

    await tester.tap(find.text('Wear today'));
    await tester.pumpAndSettle();

    // The button flips to "Worn today" (badge + button), and the top strip
    // header appears.
    expect(find.text('Wear today'), findsNothing);
    expect(find.text('Worn today'), findsWidgets);
  });
}

class _EmptyRepository extends InMemoryWatchRepository {
  @override
  Future<List<Watch>> getWatches() async => const [];
}
