import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';

/// The app-wide drift database. Disposed with the provider scope so the
/// underlying connection is closed cleanly.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provides the repository implementation to the rest of the app.
///
/// Backed by local storage ([DriftWatchRepository]). Kept as a plain [Provider]
/// so it can be overridden in tests without touching the presentation layer.
final watchRepositoryProvider = Provider<WatchRepository>((ref) {
  return DriftWatchRepository(ref.watch(appDatabaseProvider));
});

/// Loads the list of watches from the repository. Invalidated after a
/// save/delete so the list reflects the latest data.
final watchListProvider = FutureProvider<List<Watch>>((ref) async {
  final repository = ref.watch(watchRepositoryProvider);
  return repository.getWatches();
});

/// Loads a single watch by id — used to pre-fill the form in edit mode.
final watchByIdProvider =
    FutureProvider.family<Watch?, String>((ref, id) async {
  final repository = ref.watch(watchRepositoryProvider);
  return repository.getWatch(id);
});
