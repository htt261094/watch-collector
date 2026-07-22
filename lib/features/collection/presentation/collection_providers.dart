import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:watch_collection/features/collection/data/in_memory_watch_repository.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';

/// Provides the repository implementation to the rest of the app.
///
/// Kept as a plain [Provider] so it can be overridden in tests or swapped for a
/// local-storage implementation later without touching the presentation layer.
final watchRepositoryProvider = Provider<WatchRepository>((ref) {
  return InMemoryWatchRepository();
});

/// Loads the list of watches from the repository.
final watchListProvider = FutureProvider<List<Watch>>((ref) async {
  final repository = ref.watch(watchRepositoryProvider);
  return repository.getWatches();
});
