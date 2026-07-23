import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_custom_field_repository.dart';
import 'package:watch_collection/features/collection/data/drift_watch_photo_repository.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/data/drift_wear_log_repository.dart';
import 'package:watch_collection/features/collection/data/photo_storage.dart';
import 'package:watch_collection/features/collection/domain/collection_stats.dart';
import 'package:watch_collection/features/collection/domain/custom_field.dart';
import 'package:watch_collection/features/collection/domain/custom_field_repository.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_photo.dart';
import 'package:watch_collection/features/collection/domain/watch_photo_repository.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';
import 'package:watch_collection/features/collection/domain/wear_entry.dart';
import 'package:watch_collection/features/collection/domain/wear_log_repository.dart';

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

/// Repository for wear tracking ("worn today"), backed by local storage.
final wearLogRepositoryProvider = Provider<WearLogRepository>((ref) {
  return DriftWearLogRepository(ref.watch(appDatabaseProvider));
});

/// The set of watch ids worn today. Invalidated whenever a watch is toggled
/// worn/not-worn so the home screen reflects the latest state.
///
/// The current day is resolved once when the provider builds; the app is
/// expected to be re-read (invalidated) as the user interacts, and a long-lived
/// session spanning midnight is out of scope for M1.
final watchesWornTodayProvider = FutureProvider<Set<String>>((ref) async {
  return ref.watch(wearLogRepositoryProvider).getWatchIdsWornOn(DateTime.now());
});

/// Wear history for a single watch, most recent first. Invalidated whenever a
/// wear record is added, edited, or removed.
final wearHistoryForWatchProvider =
    FutureProvider.family<List<WearEntry>, String>((ref, watchId) async {
  return ref.watch(wearLogRepositoryProvider).getEntriesForWatch(watchId);
});

/// Wear history across the whole collection, most recent first. Invalidated
/// whenever a wear record is added, edited, or removed.
final allWearHistoryProvider = FutureProvider<List<WearEntry>>((ref) async {
  return ref.watch(wearLogRepositoryProvider).getAllEntries();
});

/// Convenience lookup of watch id -> "Brand Model" label, for wear-history
/// views that list entries across multiple watches.
final watchLabelsProvider = FutureProvider<Map<String, String>>((ref) async {
  final watches = await ref.watch(watchListProvider.future);
  return {for (final w in watches) w.id: '${w.brand} ${w.model}'};
});

/// Repository for per-watch custom fields (issue #15), backed by local storage.
final customFieldRepositoryProvider = Provider<CustomFieldRepository>((ref) {
  return DriftCustomFieldRepository(ref.watch(appDatabaseProvider));
});

/// The custom fields for a single watch, in display order. Invalidated whenever
/// a field is added, edited, or removed.
final customFieldsForWatchProvider =
    FutureProvider.family<List<CustomField>, String>((ref, watchId) async {
  return ref.watch(customFieldRepositoryProvider).getFieldsForWatch(watchId);
});

/// Aggregate collection statistics (issue #9): cost-per-wear, most/least worn,
/// wears this year, and brand/movement distributions. Derived from the watch
/// list and the full wear log, so it refreshes whenever either changes.
final collectionStatsProvider = FutureProvider<CollectionStats>((ref) async {
  final watches = await ref.watch(watchListProvider.future);
  final entries = await ref.watch(allWearHistoryProvider.future);
  return computeCollectionStats(watches, entries);
});
