import 'package:flutter/foundation.dart';

/// A single photo belonging to a watch.
///
/// The binary never lives in the database — [filePath] points at a file inside
/// the app's storage directory (see `PhotoStorage`). Exactly one photo per
/// watch may have [isThumbnail] set; it is the representative image shown on
/// the collection list. [sortOrder] gives the gallery a stable manual order.
@immutable
class WatchPhoto {
  const WatchPhoto({
    required this.id,
    required this.watchId,
    required this.filePath,
    this.isThumbnail = false,
    this.sortOrder = 0,
  });

  /// Opaque, client-generated identifier (UUID-like string).
  final String id;

  /// Id of the owning [Watch].
  final String watchId;

  /// Absolute path to the image file inside app storage.
  final String filePath;

  final bool isThumbnail;
  final int sortOrder;

  WatchPhoto copyWith({
    String? id,
    String? watchId,
    String? filePath,
    bool? isThumbnail,
    int? sortOrder,
  }) {
    return WatchPhoto(
      id: id ?? this.id,
      watchId: watchId ?? this.watchId,
      filePath: filePath ?? this.filePath,
      isThumbnail: isThumbnail ?? this.isThumbnail,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WatchPhoto &&
        other.id == id &&
        other.watchId == watchId &&
        other.filePath == filePath &&
        other.isThumbnail == isThumbnail &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(id, watchId, filePath, isThumbnail, sortOrder);

  @override
  String toString() =>
      'WatchPhoto(id: $id, watchId: $watchId, thumbnail: $isThumbnail)';
}
