/// Google Play product identifier for the one-time "Pro unlock" (issue #11).
///
/// A single **non-consumable** managed product: bought once, owned forever, and
/// restorable on a new device. Must match the product ID configured in the
/// Play Console.
const String proProductId = 'pro_unlock';

/// A store product available for purchase, mapped from the platform SDK into a
/// plugin-agnostic value so the rest of the app never imports `in_app_purchase`.
class ProProduct {
  const ProProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  /// Store product identifier (see [proProductId]).
  final String id;

  /// Localised product title from the store listing.
  final String title;

  /// Localised, currency-formatted price string (e.g. `"$5.99"`), ready to
  /// display. Formatting and currency come from the store, not the app.
  final String price;
}

/// Lifecycle of a purchase or restore, as reported by the store.
///
/// Mirrors the subset of the platform's purchase states the app acts on.
enum PurchaseOutcome {
  /// The purchase is awaiting completion (e.g. pending parental approval or a
  /// slow payment method). The user should be told it is in progress.
  pending,

  /// A fresh purchase completed successfully — deliver the entitlement.
  purchased,

  /// A previously-owned purchase was restored — deliver the entitlement.
  restored,

  /// The purchase failed. [PurchaseUpdate.error] carries the reason.
  error,

  /// The user cancelled the purchase before it completed.
  canceled,
}

/// A single purchase-stream event for [proProductId], mapped from the SDK.
class PurchaseUpdate {
  const PurchaseUpdate(this.outcome, {this.error});

  final PurchaseOutcome outcome;

  /// Human-readable failure reason when [outcome] is [PurchaseOutcome.error].
  final String? error;
}

/// Abstraction over the store billing client (Google Play Billing via the
/// `in_app_purchase` plugin).
///
/// Kept plugin-agnostic so the presentation layer and its tests depend only on
/// this interface; the concrete SDK wiring lives in the data layer
/// ([InAppPurchaseService]) and an in-memory fake stands in for tests.
///
/// Purchase and restore results are asynchronous: [buyPro]/[restorePurchases]
/// only *start* the flow, and outcomes arrive on [purchaseUpdates]. Listen to
/// the stream before starting a flow.
abstract interface class PurchaseService {
  /// Whether the underlying store is available on this device (e.g. Play
  /// Services present and the user signed in). When `false`, purchasing and
  /// restoring are not possible.
  Future<bool> isStoreAvailable();

  /// Loads the [proProductId] product from the store, or `null` if the store is
  /// unavailable or the product is not configured / not found.
  Future<ProProduct?> loadProProduct();

  /// Broadcast stream of purchase/restore outcomes for [proProductId]. The
  /// implementation is responsible for acknowledging completed purchases with
  /// the store so they are not redelivered.
  Stream<PurchaseUpdate> get purchaseUpdates;

  /// Starts the buy flow for the non-consumable Pro product. The outcome
  /// arrives on [purchaseUpdates].
  Future<void> buyPro(ProProduct product);

  /// Asks the store to redeliver previously-owned purchases. Restored
  /// entitlements arrive on [purchaseUpdates] with [PurchaseOutcome.restored].
  Future<void> restorePurchases();

  /// Releases any resources (stream subscriptions) held by the service.
  void dispose();
}
