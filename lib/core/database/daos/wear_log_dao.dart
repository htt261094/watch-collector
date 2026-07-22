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

  Future<void> insertLog(WearLogsCompanion entry) {
    return into(wearLogs).insert(entry);
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
