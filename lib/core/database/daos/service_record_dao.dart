import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/database/tables.dart';

part 'service_record_dao.g.dart';

/// Data-access object for the [ServiceRecords] table (M6 — issue #16).
///
/// Records are ordered by their [ServiceRecords.dueDate] so the soonest-due
/// reminder shows first on the Service tab.
@DriftAccessor(tables: [ServiceRecords])
class ServiceRecordDao extends DatabaseAccessor<AppDatabase>
    with _$ServiceRecordDaoMixin {
  ServiceRecordDao(super.db);

  /// All service records for [watchId], soonest due first.
  Future<List<ServiceRecordRow>> getRecordsForWatch(String watchId) {
    return (select(serviceRecords)
          ..where((r) => r.watchId.equals(watchId))
          ..orderBy([(r) => OrderingTerm(expression: r.dueDate)]))
        .get();
  }

  /// Every service record across the whole collection, soonest due first — used
  /// to (re)schedule reminder notifications on app start.
  Future<List<ServiceRecordRow>> getAllRecords() {
    return (select(serviceRecords)
          ..orderBy([(r) => OrderingTerm(expression: r.dueDate)]))
        .get();
  }

  /// The record with the given [id], or null if none exists.
  Future<ServiceRecordRow?> getById(String id) {
    return (select(serviceRecords)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertRecord(ServiceRecordsCompanion record) {
    return into(serviceRecords).insert(record);
  }

  /// Overwrites the editable columns of the record with the given [id]. Returns
  /// the number of rows updated.
  Future<int> updateRecord(String id, ServiceRecordsCompanion record) {
    return (update(serviceRecords)..where((r) => r.id.equals(id))).write(record);
  }

  /// Deletes the record with the given [id]. Returns the number of rows removed.
  Future<int> deleteById(String id) {
    return (delete(serviceRecords)..where((r) => r.id.equals(id))).go();
  }
}
