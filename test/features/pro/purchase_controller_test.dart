import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/features/pro/data/in_memory_pro_repository.dart';
import 'package:watch_collection/features/pro/domain/purchase_service.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';
import 'package:watch_collection/features/pro/presentation/purchase_controller.dart';

import 'fake_purchase_service.dart';

void main() {
  late FakePurchaseService service;
  late InMemoryProRepository repo;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        purchaseServiceProvider.overrideWithValue(service),
        proRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    // Build the controller eagerly so its async startup (_init) runs during the
    // first pumpEventQueue, before any test action reads state.
    container.read(purchaseControllerProvider);
    return container;
  }

  setUp(() {
    service = FakePurchaseService();
    repo = InMemoryProRepository();
  });

  test('loads the product and store availability on start', () async {
    final container = makeContainer();
    // Initial state is pre-init: loading, not yet available.
    expect(container.read(purchaseControllerProvider).loadingProduct, isTrue);

    await pumpEventQueue();

    final state = container.read(purchaseControllerProvider);
    expect(state.loadingProduct, isFalse);
    expect(state.storeAvailable, isTrue);
    expect(state.product?.price, r'$5.99');
  });

  test('buying Pro persists the entitlement and reaches unlocked', () async {
    final container = makeContainer();
    await pumpEventQueue();

    await container.read(purchaseControllerProvider.notifier).buy();
    await pumpEventQueue();

    expect(service.buyCalled, isTrue);
    expect(
      container.read(purchaseControllerProvider).phase,
      PurchasePhase.unlocked,
    );
    expect(await repo.isProUnlocked(), isTrue);
  });

  test('restoring a purchase persists the entitlement', () async {
    final container = makeContainer();
    await pumpEventQueue();

    await container.read(purchaseControllerProvider.notifier).restore();
    await pumpEventQueue();

    expect(service.restoreCalled, isTrue);
    expect(
      container.read(purchaseControllerProvider).phase,
      PurchasePhase.unlocked,
    );
    expect(await repo.isProUnlocked(), isTrue);
  });

  test('a failed purchase surfaces an error and does not unlock', () async {
    service.autoPurchase = false;
    final container = makeContainer();
    await pumpEventQueue();

    await container.read(purchaseControllerProvider.notifier).buy();
    service.emit(PurchaseOutcome.error, error: 'Card declined');
    await pumpEventQueue();

    final state = container.read(purchaseControllerProvider);
    expect(state.phase, PurchasePhase.error);
    expect(state.message, 'Card declined');
    expect(await repo.isProUnlocked(), isFalse);
  });

  test('a canceled purchase does not unlock', () async {
    service.autoPurchase = false;
    final container = makeContainer();
    await pumpEventQueue();

    await container.read(purchaseControllerProvider.notifier).buy();
    service.emit(PurchaseOutcome.canceled);
    await pumpEventQueue();

    expect(
      container.read(purchaseControllerProvider).phase,
      PurchasePhase.canceled,
    );
    expect(await repo.isProUnlocked(), isFalse);
  });

  test('does not start a buy when the store is unavailable', () async {
    service.available = false;
    final container = makeContainer();
    await pumpEventQueue();

    expect(container.read(purchaseControllerProvider).storeAvailable, isFalse);

    await container.read(purchaseControllerProvider.notifier).buy();
    await pumpEventQueue();

    expect(service.buyCalled, isFalse);
    expect(await repo.isProUnlocked(), isFalse);
  });
}
