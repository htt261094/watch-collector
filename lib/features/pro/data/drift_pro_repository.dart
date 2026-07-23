import 'package:drift/drift.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/pro/domain/pro_repository.dart';

/// Local-storage backed [ProRepository], reading and writing the
/// `pro_unlocked` flag as a single row in the key/value [Settings] table.
///
/// The value is stored as the string `'true'`/`'false'`; any other (or missing)
/// value reads as not unlocked.
class DriftProRepository implements ProRepository {
  DriftProRepository(this._db);

  final AppDatabase _db;

  /// Settings key under which the Pro entitlement flag is stored.
  static const String _proUnlockedKey = 'pro_unlocked';

  @override
  Future<bool> isProUnlocked() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(_proUnlockedKey)))
        .getSingleOrNull();
    return row?.value == 'true';
  }

  @override
  Future<void> setProUnlocked(bool value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _proUnlockedKey,
            value: Value(value ? 'true' : 'false'),
          ),
        );
  }
}
