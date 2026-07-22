import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/database/tables.dart';

part 'watch_dao.g.dart';

/// Basic data-access object for the [Watches] table.
///
/// Covers the CRUD surface needed to back a watch repository; richer queries
/// (photos, complications, joins) are layered on in later milestones.
@DriftAccessor(tables: [Watches])
class WatchDao extends DatabaseAccessor<AppDatabase> with _$WatchDaoMixin {
  WatchDao(super.db);

  /// All watches, most recently created first.
  Future<List<WatchRow>> getAllWatches() {
    return (select(watches)
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)]))
        .get();
  }

  /// Reactive version of [getAllWatches] — emits whenever the table changes.
  Stream<List<WatchRow>> watchAllWatches() {
    return (select(watches)
          ..orderBy([(w) => OrderingTerm.desc(w.createdAt)]))
        .watch();
  }

  Future<WatchRow?> getWatchById(String id) {
    return (select(watches)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
  }

  /// Inserts a new watch, or replaces the existing row with the same id.
  Future<void> upsertWatch(WatchesCompanion entry) {
    return into(watches).insertOnConflictUpdate(entry);
  }

  /// Deletes a watch (and, via cascade, all of its related rows).
  /// Returns the number of rows removed.
  Future<int> deleteWatch(String id) {
    return (delete(watches)..where((w) => w.id.equals(id))).go();
  }
}
