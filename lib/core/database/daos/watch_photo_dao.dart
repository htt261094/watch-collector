import 'package:drift/drift.dart';
import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/core/database/tables.dart';

part 'watch_photo_dao.g.dart';

/// Data-access object for the [WatchPhotos] table.
///
/// Photos are ordered within a watch by [WatchPhotos.sortOrder]; the row flagged
/// [WatchPhotos.isThumbnail] is the representative image. Keeping "exactly one
/// thumbnail" and file lifecycle is the repository's job — this DAO only offers
/// the raw queries.
@DriftAccessor(tables: [WatchPhotos])
class WatchPhotoDao extends DatabaseAccessor<AppDatabase>
    with _$WatchPhotoDaoMixin {
  WatchPhotoDao(super.db);

  /// Photos for a watch, in gallery order.
  Future<List<WatchPhotoRow>> getPhotosForWatch(String watchId) {
    return (select(watchPhotos)
          ..where((p) => p.watchId.equals(watchId))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
  }

  /// The thumbnail row for each watch that has one, across the whole table.
  Future<List<WatchPhotoRow>> getAllThumbnails() {
    return (select(watchPhotos)..where((p) => p.isThumbnail.equals(true))).get();
  }

  Future<void> insertPhoto(WatchPhotosCompanion entry) {
    return into(watchPhotos).insert(entry);
  }

  /// Applies partial updates (thumbnail flag, sort order) to a photo by id.
  Future<void> updatePhoto(String id, WatchPhotosCompanion entry) {
    return (update(watchPhotos)..where((p) => p.id.equals(id))).write(entry);
  }

  Future<void> deletePhotos(Iterable<String> ids) {
    return (delete(watchPhotos)..where((p) => p.id.isIn(ids))).go();
  }
}
