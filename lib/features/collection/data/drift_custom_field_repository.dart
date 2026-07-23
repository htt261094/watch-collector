import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/domain/custom_field.dart';
import 'package:watch_collection/features/collection/domain/custom_field_repository.dart';

/// Local-storage backed [CustomFieldRepository], reading and writing through the
/// drift [AppDatabase].
class DriftCustomFieldRepository implements CustomFieldRepository {
  DriftCustomFieldRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<CustomField>> getFieldsForWatch(String watchId) async {
    final rows = await _db.customFieldDao.getFieldsForWatch(watchId);
    return rows.map(_toField).toList();
  }

  @override
  Future<String> addField(
    String watchId, {
    required String name,
    required CustomFieldType type,
    String? value,
  }) async {
    final id = IdGenerator.newId();
    // Append after the current last field so ordering stays stable.
    final maxOrder = await _db.customFieldDao.maxSortOrder(watchId);
    await _db.customFieldDao.insertField(
      CustomFieldsCompanion.insert(
        id: id,
        watchId: watchId,
        fieldKey: name.trim(),
        fieldType: Value(type.storageKey),
        fieldValue: Value(_clean(value)),
        sortOrder: Value((maxOrder ?? -1) + 1),
      ),
    );
    return id;
  }

  @override
  Future<void> updateField(
    String id, {
    required String name,
    required CustomFieldType type,
    String? value,
  }) async {
    await _db.customFieldDao.updateField(
      id,
      name: name.trim(),
      type: type.storageKey,
      value: _clean(value),
    );
  }

  @override
  Future<void> deleteField(String id) async {
    await _db.customFieldDao.deleteById(id);
  }

  static CustomField _toField(CustomFieldRow row) => CustomField(
        id: row.id,
        watchId: row.watchId,
        name: row.fieldKey,
        type: CustomFieldType.fromStorage(row.fieldType),
        value: row.fieldValue,
        sortOrder: row.sortOrder,
      );

  /// Trims a value and normalises blank text to null ("unset").
  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
