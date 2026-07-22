import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';

/// In-memory [WatchRepository], handy for tests, previews, and running the app
/// without a real database.
///
/// State lives only for the lifetime of the instance. It is seeded with a
/// couple of sample entries so the UI renders something meaningful.
class InMemoryWatchRepository implements WatchRepository {
  InMemoryWatchRepository();

  final List<Watch> _watches = [
    const Watch(
      id: '1',
      brand: 'Seiko',
      model: 'SPB143',
      movementType: MovementType.auto,
    ),
    const Watch(
      id: '2',
      brand: 'Casio',
      model: 'A168',
      movementType: MovementType.quartz,
    ),
  ];

  @override
  Future<List<Watch>> getWatches() async {
    return List.unmodifiable(_watches);
  }

  @override
  Future<Watch?> getWatch(String id) async {
    for (final w in _watches) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<void> saveWatch(Watch watch) async {
    final index = _watches.indexWhere((w) => w.id == watch.id);
    if (index >= 0) {
      _watches[index] = watch;
    } else {
      _watches.insert(0, watch);
    }
  }

  @override
  Future<void> deleteWatch(String id) async {
    _watches.removeWhere((w) => w.id == id);
  }
}
