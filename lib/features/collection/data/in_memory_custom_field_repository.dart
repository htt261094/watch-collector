import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/domain/custom_field.dart';
import 'package:watch_collection/features/collection/domain/custom_field_repository.dart';

/// In-memory [CustomFieldRepository], handy for tests, previews, and running the
/// app without a real database.
///
/// State lives only for the lifetime of the instance and mirrors the drift
/// implementation's semantics (fields appended in insertion order).
class InMemoryCustomFieldRepository implements CustomFieldRepository {
  final List<CustomField> _fields = [];

  @override
  Future<List<CustomField>> getFieldsForWatch(String watchId) async {
    final list = _fields.where((f) => f.watchId == watchId).toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
    return list;
  }

  @override
  Future<String> addField(
    String watchId, {
    required String name,
    required CustomFieldType type,
    String? value,
  }) async {
    final id = IdGenerator.newId();
    final maxOrder = _fields
        .where((f) => f.watchId == watchId)
        .fold<int>(-1, (m, f) => f.sortOrder > m ? f.sortOrder : m);
    _fields.add(
      CustomField(
        id: id,
        watchId: watchId,
        name: name.trim(),
        type: type,
        value: _clean(value),
        sortOrder: maxOrder + 1,
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
    final index = _fields.indexWhere((f) => f.id == id);
    if (index < 0) return;
    final existing = _fields[index];
    _fields[index] = CustomField(
      id: existing.id,
      watchId: existing.watchId,
      name: name.trim(),
      type: type,
      value: _clean(value),
      sortOrder: existing.sortOrder,
    );
  }

  @override
  Future<void> deleteField(String id) async {
    _fields.removeWhere((f) => f.id == id);
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
