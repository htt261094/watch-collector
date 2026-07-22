import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';

/// In-memory [WearLogRepository], handy for tests, previews, and running the
/// app without a real database.
///
/// State lives only for the lifetime of the instance. Entries are keyed by
/// day (date granularity) so it mirrors the drift implementation's semantics.
class InMemoryWearLogRepository implements WearLogRepository {
  /// Day (midnight) -> set of watch ids worn that day.
  final Map<DateTime, Set<String>> _byDay = {};

  @override
  Future<Set<String>> getWatchIdsWornOn(DateTime day) async {
    return Set.unmodifiable(_byDay[_dayKey(day)] ?? const <String>{});
  }

  @override
  Future<void> logWear(String watchId, DateTime day) async {
    (_byDay[_dayKey(day)] ??= <String>{}).add(watchId);
  }

  @override
  Future<void> removeWear(String watchId, DateTime day) async {
    _byDay[_dayKey(day)]?.remove(watchId);
  }

  static DateTime _dayKey(DateTime day) =>
      DateTime(day.year, day.month, day.day);
}
