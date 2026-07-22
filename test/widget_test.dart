import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
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

void main() {
  testWidgets('renders watches from the repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchRepositoryProvider.overrideWithValue(_StubWatchRepository()),
        ],
        child: const MaterialApp(home: CollectionHomePage()),
      ),
    );

    // Initially the FutureProvider is loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the future resolve.
    await tester.pumpAndSettle();

    expect(find.text('Rolex Submariner'), findsOneWidget);
    // Movement type label is shown in the subtitle.
    expect(find.text('Automatic'), findsOneWidget);
    // The add-watch FAB is present.
    expect(find.widgetWithText(FloatingActionButton, 'Add watch'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no watches', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // A fresh in-memory repo seeds sample data, so override with an
          // empty stub via a repository that returns nothing.
          watchRepositoryProvider.overrideWithValue(_EmptyRepository()),
        ],
        child: const MaterialApp(home: CollectionHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No watches yet'), findsOneWidget);
  });
}

class _EmptyRepository extends InMemoryWatchRepository {
  @override
  Future<List<Watch>> getWatches() async => const [];
}
