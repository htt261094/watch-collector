import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/presentation/collection_providers.dart';
import 'package:watch_collection/features/pro/data/drift_pro_repository.dart';
import 'package:watch_collection/features/pro/domain/pro_repository.dart';

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
