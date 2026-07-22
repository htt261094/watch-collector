import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_collection/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  WatchesCompanion buildWatch(String id) {
    return WatchesCompanion.insert(
      id: id,
      brand: 'Seiko',
      model: 'SPB143',
      movementType: const Value('auto'),
    );
  }

  test('inserts and reads back a watch', () async {
    await db.watchDao.upsertWatch(buildWatch('w1'));

    final rows = await db.watchDao.getAllWatches();
    expect(rows, hasLength(1));
    expect(rows.single.brand, 'Seiko');
    expect(rows.single.model, 'SPB143');
    expect(rows.single.movementType, 'auto');
  });

  test('upsert replaces an existing watch with the same id', () async {
    await db.watchDao.upsertWatch(buildWatch('w1'));
    await db.watchDao.upsertWatch(
      buildWatch('w1').copyWith(model: const Value('SPB149')),
    );

    final row = await db.watchDao.getWatchById('w1');
    expect(row, isNotNull);
    expect(row!.model, 'SPB149');
    expect(await db.watchDao.getAllWatches(), hasLength(1));
  });

  test('deleting a watch cascades to its child rows', () async {
    await db.watchDao.upsertWatch(buildWatch('w1'));
    await db.into(db.watchPhotos).insert(
          WatchPhotosCompanion.insert(
            id: 'p1',
            watchId: 'w1',
            filePath: '/photos/p1.jpg',
          ),
        );
    await db.into(db.customFields).insert(
          CustomFieldsCompanion.insert(
            id: 'c1',
            watchId: 'w1',
            fieldKey: 'strap',
            fieldValue: const Value('leather'),
          ),
        );

    final removed = await db.watchDao.deleteWatch('w1');
    expect(removed, 1);

    expect(await db.select(db.watchPhotos).get(), isEmpty);
    expect(await db.select(db.customFields).get(), isEmpty);
  });
}
