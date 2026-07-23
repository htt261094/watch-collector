import 'package:watch_collection/features/collection/domain/custom_field.dart';

/// Abstraction over per-watch custom fields — arbitrary user-defined attributes
/// (name + typed value) attached to a watch (M5).
///
/// New fields are appended to the end of a watch's list; ordering is stable so
/// the Watch Detail screen renders them in the order they were added.
abstract interface class CustomFieldRepository {
  /// All custom fields for [watchId], in display order.
  Future<List<CustomField>> getFieldsForWatch(String watchId);

  /// Adds a new field to [watchId] and returns its generated id. [name] is
  /// trimmed; [value] is stored verbatim (null/empty means "unset").
  Future<String> addField(
    String watchId, {
    required String name,
    required CustomFieldType type,
    String? value,
  });

  /// Updates the field [id] with a new [name], [type], and [value]. A no-op if
  /// no field with that id exists.
  Future<void> updateField(
    String id, {
    required String name,
    required CustomFieldType type,
    String? value,
  });

  /// Deletes the field with the given [id]. A no-op if none exists.
  Future<void> deleteField(String id);
}
