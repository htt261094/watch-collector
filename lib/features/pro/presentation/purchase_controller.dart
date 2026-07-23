import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/pro/domain/purchase_service.dart';
import 'package:watch_collection/features/pro/presentation/pro_providers.dart';

/// High-level phase of the paywall's billing flow, derived from store events.
enum PurchasePhase {
  /// No purchase in progress. If [PurchaseState.storeAvailable] is false the
  /// store cannot be reached and buy/restore are disabled.
  idle,

  /// A buy or restore was started and is awaiting a store outcome.
  pending,

  /// Pro was unlocked (fresh purchase or restore) and persisted. The paywall
  /// should dismiss and let the gated action proceed.
  unlocked,

  /// The last flow failed; [PurchaseState.message] carries the reason.
  error,

  /// The user cancelled the last purchase.
  canceled,
}

/// Immutable view-model for the paywall.
class PurchaseState {
  const PurchaseState({
    this.storeAvailable = false,
    this.loadingProduct = true,
    this.product,
    this.phase = PurchasePhase.idle,
    this.message,
  });

  /// Whether the store is reachable on this device.
  final bool storeAvailable;

  /// True while the product details are being fetched on startup.
  final bool loadingProduct;

  /// The Pro product (title/price), or null if unavailable / not yet loaded.
  final ProProduct? product;

  /// Current flow phase.
  final PurchasePhase phase;

  /// Human-readable message for [PurchasePhase.error].
  final String? message;

  /// Whether a buy/restore is in flight (buttons should be disabled).
  bool get busy => phase == PurchasePhase.pending;

  PurchaseState copyWith({
    bool? storeAvailable,
    bool? loadingProduct,
    ProProduct? product,
    PurchasePhase? phase,
    String? message,
  }) {
    return PurchaseState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      loadingProduct: loadingProduct ?? this.loadingProduct,
      product: product ?? this.product,
      phase: phase ?? this.phase,
      message: message,
    );
  }
}

/// Drives the Pro purchase / restore flow for the paywall (issue #11).
///
/// Wraps a [PurchaseService]: loads the product on start, exposes buy/restore
/// actions, and translates store outcomes into a [PurchaseState]. On a
/// successful purchase or restore it persists the entitlement via
/// [proRepositoryProvider] and invalidates [proUnlockedProvider] so gated
/// surfaces re-evaluate immediately.
class PurchaseController extends Notifier<PurchaseState> {
  StreamSubscription<PurchaseUpdate>? _subscription;

  @override
  PurchaseState build() {
    final service = ref.watch(purchaseServiceProvider);
    _subscription = service.purchaseUpdates.listen(_onUpdate);
    ref.onDispose(() => _subscription?.cancel());
    // Kick off async startup; state updates land as they resolve.
    unawaited(_init(service));
    return const PurchaseState();
  }

  Future<void> _init(PurchaseService service) async {
    final available = await service.isStoreAvailable();
    final product = available ? await service.loadProProduct() : null;
    state = state.copyWith(
      storeAvailable: available,
      loadingProduct: false,
      product: product,
    );
  }

  /// Starts the buy flow. No-op if the store is unavailable, the product failed
  /// to load, or a flow is already in progress.
  Future<void> buy() async {
    final product = state.product;
    if (!state.storeAvailable || product == null || state.busy) return;
    state = state.copyWith(phase: PurchasePhase.pending);
    try {
      await ref.read(purchaseServiceProvider).buyPro(product);
    } catch (error) {
      state = state.copyWith(
        phase: PurchasePhase.error,
        message: 'Could not start the purchase: $error',
      );
    }
  }

  /// Asks the store to restore a previously-owned Pro unlock.
  Future<void> restore() async {
    if (!state.storeAvailable || state.busy) return;
    state = state.copyWith(phase: PurchasePhase.pending);
    try {
      await ref.read(purchaseServiceProvider).restorePurchases();
    } catch (error) {
      state = state.copyWith(
        phase: PurchasePhase.error,
        message: 'Could not restore purchases: $error',
      );
    }
  }

  Future<void> _onUpdate(PurchaseUpdate update) async {
    switch (update.outcome) {
      case PurchaseOutcome.pending:
        state = state.copyWith(phase: PurchasePhase.pending);
      case PurchaseOutcome.purchased:
      case PurchaseOutcome.restored:
        await _grantPro();
        state = state.copyWith(phase: PurchasePhase.unlocked);
      case PurchaseOutcome.error:
        state = state.copyWith(
          phase: PurchasePhase.error,
          message: update.error ?? 'The purchase could not be completed.',
        );
      case PurchaseOutcome.canceled:
        state = state.copyWith(phase: PurchasePhase.canceled);
    }
  }

  /// Persists the entitlement and refreshes gated surfaces.
  Future<void> _grantPro() async {
    await ref.read(proRepositoryProvider).setProUnlocked(true);
    ref.invalidate(proUnlockedProvider);
  }
}
