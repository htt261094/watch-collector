import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/database/tables.dart';

part 'custom_field_dao.g.dart';

/// Data-access object for the [CustomFields] table (M5 — custom fields).
///
/// Fields are ordered by their manual [CustomFields.sortOrder]; the repository
/// assigns a monotonically increasing order on insert so new fields append to
/// the end of a watch's list.
@DriftAccessor(tables: [CustomFields])
class CustomFieldDao extends DatabaseAccessor<AppDatabase>
    with _$CustomFieldDaoMixin {
  CustomFieldDao(super.db);

  /// All custom fields for [watchId], in display order.
  Future<List<CustomFieldRow>> getFieldsForWatch(String watchId) {
    return (select(customFields)
          ..where((f) => f.watchId.equals(watchId))
          ..orderBy([
            (f) => OrderingTerm(expression: f.sortOrder),
            (f) => OrderingTerm(expression: f.fieldKey),
          ]))
        .get();
  }

  /// The field with the given [id], or null if none exists.
  Future<CustomFieldRow?> getById(String id) {
    return (select(customFields)..where((f) => f.id.equals(id)))
        .getSingleOrNull();
  }

  /// The highest [CustomFields.sortOrder] currently used by [watchId], or null
  /// when the watch has no fields yet.
  Future<int?> maxSortOrder(String watchId) async {
    final max = customFields.sortOrder.max();
    final query = selectOnly(customFields)
      ..addColumns([max])
      ..where(customFields.watchId.equals(watchId));
    final row = await query.getSingleOrNull();
    return row?.read(max);
  }

  Future<void> insertField(CustomFieldsCompanion field) {
    return into(customFields).insert(field);
  }

  /// Sets the name, type, and value of the field with the given [id]. Returns
  /// the number of rows updated.
  Future<int> updateField(
    String id, {
    required String name,
    required String type,
    required String? value,
  }) {
    return (update(customFields)..where((f) => f.id.equals(id))).write(
      CustomFieldsCompanion(
        fieldKey: Value(name),
        fieldType: Value(type),
        fieldValue: Value(value),
      ),
    );
  }

  /// Deletes the field with the given [id]. Returns the number of rows removed.
  Future<int> deleteById(String id) {
    return (delete(customFields)..where((f) => f.id.equals(id))).go();
  }
}
