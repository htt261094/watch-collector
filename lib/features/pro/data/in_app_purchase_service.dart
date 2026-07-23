import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:watch_collection/features/pro/domain/purchase_service.dart';

/// [PurchaseService] backed by the `in_app_purchase` plugin (Google Play
/// Billing on Android).
///
/// Responsibilities:
///  * query the [proProductId] managed product;
///  * start the non-consumable buy flow and trigger restores;
///  * translate the plugin's [PurchaseDetails] stream into plugin-agnostic
///    [PurchaseUpdate]s for the app;
///  * acknowledge completed purchases so the store does not redeliver them.
///
/// Verification note: the app is offline-first with no backend, so purchases
/// are trusted locally — a `purchased`/`restored` status from the store is
/// taken as proof of entitlement and the `pro_unlocked` flag is persisted by
/// the controller. There is no server-side receipt validation to perform.
class InAppPurchaseService implements PurchaseService {
  InAppPurchaseService([InAppPurchase? iap])
      : _iap = iap ?? InAppPurchase.instance {
    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => _controller.add(
        PurchaseUpdate(PurchaseOutcome.error, error: error.toString()),
      ),
    );
  }

  final InAppPurchase _iap;
  final StreamController<PurchaseUpdate> _controller =
      StreamController<PurchaseUpdate>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  Stream<PurchaseUpdate> get purchaseUpdates => _controller.stream;

  @override
  Future<bool> isStoreAvailable() => _iap.isAvailable();

  @override
  Future<ProProduct?> loadProProduct() async {
    if (!await _iap.isAvailable()) return null;
    final response = await _iap.queryProductDetails({proProductId});
    final details = response.productDetails
        .where((p) => p.id == proProductId)
        .firstOrNull;
    if (details == null) return null;
    return ProProduct(
      id: details.id,
      title: details.title,
      price: details.price,
    );
  }

  @override
  Future<void> buyPro(ProProduct product) async {
    final response = await _iap.queryProductDetails({product.id});
    final details =
        response.productDetails.where((p) => p.id == product.id).firstOrNull;
    if (details == null) {
      _controller.add(
        const PurchaseUpdate(
          PurchaseOutcome.error,
          error: 'Product is not available for purchase.',
        ),
      );
      return;
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// Handles a batch of purchase updates from the plugin. Only [proProductId]
  /// events are surfaced; completed/failed purchases are acknowledged so the
  /// store stops redelivering them.
  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != proProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _controller.add(const PurchaseUpdate(PurchaseOutcome.pending));
        case PurchaseStatus.purchased:
          _controller.add(const PurchaseUpdate(PurchaseOutcome.purchased));
        case PurchaseStatus.restored:
          _controller.add(const PurchaseUpdate(PurchaseOutcome.restored));
        case PurchaseStatus.error:
          _controller.add(
            PurchaseUpdate(
              PurchaseOutcome.error,
              error: purchase.error?.message ?? 'Purchase failed.',
            ),
          );
        case PurchaseStatus.canceled:
          _controller.add(const PurchaseUpdate(PurchaseOutcome.canceled));
      }

      // Acknowledge the transaction so Google Play considers it finished and
      // does not redeliver it on the next stream connection.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
