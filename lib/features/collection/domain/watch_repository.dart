import 'package:watch_collection/features/collection/domain/watch.dart';

/// Abstraction over the collection data source.
///
/// The domain layer depends only on this contract; concrete implementations
/// (in-memory, local database, etc.) live in the data layer. This keeps the
/// storage choice (offline / local-only) an implementation detail.
abstract interface class WatchRepository {
  Future<List<Watch>> getWatches();
}
