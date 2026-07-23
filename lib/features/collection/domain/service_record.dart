import 'package:flutter/foundation.dart';

/// The kind of reminder a [ServiceRecord] represents.
enum ServiceRecordType {
  service('service', 'Service'),
  warranty('warranty', 'Warranty');

  const ServiceRecordType(this.storageKey, this.label);

  /// Stable identifier written to the database `recordType` column.
  final String storageKey;

  /// Human-readable name shown in the type picker and list.
  final String label;

  /// Resolves a stored [storageKey] back to its type, defaulting to [service]
  /// for unknown/legacy values so a bad row can never crash a read.
  static ServiceRecordType fromStorage(String? key) {
    return ServiceRecordType.values.firstWhere(
      (t) => t.storageKey == key,
      orElse: () => ServiceRecordType.service,
    );
  }
}

/// A single service / warranty reminder attached to a watch (M6 — issue #16).
///
/// Immutable value object in the domain layer — the persistence-layer row
/// (`ServiceRecordRow`) is mapped to this by the repository. The reminder
/// notification is scheduled off [dueDate].
@immutable
class ServiceRecord {
  const ServiceRecord({
    required this.id,
    required this.watchId,
    required this.type,
    required this.dueDate,
    this.note,
    this.cardPhotoPath,
  });

  /// Opaque, client-generated identifier.
  final String id;

  /// The watch this reminder belongs to.
  final String watchId;

  /// Whether this reminds about a service due or a warranty expiry.
  final ServiceRecordType type;

  /// The day the service is due / the warranty expires.
  final DateTime dueDate;

  /// Optional free-text note (e.g. "full service at authorised dealer").
  final String? note;

  /// Absolute path to the attached warranty-card photo, or null when none.
  final String? cardPhotoPath;

  /// Whether a warranty-card photo is attached.
  bool get hasCardPhoto =>
      cardPhotoPath != null && cardPhotoPath!.trim().isNotEmpty;

  /// True once [dueDate] is in the past relative to [now] (defaults to today).
  /// Compared by calendar day, so a reminder due today is not yet overdue.
  bool isOverdue([DateTime? now]) {
    final today = _dayOf(now ?? DateTime.now());
    return _dayOf(dueDate).isBefore(today);
  }

  /// ISO-8601 date string (`yyyy-MM-dd`) of [dueDate], for display.
  String get formattedDueDate => formatDate(dueDate);

  /// ISO-8601 date string (`yyyy-MM-dd`).
  static String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  bool operator ==(Object other) =>
      other is ServiceRecord &&
      other.id == id &&
      other.watchId == watchId &&
      other.type == type &&
      other.dueDate == dueDate &&
      other.note == note &&
      other.cardPhotoPath == cardPhotoPath;

  @override
  int get hashCode =>
      Object.hash(id, watchId, type, dueDate, note, cardPhotoPath);

  @override
  String toString() =>
      'ServiceRecord(id: $id, watchId: $watchId, type: ${type.storageKey}, '
      'dueDate: $dueDate, note: $note, cardPhotoPath: $cardPhotoPath)';
}
