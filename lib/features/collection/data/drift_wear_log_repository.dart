import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';

/// Local-storage backed [WearLogRepository], reading and writing through the
/// drift [AppDatabase].
///
/// Wear entries are stored with `wornOn` normalised to midnight of the day, and
/// matched against the half-open range `[dayStart, nextDayStart)` so lookups are
/// robust regardless of the time component that ever ends up in the column.
class DriftWearLogRepository implements WearLogRepository {
  DriftWearLogRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Set<String>> getWatchIdsWornOn(DateTime day) async {
    final start = _dayStart(day);
    final rows = await _db.wearLogDao.getLogsForDay(start, _nextDay(start));
    return rows.map((r) => r.watchId).toSet();
  }

  @override
  Future<void> logWear(String watchId, DateTime day) async {
    final start = _dayStart(day);
    // Enforce one entry per watch per day: clear any existing entry first so
    // repeated calls stay idempotent.
    await _db.wearLogDao
        .deleteLogsForWatchOnDay(watchId, start, _nextDay(start));
    await _db.wearLogDao.insertLog(
      WearLogsCompanion.insert(
        id: IdGenerator.newId(),
        watchId: watchId,
        wornOn: start,
      ),
    );
  }

  @override
  Future<void> removeWear(String watchId, DateTime day) async {
    final start = _dayStart(day);
    await _db.wearLogDao
        .deleteLogsForWatchOnDay(watchId, start, _nextDay(start));
  }

  /// Midnight (local) of the given day.
  static DateTime _dayStart(DateTime day) => DateTime(day.year, day.month, day.day);

  /// Midnight (local) of the day after [start]. Using [DateTime] arithmetic via
  /// the constructor keeps it correct across DST boundaries.
  static DateTime _nextDay(DateTime start) =>
      DateTime(start.year, start.month, start.day + 1);
}
