import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/database/tables.dart';

part 'wear_log_dao.g.dart';

/// Data-access object for the [WearLogs] table.
///
/// Entries are matched at day granularity: callers pass a half-open range
/// `[dayStart, nextDayStart)` so the time component of a stored `wornOn` never
/// affects matching. Keeping the "one entry per watch per day" rule is the
/// repository's job — this DAO only exposes the raw queries.
@DriftAccessor(tables: [WearLogs])
class WearLogDao extends DatabaseAccessor<AppDatabase> with _$WearLogDaoMixin {
  WearLogDao(super.db);

  /// Wear entries whose `wornOn` falls in `[dayStart, dayEnd)`.
  Future<List<WearLogRow>> getLogsForDay(DateTime dayStart, DateTime dayEnd) {
    return (select(wearLogs)
          ..where(
            (l) =>
                l.wornOn.isBiggerOrEqualValue(dayStart) &
                l.wornOn.isSmallerThanValue(dayEnd),
          ))
        .get();
  }

  /// All wear entries for [watchId], most recent day first.
  Future<List<WearLogRow>> getLogsForWatch(String watchId) {
    return (select(wearLogs)
          ..where((l) => l.watchId.equals(watchId))
          ..orderBy([
            (l) => OrderingTerm(expression: l.wornOn, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// All wear entries across every watch, most recent day first.
  Future<List<WearLogRow>> getAllLogs() {
    return (select(wearLogs)
          ..orderBy([
            (l) => OrderingTerm(expression: l.wornOn, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// The entry with the given [id], or null if none exists.
  Future<WearLogRow?> getById(String id) {
    return (select(wearLogs)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertLog(WearLogsCompanion entry) {
    return into(wearLogs).insert(entry);
  }

  /// Sets the `wornOn` and `note` of the entry with the given [id].
  Future<int> updateLog(String id, DateTime wornOn, String? note) {
    return (update(wearLogs)..where((l) => l.id.equals(id))).write(
      WearLogsCompanion(
        wornOn: Value(wornOn),
        note: Value(note),
      ),
    );
  }

  /// Deletes the entry with the given [id]. Returns the number of rows removed.
  Future<int> deleteById(String id) {
    return (delete(wearLogs)..where((l) => l.id.equals(id))).go();
  }

  /// Deletes entries for [watchId] in `[dayStart, dayEnd)` except the row
  /// [exceptId]. Used when moving a record onto a day that may already have one.
  Future<int> deleteLogsForWatchOnDayExcept(
    String watchId,
    DateTime dayStart,
    DateTime dayEnd,
    String exceptId,
  ) {
    return (delete(wearLogs)
          ..where(
            (l) =>
                l.watchId.equals(watchId) &
                l.id.equals(exceptId).not() &
                l.wornOn.isBiggerOrEqualValue(dayStart) &
                l.wornOn.isSmallerThanValue(dayEnd),
          ))
        .go();
  }

  /// Deletes wear entries for [watchId] whose `wornOn` falls in
  /// `[dayStart, dayEnd)`. Returns the number of rows removed.
  Future<int> deleteLogsForWatchOnDay(
    String watchId,
    DateTime dayStart,
    DateTime dayEnd,
  ) {
    return (delete(wearLogs)
          ..where(
            (l) =>
                l.watchId.equals(watchId) &
                l.wornOn.isBiggerOrEqualValue(dayStart) &
                l.wornOn.isSmallerThanValue(dayEnd),
          ))
        .go();
  }
}
