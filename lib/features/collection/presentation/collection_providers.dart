import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_watch_photo_repository.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/data/photo_storage.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_photo.dart';
import 'package:watch_collection/features/collection/domain/watch_photo_repository.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';

/// The app-wide drift database. Disposed with the provider scope so the
/// underlying connection is closed cleanly.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provides the repository implementation to the rest of the app.
///
/// Backed by local storage ([DriftWatchRepository]). Kept as a plain [Provider]
/// so it can be overridden in tests without touching the presentation layer.
final watchRepositoryProvider = Provider<WatchRepository>((ref) {
  return DriftWatchRepository(ref.watch(appDatabaseProvider));
});

/// Loads the list of watches from the repository. Invalidated after a
/// save/delete so the list reflects the latest data.
final watchListProvider = FutureProvider<List<Watch>>((ref) async {
  final repository = ref.watch(watchRepositoryProvider);
  return repository.getWatches();
});

/// Loads a single watch by id — used to pre-fill the form in edit mode.
final watchByIdProvider =
    FutureProvider.family<Watch?, String>((ref, id) async {
  final repository = ref.watch(watchRepositoryProvider);
  return repository.getWatch(id);
});

/// The image-file store backing the watch galleries.
final photoStorageProvider = Provider<PhotoStorage>((ref) => PhotoStorage());

/// Repository for per-watch photo galleries, backed by local storage.
final watchPhotoRepositoryProvider = Provider<WatchPhotoRepository>((ref) {
  return DriftWatchPhotoRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(photoStorageProvider),
  );
});

/// Photos for a single watch, in gallery order. Invalidated after the gallery
/// is edited so views reflect the latest set.
final watchPhotosProvider =
    FutureProvider.family<List<WatchPhoto>, String>((ref, watchId) async {
  return ref.watch(watchPhotoRepositoryProvider).getPhotos(watchId);
});

/// Map of watch id to thumbnail file path, for the collection list. Invalidated
/// alongside [watchListProvider] whenever galleries or watches change.
final watchThumbnailsProvider =
    FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(watchPhotoRepositoryProvider).getThumbnails();
});
