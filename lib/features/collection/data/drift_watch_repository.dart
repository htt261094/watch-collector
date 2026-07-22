import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';

/// Local-storage backed [WatchRepository] implementation, reading through the
/// drift [AppDatabase]. It maps persistence rows ([WatchRow]) onto the pure
/// domain [Watch] entity so the rest of the app stays unaware of drift.
///
/// This will supersede `InMemoryWatchRepository` as the wired-up
/// implementation once CRUD (issue #3) lands.
class DriftWatchRepository implements WatchRepository {
  DriftWatchRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Watch>> getWatches() async {
    final rows = await _db.watchDao.getAllWatches();
    return rows.map(_toDomain).toList();
  }

  Watch _toDomain(WatchRow row) {
    return Watch(
      id: row.id,
      brand: row.brand,
      model: row.model,
      movement: row.movementType,
    );
  }
}
