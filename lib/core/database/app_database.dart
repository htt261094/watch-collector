import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/connection.dart' as conn;
import 'package:watch_collection/core/database/daos/custom_field_dao.dart';
import 'package:watch_collection/core/database/daos/service_record_dao.dart';
import 'package:watch_collection/core/database/daos/watch_dao.dart';
import 'package:watch_collection/core/database/daos/watch_photo_dao.dart';
import 'package:watch_collection/core/database/daos/wear_log_dao.dart';
import 'package:watch_collection/core/database/tables.dart';

part 'app_database.g.dart';

/// The application's local SQLite database.
///
/// All persistence for the (fully offline, no-backend) app flows through this
/// single drift database. Tables are declared in `tables.dart`; data access is
/// grouped into DAOs under `daos/`.
@DriftDatabase(
  tables: [
    Watches,
    WatchPhotos,
    Complications,
    WearLogs,
    AccuracyMeasurements,
    CustomFields,
    ServiceRecords,
    Settings,
  ],
  daos: [
    WatchDao,
    WatchPhotoDao,
    WearLogDao,
    CustomFieldDao,
    ServiceRecordDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database (production use).
  AppDatabase() : super(conn.openConnection());

  /// Builds a database over the given executor — used by tests to inject an
  /// in-memory (`NativeDatabase.memory()`) executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // v2 (M5): custom fields gained a `fieldType` column describing how the
        // stored value is entered/displayed. Existing rows default to `text`.
        if (from < 2) {
          await m.addColumn(customFields, customFields.fieldType);
        }
        // v3 (M6): the service_records table was reshaped for the service &
        // warranty reminder feature (issue #16). The previous shape was only
        // ever scaffolded — never written to by any DAO — so it is safe to drop
        // and recreate it rather than migrate column-by-column.
        if (from < 3) {
          await m.deleteTable(serviceRecords.actualTableName);
          await m.createTable(serviceRecords);
        }
      },
      beforeOpen: (details) async {
        // SQLite disables foreign keys per-connection by default; the cascade
        // deletes declared in the schema rely on this being on.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
