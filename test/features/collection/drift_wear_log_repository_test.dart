import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/data/drift_wear_log_repository.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';

void main() {
  late AppDatabase db;
  late DriftWearLogRepository repo;
  late DriftWatchRepository watches;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftWearLogRepository(db);
    watches = DriftWatchRepository(db);
    // Wear logs reference a watch row (FK), so seed one first.
    await watches.saveWatch(
      const Watch(id: 'w1', brand: 'Seiko', model: 'SPB143'),
    );
    await watches.saveWatch(
      const Watch(id: 'w2', brand: 'Casio', model: 'A168'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  final today = DateTime(2026, 7, 23, 14, 30);

  test('logWear records a watch as worn on the day', () async {
    await repo.logWear('w1', today);

    final worn = await repo.getWatchIdsWornOn(today);
    expect(worn, {'w1'});
  });

  test('matching ignores the time component of the day', () async {
    await repo.logWear('w1', DateTime(2026, 7, 23, 9));

    // A different time on the same calendar day still matches.
    final worn = await repo.getWatchIdsWornOn(DateTime(2026, 7, 23, 23, 59));
    expect(worn, {'w1'});
  });

  test('logWear is idempotent — one entry per watch per day', () async {
    await repo.logWear('w1', today);
    await repo.logWear('w1', today);

    final rows = await db.select(db.wearLogs).get();
    expect(rows, hasLength(1));
  });

  test('removeWear clears the entry for that watch and day', () async {
    await repo.logWear('w1', today);
    await repo.logWear('w2', today);

    await repo.removeWear('w1', today);

    final worn = await repo.getWatchIdsWornOn(today);
    expect(worn, {'w2'});
  });

  test('entries on other days are not returned', () async {
    await repo.logWear('w1', DateTime(2026, 7, 22));
    await repo.logWear('w2', today);

    final worn = await repo.getWatchIdsWornOn(today);
    expect(worn, {'w2'});
  });

  test('deleting a watch cascades to its wear logs', () async {
    await repo.logWear('w1', today);
    await watches.deleteWatch('w1');

    expect(await repo.getWatchIdsWornOn(today), isEmpty);
  });
}
