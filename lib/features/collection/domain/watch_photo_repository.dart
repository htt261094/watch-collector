import 'package:flutter/foundation.dart';

import 'package:watch_collection/features/collection/domain/watch_photo.dart';

/// Describes the desired state of a single photo when saving a watch's gallery.
///
/// The gallery editor works with a mix of already-stored photos and freshly
/// picked files. Rather than leak file/row bookkeeping into the UI, the editor
/// hands the repository a list of these drafts and the repository reconciles
/// rows and files to match (see [WatchPhotoRepository.savePhotos]).
@immutable
sealed class PhotoDraft {
  const PhotoDraft({required this.isThumbnail});

  /// Whether this photo should become the watch's representative thumbnail.
  final bool isThumbnail;
}

/// A photo already persisted in storage that should be kept.
class ExistingPhoto extends PhotoDraft {
  const ExistingPhoto({required this.id, required super.isThumbnail});

  final String id;
}

/// A newly picked photo whose file at [sourcePath] should be imported into
/// app storage and recorded.
class NewPhoto extends PhotoDraft {
  const NewPhoto({required this.sourcePath, required super.isThumbnail});

  final String sourcePath;
}

/// Abstraction over the per-watch photo gallery, owning both the database rows
/// and the underlying image files so the two never drift apart.
abstract interface class WatchPhotoRepository {
  /// Photos for a watch, in gallery order (thumbnail-eligible order).
  Future<List<WatchPhoto>> getPhotos(String watchId);

  /// Map of watch id to its thumbnail file path, for the collection list.
  /// Watches without any photo are absent from the map.
  Future<Map<String, String>> getThumbnails();

  /// Reconciles the stored gallery for [watchId] to match [drafts]:
  /// keeps/reorders existing photos, imports new files, deletes dropped ones,
  /// and normalises the set so exactly one photo is the thumbnail when the
  /// gallery is non-empty.
  Future<void> savePhotos(String watchId, List<PhotoDraft> drafts);

  /// Deletes all photo files for a watch (its rows are removed by the database
  /// cascade). Call when a watch itself is deleted.
  Future<void> deletePhotosForWatch(String watchId);
}
