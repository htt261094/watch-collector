import 'package:drift/drift.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/util/id_generator.dart';
import 'package:watch_collection/features/collection/data/photo_storage.dart';
import 'package:watch_collection/features/collection/domain/watch_photo.dart';
import 'package:watch_collection/features/collection/domain/watch_photo_repository.dart';

/// Local-storage backed [WatchPhotoRepository].
///
/// Coordinates the drift [WatchPhotos] rows with the image files owned by
/// [PhotoStorage] so a photo's row and its file are always created and removed
/// together. Row work runs inside a transaction; file work happens around it.
class DriftWatchPhotoRepository implements WatchPhotoRepository {
  DriftWatchPhotoRepository(this._db, this._storage);

  final AppDatabase _db;
  final PhotoStorage _storage;

  @override
  Future<List<WatchPhoto>> getPhotos(String watchId) async {
    final rows = await _db.watchPhotoDao.getPhotosForWatch(watchId);
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Map<String, String>> getThumbnails() async {
    final rows = await _db.watchPhotoDao.getAllThumbnails();
    return {for (final row in rows) row.watchId: row.filePath};
  }

  @override
  Future<void> savePhotos(String watchId, List<PhotoDraft> drafts) async {
    final existing = await _db.watchPhotoDao.getPhotosForWatch(watchId);

    // Which already-stored photos are being kept?
    final keptIds = drafts.whereType<ExistingPhoto>().map((d) => d.id).toSet();

    // Rows/files for photos the user removed.
    final removed =
        existing.where((row) => !keptIds.contains(row.id)).toList();

    // Normalise the thumbnail flag: honour the first draft explicitly marked
    // as thumbnail; otherwise fall back to the first photo so a non-empty
    // gallery always has exactly one representative image.
    var thumbIndex = drafts.indexWhere((d) => d.isThumbnail);
    if (thumbIndex < 0 && drafts.isNotEmpty) thumbIndex = 0;

    // Import new files up front (outside the transaction — file I/O only),
    // recording the minted id + destination path per draft index.
    final imported = <int, ({String id, String path})>{};
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      if (draft is NewPhoto) {
        final id = IdGenerator.newId();
        final path = await _storage.importPhoto(
          watchId: watchId,
          photoId: id,
          sourcePath: draft.sourcePath,
        );
        imported[i] = (id: id, path: path);
      }
    }

    await _db.transaction(() async {
      if (removed.isNotEmpty) {
        await _db.watchPhotoDao.deletePhotos(removed.map((r) => r.id));
      }

      for (var i = 0; i < drafts.length; i++) {
        final draft = drafts[i];
        final isThumb = i == thumbIndex;
        if (draft is ExistingPhoto) {
          await _db.watchPhotoDao.updatePhoto(
            draft.id,
            WatchPhotosCompanion(
              sortOrder: Value(i),
              isThumbnail: Value(isThumb),
            ),
          );
        } else if (draft is NewPhoto) {
          final entry = imported[i]!;
          await _db.watchPhotoDao.insertPhoto(
            WatchPhotosCompanion.insert(
              id: entry.id,
              watchId: watchId,
              filePath: entry.path,
              isThumbnail: Value(isThumb),
              sortOrder: Value(i),
            ),
          );
        }
      }
    });

    // Delete dropped files only after the rows are gone.
    for (final row in removed) {
      await _storage.deleteFile(row.filePath);
    }
  }

  @override
  Future<void> deletePhotosForWatch(String watchId) async {
    // Rows cascade with the watch; just clear the files.
    await _storage.deleteWatchDir(watchId);
  }

  WatchPhoto _toDomain(WatchPhotoRow row) {
    return WatchPhoto(
      id: row.id,
      watchId: row.watchId,
      filePath: row.filePath,
      isThumbnail: row.isThumbnail,
      sortOrder: row.sortOrder,
    );
  }
}
