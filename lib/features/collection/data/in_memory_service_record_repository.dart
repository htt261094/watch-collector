import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_record_repository.dart';

/// In-memory [ServiceRecordRepository], handy for tests, previews, and running
/// the app without a real database.
///
/// State lives only for the lifetime of the instance. Card photos are not
/// copied anywhere — the provided source path is stored verbatim, which is
/// enough to exercise the "has a photo" behaviour.
class InMemoryServiceRecordRepository implements ServiceRecordRepository {
  final List<ServiceRecord> _records = [];

  @override
  Future<List<ServiceRecord>> getRecordsForWatch(String watchId) async {
    final list = _records.where((r) => r.watchId == watchId).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  @override
  Future<List<ServiceRecord>> getAllRecords() async {
    return _records.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Future<ServiceRecord?> getRecord(String id) async {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<String> addRecord(
    String watchId, {
    required ServiceRecordType type,
    required DateTime dueDate,
    String? note,
    String? cardPhotoSourcePath,
  }) async {
    final id = IdGenerator.newId();
    _records.add(
      ServiceRecord(
        id: id,
        watchId: watchId,
        type: type,
        dueDate: _dayOnly(dueDate),
        note: _clean(note),
        cardPhotoPath: _clean(cardPhotoSourcePath),
      ),
    );
    return id;
  }

  @override
  Future<void> updateRecord(
    String id, {
    required ServiceRecordType type,
    required DateTime dueDate,
    String? note,
    CardPhotoChange cardPhoto = const CardPhotoChange.keep(),
  }) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index < 0) return;
    final existing = _records[index];

    final String? newPath = switch (cardPhoto) {
      KeepCardPhoto() => existing.cardPhotoPath,
      SetCardPhoto(:final sourcePath) => _clean(sourcePath),
      ClearCardPhoto() => null,
    };

    _records[index] = ServiceRecord(
      id: existing.id,
      watchId: existing.watchId,
      type: type,
      dueDate: _dayOnly(dueDate),
      note: _clean(note),
      cardPhotoPath: newPath,
    );
  }

  @override
  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
