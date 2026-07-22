import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/presentation/collection_home_page.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';

class _FakeWatchRepository implements WatchRepository {
  @override
  Future<List<Watch>> getWatches() async {
    return const [
      Watch(
        id: '1',
        brand: 'Rolex',
        model: 'Submariner',
        movement: 'Automatic',
      ),
    ];
  }
}

void main() {
  testWidgets('renders watches from the repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchRepositoryProvider.overrideWithValue(_FakeWatchRepository()),
        ],
        child: const MaterialApp(home: CollectionHomePage()),
      ),
    );

    // Initially the FutureProvider is loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the future resolve.
    await tester.pumpAndSettle();

    expect(find.text('Rolex Submariner'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
  });
}
