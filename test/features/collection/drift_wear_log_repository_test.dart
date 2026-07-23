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

  group('wear history (issue #8)', () {
    test('getEntriesForWatch returns that watch, most recent first', () async {
      await repo.logWear('w1', DateTime(2026, 7, 20));
      await repo.logWear('w1', DateTime(2026, 7, 23));
      await repo.logWear('w1', DateTime(2026, 7, 21));
      await repo.logWear('w2', DateTime(2026, 7, 22));

      final entries = await repo.getEntriesForWatch('w1');
      expect(entries, hasLength(3));
      expect(entries.every((e) => e.watchId == 'w1'), isTrue);
      expect(
        entries.map((e) => e.wornOn),
        [DateTime(2026, 7, 23), DateTime(2026, 7, 21), DateTime(2026, 7, 20)],
      );
    });

    test('getAllEntries spans every watch, most recent first', () async {
      await repo.logWear('w1', DateTime(2026, 7, 20));
      await repo.logWear('w2', DateTime(2026, 7, 23));

      final entries = await repo.getAllEntries();
      expect(entries.map((e) => e.watchId), ['w2', 'w1']);
    });

    test('updateEntry moves the day and sets the note', () async {
      await repo.logWear('w1', DateTime(2026, 7, 20));
      final entry = (await repo.getEntriesForWatch('w1')).single;

      await repo.updateEntry(
        entry.id,
        wornOn: DateTime(2026, 7, 25, 10),
        note: '  desk day  ',
      );

      final updated = (await repo.getEntriesForWatch('w1')).single;
      expect(updated.wornOn, DateTime(2026, 7, 25));
      expect(updated.note, 'desk day'); // trimmed
    });

    test('updateEntry clears the note when given blank text', () async {
      await repo.logWear('w1', DateTime(2026, 7, 20));
      final entry = (await repo.getEntriesForWatch('w1')).single;
      await repo.updateEntry(entry.id, wornOn: entry.wornOn, note: 'x');

      await repo.updateEntry(entry.id, wornOn: entry.wornOn, note: '   ');

      expect((await repo.getEntriesForWatch('w1')).single.note, isNull);
    });

    test('updateEntry keeps one entry per watch per day on collision',
        () async {
      await repo.logWear('w1', DateTime(2026, 7, 20));
      await repo.logWear('w1', DateTime(2026, 7, 21));
      final entries = await repo.getEntriesForWatch('w1');
      final toMove = entries.firstWhere(
        (e) => e.wornOn == DateTime(2026, 7, 20),
      );

      // Move the 20th onto the 21st, which already has an entry.
      await repo.updateEntry(toMove.id, wornOn: DateTime(2026, 7, 21));

      final after = await repo.getEntriesForWatch('w1');
      expect(after, hasLength(1));
      expect(after.single.wornOn, DateTime(2026, 7, 21));
    });

    test('deleteEntry removes just that record', () async {
      await repo.logWear('w1', DateTime(2026, 7, 20));
      await repo.logWear('w1', DateTime(2026, 7, 21));
      final entry =
          (await repo.getEntriesForWatch('w1')).first; // the 21st

      await repo.deleteEntry(entry.id);

      final after = await repo.getEntriesForWatch('w1');
      expect(after, hasLength(1));
      expect(after.single.wornOn, DateTime(2026, 7, 20));
    });
  });
}
