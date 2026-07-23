import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/data/photo_storage.dart';
import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_record_repository.dart';

/// Local-storage backed [ServiceRecordRepository].
///
/// Coordinates the drift [ServiceRecords] rows with the warranty-card image
/// files owned by [PhotoStorage], so a record's row and its card photo are
/// always created and removed together. Card images are stored under the
/// owning watch's photo folder, keyed by an opaque photo id.
class DriftServiceRecordRepository implements ServiceRecordRepository {
  DriftServiceRecordRepository(this._db, this._storage);

  final AppDatabase _db;
  final PhotoStorage _storage;

  @override
  Future<List<ServiceRecord>> getRecordsForWatch(String watchId) async {
    final rows = await _db.serviceRecordDao.getRecordsForWatch(watchId);
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<ServiceRecord>> getAllRecords() async {
    final rows = await _db.serviceRecordDao.getAllRecords();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<ServiceRecord?> getRecord(String id) async {
    final row = await _db.serviceRecordDao.getById(id);
    return row == null ? null : _toDomain(row);
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

    // Import the card photo (file I/O) before touching the database.
    String? cardPhotoPath;
    if (cardPhotoSourcePath != null && cardPhotoSourcePath.trim().isNotEmpty) {
      cardPhotoPath = await _storage.importPhoto(
        watchId: watchId,
        photoId: IdGenerator.newId(),
        sourcePath: cardPhotoSourcePath,
      );
    }

    await _db.serviceRecordDao.insertRecord(
      ServiceRecordsCompanion.insert(
        id: id,
        watchId: watchId,
        recordType: type.storageKey,
        dueDate: _dayOnly(dueDate),
        note: Value(_clean(note)),
        cardPhotoPath: Value(cardPhotoPath),
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
    final existing = await _db.serviceRecordDao.getById(id);
    if (existing == null) return;

    // Resolve the new photo path (importing any new file first), and note the
    // old file to remove once the row is updated.
    String? newPath = existing.cardPhotoPath;
    String? fileToDelete;
    switch (cardPhoto) {
      case KeepCardPhoto():
        break;
      case SetCardPhoto(:final sourcePath):
        newPath = await _storage.importPhoto(
          watchId: existing.watchId,
          photoId: IdGenerator.newId(),
          sourcePath: sourcePath,
        );
        fileToDelete = existing.cardPhotoPath;
      case ClearCardPhoto():
        newPath = null;
        fileToDelete = existing.cardPhotoPath;
    }

    await _db.serviceRecordDao.updateRecord(
      id,
      ServiceRecordsCompanion(
        recordType: Value(type.storageKey),
        dueDate: Value(_dayOnly(dueDate)),
        note: Value(_clean(note)),
        cardPhotoPath: Value(newPath),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Remove the replaced/cleared file only after the row no longer points at
    // it, and never when the new path resolved to the same file.
    if (fileToDelete != null && fileToDelete != newPath) {
      await _storage.deleteFile(fileToDelete);
    }
  }

  @override
  Future<void> deleteRecord(String id) async {
    final existing = await _db.serviceRecordDao.getById(id);
    if (existing == null) return;
    await _db.serviceRecordDao.deleteById(id);
    final path = existing.cardPhotoPath;
    if (path != null && path.isNotEmpty) {
      await _storage.deleteFile(path);
    }
  }

  static ServiceRecord _toDomain(ServiceRecordRow row) => ServiceRecord(
        id: row.id,
        watchId: row.watchId,
        type: ServiceRecordType.fromStorage(row.recordType),
        dueDate: row.dueDate,
        note: row.note,
        cardPhotoPath: row.cardPhotoPath,
      );

  /// Normalises a due date to midnight so equality/ordering ignore time-of-day.
  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Trims a value and normalises blank text to null ("unset").
  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
