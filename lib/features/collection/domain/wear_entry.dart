import 'package:flutter/foundation.dart';

/// A single wear record: a watch worn on a particular day, with an optional
/// note.
///
/// Plain, immutable value object in the domain layer — the persistence-layer
/// row (`WearLogRow`) is mapped to this by the repository. Days carry date
/// granularity only; the time component of [wornOn] is not significant.
@immutable
class WearEntry {
  const WearEntry({
    required this.id,
    required this.watchId,
    required this.wornOn,
    this.note,
  });

  /// Opaque, client-generated identifier.
  final String id;

  /// The watch this record belongs to.
  final String watchId;

  /// The day the watch was worn (time component not significant).
  final DateTime wornOn;

  /// Optional free-text note attached to the wear.
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is WearEntry &&
      other.id == id &&
      other.watchId == watchId &&
      other.wornOn == wornOn &&
      other.note == note;

  @override
  int get hashCode => Object.hash(id, watchId, wornOn, note);

  @override
  String toString() =>
      'WearEntry(id: $id, watchId: $watchId, wornOn: $wornOn, note: $note)';
}
