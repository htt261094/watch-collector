import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_photo_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/data/in_memory_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/presentation/collection_home_page.dart';
import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/pro/data/in_memory_pro_repository.dart';
import 'package:watch_collection/features/pro/domain/pro_repository.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

import 'fake_purchase_service.dart';

/// A repository returning a fixed set of watches, so the gate sees a known
/// collection size.
class _FixedRepository extends InMemoryWatchRepository {
  _FixedRepository(this.watches);

  final List<Watch> watches;

  @override
  Future<List<Watch>> getWatches() async => List.unmodifiable(watches);
}

List<Watch> _watches(int count) => [
      for (var i = 0; i < count; i++)
        Watch(
          id: '$i',
          brand: 'Brand $i',
          model: 'Model $i',
          movementType: MovementType.auto,
        ),
    ];

Widget _wrap({required int watchCount, required bool proUnlocked}) {
  return ProviderScope(
    overrides: [
      watchRepositoryProvider
          .overrideWithValue(_FixedRepository(_watches(watchCount))),
      watchPhotoRepositoryProvider
          .overrideWithValue(InMemoryWatchPhotoRepository()),
      wearLogRepositoryProvider.overrideWithValue(InMemoryWearLogRepository()),
      proRepositoryProvider.overrideWithValue(
        InMemoryProRepository(proUnlocked: proUnlocked),
      ),
      purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
    ],
    child: const MaterialApp(home: CollectionHomePage()),
  );
}

void main() {
  Future<void> tapAdd(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add watch'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens the paywall when a free user is at the limit',
      (tester) async {
    await tester.pumpWidget(
      _wrap(watchCount: freeWatchLimit, proUnlocked: false),
    );
    await tapAdd(tester);

    // Paywall is shown; the Add form is not.
    expect(find.text('Upgrade to Pro'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Brand *'), findsNothing);
  });

  testWidgets('opens the Add form when a free user is below the limit',
      (tester) async {
    await tester.pumpWidget(
      _wrap(watchCount: freeWatchLimit - 1, proUnlocked: false),
    );
    await tapAdd(tester);

    expect(find.widgetWithText(TextFormField, 'Brand *'), findsOneWidget);
    expect(find.text('Upgrade to Pro'), findsNothing);
  });

  testWidgets('opens the Add form for a Pro user past the limit',
      (tester) async {
    await tester.pumpWidget(
      _wrap(watchCount: freeWatchLimit + 2, proUnlocked: true),
    );
    await tapAdd(tester);

    expect(find.widgetWithText(TextFormField, 'Brand *'), findsOneWidget);
    expect(find.text('Upgrade to Pro'), findsNothing);
  });

  testWidgets('unlocking Pro from the paywall proceeds to the Add form',
      (tester) async {
    await tester.pumpWidget(
      _wrap(watchCount: freeWatchLimit, proUnlocked: false),
    );
    await tapAdd(tester);
    expect(find.text('Upgrade to Pro'), findsOneWidget);

    // The unlock button carries the store-formatted price.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Paywall popped, Add form opened.
    expect(find.widgetWithText(TextFormField, 'Brand *'), findsOneWidget);
  });
}
