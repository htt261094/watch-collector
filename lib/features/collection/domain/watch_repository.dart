import 'package:watch_collection/features/collection/domain/watch.dart';

/// Abstraction over the collection data source.
///
/// The domain layer depends only on this contract; concrete implementations
/// (in-memory, local database, etc.) live in the data layer. This keeps the
/// storage choice (offline / local-only) an implementation detail.
abstract interface class WatchRepository {
  /// All watches, most recently created first.
  Future<List<Watch>> getWatches();

  /// Loads a single watch (with its complications) by id, or `null` if absent.
  Future<Watch?> getWatch(String id);

  /// Inserts a new watch or updates the existing one with the same id,
  /// replacing its complications to match [watch].
  Future<void> saveWatch(Watch watch);

  /// Removes a watch and all of its related rows (photos, complications, …).
  Future<void> deleteWatch(String id);
}
