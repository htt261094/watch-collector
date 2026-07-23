import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/domain/wear_entry.dart';
import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';

/// In-memory [WearLogRepository], handy for tests, previews, and running the
/// app without a real database.
///
/// State lives only for the lifetime of the instance. Entries are stored as a
/// flat list of [WearEntry] with `wornOn` normalised to midnight, mirroring the
/// drift implementation's semantics (one entry per watch per day).
class InMemoryWearLogRepository implements WearLogRepository {
  final List<WearEntry> _entries = [];

  @override
  Future<Set<String>> getWatchIdsWornOn(DateTime day) async {
    final key = _dayKey(day);
    return {
      for (final e in _entries)
        if (e.wornOn == key) e.watchId,
    };
  }

  @override
  Future<void> logWear(String watchId, DateTime day) async {
    final key = _dayKey(day);
    _entries.removeWhere((e) => e.watchId == watchId && e.wornOn == key);
    _entries.add(
      WearEntry(id: IdGenerator.newId(), watchId: watchId, wornOn: key),
    );
  }

  @override
  Future<void> removeWear(String watchId, DateTime day) async {
    final key = _dayKey(day);
    _entries.removeWhere((e) => e.watchId == watchId && e.wornOn == key);
  }

  @override
  Future<List<WearEntry>> getEntriesForWatch(String watchId) async {
    final list = _entries.where((e) => e.watchId == watchId).toList()
      ..sort((a, b) => b.wornOn.compareTo(a.wornOn));
    return list;
  }

  @override
  Future<List<WearEntry>> getAllEntries() async {
    final list = List<WearEntry>.of(_entries)
      ..sort((a, b) => b.wornOn.compareTo(a.wornOn));
    return list;
  }

  @override
  Future<void> updateEntry(
    String id, {
    required DateTime wornOn,
    String? note,
  }) async {
    final key = _dayKey(wornOn);
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final existing = _entries[index];
    // Keep one entry per watch per day.
    _entries.removeWhere(
      (e) => e.id != id && e.watchId == existing.watchId && e.wornOn == key,
    );
    final trimmed = note?.trim();
    _entries[_entries.indexWhere((e) => e.id == id)] = WearEntry(
      id: existing.id,
      watchId: existing.watchId,
      wornOn: key,
      note: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  static DateTime _dayKey(DateTime day) =>
      DateTime(day.year, day.month, day.day);
}
