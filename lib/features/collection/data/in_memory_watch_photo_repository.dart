import 'package:watch_collection/features/collection/domain/watch_photo.dart';
import 'package:watch_collection/features/collection/domain/watch_photo_repository.dart';

/// In-memory [WatchPhotoRepository] for tests, previews, and running the app
/// without a real database / file storage.
///
/// It records the drafts it is handed but performs no file I/O, so it is safe
/// in a widget-test environment where platform plugins are unavailable. New
/// photos are given synthetic paths derived from their source path.
class InMemoryWatchPhotoRepository implements WatchPhotoRepository {
  final Map<String, List<WatchPhoto>> _byWatch = {};
  var _seq = 0;

  @override
  Future<List<WatchPhoto>> getPhotos(String watchId) async {
    return List.unmodifiable(_byWatch[watchId] ?? const []);
  }

  @override
  Future<Map<String, String>> getThumbnails() async {
    final result = <String, String>{};
    for (final entry in _byWatch.entries) {
      for (final photo in entry.value) {
        if (photo.isThumbnail) {
          result[entry.key] = photo.filePath;
          break;
        }
      }
    }
    return result;
  }

  @override
  Future<void> savePhotos(String watchId, List<PhotoDraft> drafts) async {
    final existing = {
      for (final p in _byWatch[watchId] ?? const <WatchPhoto>[]) p.id: p,
    };

    var thumbIndex = drafts.indexWhere((d) => d.isThumbnail);
    if (thumbIndex < 0 && drafts.isNotEmpty) thumbIndex = 0;

    final next = <WatchPhoto>[];
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      final isThumb = i == thumbIndex;
      if (draft is ExistingPhoto) {
        final prev = existing[draft.id];
        if (prev == null) continue;
        next.add(prev.copyWith(isThumbnail: isThumb, sortOrder: i));
      } else if (draft is NewPhoto) {
        final id = 'mem-${_seq++}';
        next.add(
          WatchPhoto(
            id: id,
            watchId: watchId,
            filePath: draft.sourcePath,
            isThumbnail: isThumb,
            sortOrder: i,
          ),
        );
      }
    }
    _byWatch[watchId] = next;
  }

  @override
  Future<void> deletePhotosForWatch(String watchId) async {
    _byWatch.remove(watchId);
  }
}
