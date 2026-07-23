import 'package:watch_collection/features/collection/domain/wear_entry.dart';

/// Abstraction over wear tracking — which watch was worn on which day.
///
/// The Home screen (issue #5) only needs the "worn today" slice: read the set
/// of watches worn on a given day and toggle today's entry. The wear-history
/// views (issue #8) layer richer queries on top: the full log for one watch,
/// the log across the whole collection, and editing/deleting individual
/// records.
///
/// Days are compared at date granularity — the time component of any supplied
/// [DateTime] is ignored by implementations.
abstract interface class WearLogRepository {
  /// Ids of the watches that have a wear log on [day] (date granularity).
  Future<Set<String>> getWatchIdsWornOn(DateTime day);

  /// Records that [watchId] was worn on [day]. A no-op if an entry for that
  /// watch and day already exists, so it is safe to call repeatedly.
  Future<void> logWear(String watchId, DateTime day);

  /// Removes any wear entry for [watchId] on [day]. A no-op if none exists.
  Future<void> removeWear(String watchId, DateTime day);

  /// All wear records for [watchId], most recent day first.
  Future<List<WearEntry>> getEntriesForWatch(String watchId);

  /// All wear records across the whole collection, most recent day first.
  Future<List<WearEntry>> getAllEntries();

  /// Updates the record [id] to fall on [wornOn] (date granularity) with the
  /// given [note]. To keep the "one entry per watch per day" rule, any other
  /// record for the same watch on the target day is removed first.
  Future<void> updateEntry(String id, {required DateTime wornOn, String? note});

  /// Deletes the wear record with the given [id]. A no-op if none exists.
  Future<void> deleteEntry(String id);
}
