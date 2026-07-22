/// Abstraction over wear tracking — which watch was worn on which day.
///
/// The Home screen (issue #5) only needs the "worn today" slice: read the set
/// of watches worn on a given day and toggle today's entry. Richer wear-history
/// queries are layered on in M2; this contract stays intentionally small.
///
/// Days are compared at date granularity — the time component of the supplied
/// [DateTime] is ignored by implementations.
abstract interface class WearLogRepository {
  /// Ids of the watches that have a wear log on [day] (date granularity).
  Future<Set<String>> getWatchIdsWornOn(DateTime day);

  /// Records that [watchId] was worn on [day]. A no-op if an entry for that
  /// watch and day already exists, so it is safe to call repeatedly.
  Future<void> logWear(String watchId, DateTime day);

  /// Removes any wear entry for [watchId] on [day]. A no-op if none exists.
  Future<void> removeWear(String watchId, DateTime day);
}
