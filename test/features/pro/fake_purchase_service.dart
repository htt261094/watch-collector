import 'dart:async';

import 'package:watch_collection/features/pro/domain/purchase_service.dart';

/// In-memory [PurchaseService] for tests. Records calls and lets a test drive
/// purchase outcomes, either automatically on [buyPro]/[restorePurchases] or
/// manually via [emit].
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({
    this.available = true,
    this.product = const ProProduct(
      id: proProductId,
      title: 'Pro unlock',
      price: r'$5.99',
    ),
    this.autoPurchase = true,
    this.autoRestore = true,
  });

  /// Whether the store reports itself available.
  bool available;

  /// Product returned by [loadProProduct] (null when unavailable).
  ProProduct? product;

  /// When true, [buyPro] immediately emits a `purchased` outcome.
  bool autoPurchase;

  /// When true, [restorePurchases] immediately emits a `restored` outcome.
  bool autoRestore;

  bool buyCalled = false;
  bool restoreCalled = false;

  final StreamController<PurchaseUpdate> _controller =
      StreamController<PurchaseUpdate>.broadcast();

  @override
  Future<bool> isStoreAvailable() async => available;

  @override
  Future<ProProduct?> loadProProduct() async => available ? product : null;

  @override
  Stream<PurchaseUpdate> get purchaseUpdates => _controller.stream;

  @override
  Future<void> buyPro(ProProduct product) async {
    buyCalled = true;
    if (autoPurchase) emit(PurchaseOutcome.purchased);
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalled = true;
    if (autoRestore) emit(PurchaseOutcome.restored);
  }

  /// Pushes an outcome onto the purchase stream, as the store would.
  void emit(PurchaseOutcome outcome, {String? error}) {
    _controller.add(PurchaseUpdate(outcome, error: error));
  }

  @override
  void dispose() => _controller.close();
}
