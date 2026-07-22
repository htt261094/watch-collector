import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';

/// Temporary in-memory implementation used to bootstrap the app in M1.
///
/// It will be replaced by a local-storage backed implementation in a later
/// milestone. Seeding a couple of sample entries lets the UI render something
/// meaningful before persistence exists.
class InMemoryWatchRepository implements WatchRepository {
  final List<Watch> _watches = const [
    Watch(
      id: '1',
      brand: 'Seiko',
      model: 'SPB143',
      movement: 'Automatic',
    ),
    Watch(
      id: '2',
      brand: 'Casio',
      model: 'A168',
      movement: 'Quartz',
    ),
  ];

  @override
  Future<List<Watch>> getWatches() async {
    return List.unmodifiable(_watches);
  }
}
