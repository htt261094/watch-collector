import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/pro/data/drift_pro_repository.dart';
import 'package:watch_collection/features/pro/data/in_app_purchase_service.dart';
import 'package:watch_collection/features/pro/domain/pro_repository.dart';
import 'package:watch_collection/features/pro/domain/purchase_service.dart';
import 'package:watch_collection/features/pro/presentation/purchase_controller.dart';

/// Provides the Pro-entitlement repository. Backed by local storage
/// ([DriftProRepository]); overridable in tests.
final proRepositoryProvider = Provider<ProRepository>((ref) {
  return DriftProRepository(ref.watch(appDatabaseProvider));
});

/// The current `pro_unlocked` flag. Invalidated after an unlock so gated
/// surfaces re-evaluate immediately.
final proUnlockedProvider = FutureProvider<bool>((ref) async {
  return ref.watch(proRepositoryProvider).isProUnlocked();
});

/// Store billing client (Google Play Billing). Backed by [InAppPurchaseService];
/// overridden with a fake in tests. Disposed with the provider scope so the
/// underlying purchase-stream subscription is released.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = InAppPurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

/// Drives the paywall's purchase / restore flow and persists the entitlement.
final purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);
