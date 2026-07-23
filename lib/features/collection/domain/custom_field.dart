import 'package:flutter/foundation.dart';

/// The value kind a [CustomField] holds. Every value is persisted as text; the
/// type only governs how the value is entered, validated, and displayed.
enum CustomFieldType {
  text('text', 'Text'),
  number('number', 'Number'),
  date('date', 'Date');

  const CustomFieldType(this.storageKey, this.label);

  /// Stable identifier written to the database `fieldType` column.
  final String storageKey;

  /// Human-readable name shown in the type picker.
  final String label;

  /// Resolves a stored [storageKey] back to its type, defaulting to [text] for
  /// unknown/legacy values so a bad row can never crash a read.
  static CustomFieldType fromStorage(String? key) {
    return CustomFieldType.values.firstWhere(
      (t) => t.storageKey == key,
      orElse: () => CustomFieldType.text,
    );
  }
}

/// A user-defined attribute attached to a single watch (M5 — custom fields).
///
/// Plain, immutable value object in the domain layer — the persistence-layer
/// row (`CustomFieldRow`) is mapped to this by the repository. The [value] is
/// stored verbatim as text; [displayValue] renders it according to [type].
@immutable
class CustomField {
  const CustomField({
    required this.id,
    required this.watchId,
    required this.name,
    required this.type,
    this.value,
    this.sortOrder = 0,
  });

  /// Opaque, client-generated identifier.
  final String id;

  /// The watch this field belongs to.
  final String watchId;

  /// The user-chosen label for the field (e.g. "Strap", "Water resistance").
  final String name;

  /// How [value] should be interpreted and rendered.
  final CustomFieldType type;

  /// The stored value, as raw text. Dates are stored ISO-8601 (`yyyy-MM-dd`);
  /// numbers as their canonical string. Null/empty means "unset".
  final String? value;

  /// Manual ordering within a watch's set of custom fields.
  final int sortOrder;

  /// Whether the field carries a value worth displaying.
  bool get hasValue => value != null && value!.trim().isNotEmpty;

  /// The value formatted for display according to [type]. Falls back to the raw
  /// value when it cannot be parsed, so nothing ever silently disappears.
  String get displayValue {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '';
    switch (type) {
      case CustomFieldType.date:
        final parsed = DateTime.tryParse(raw);
        return parsed == null ? raw : formatDate(parsed);
      case CustomFieldType.number:
      case CustomFieldType.text:
        return raw;
    }
  }

  /// The value parsed as a [DateTime], or null if not a [CustomFieldType.date]
  /// field or unparseable. Handy for pre-filling a date picker when editing.
  DateTime? get dateValue {
    if (type != CustomFieldType.date) return null;
    final raw = value?.trim();
    return (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
  }

  /// ISO-8601 date string (`yyyy-MM-dd`) used for storing date values.
  static String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  bool operator ==(Object other) =>
      other is CustomField &&
      other.id == id &&
      other.watchId == watchId &&
      other.name == name &&
      other.type == type &&
      other.value == value &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, watchId, name, type, value, sortOrder);

  @override
  String toString() =>
      'CustomField(id: $id, watchId: $watchId, name: $name, '
      'type: ${type.storageKey}, value: $value, sortOrder: $sortOrder)';
}
