import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';

void main() {
  late AppDatabase db;
  late DriftWatchRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftWatchRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Watch sampleWatch({
    String id = 'w1',
    List<String> complications = const ['Date', 'GMT'],
  }) {
    return Watch(
      id: id,
      brand: 'Seiko',
      model: 'SPB143',
      referenceNo: 'SPB143J1',
      movementType: MovementType.auto,
      caliber: '6R35',
      powerReserve: 70,
      vph: 21600,
      diameter: 40.5,
      lugWidth: 20,
      thickness: 13.2,
      caseMaterial: 'Stainless steel',
      complications: complications,
      purchaseDate: DateTime(2023, 5, 1),
      purchasePrice: 1000,
      notes: 'Great diver',
    );
  }

  test('saves a watch and reads back all fields + complications', () async {
    await repo.saveWatch(sampleWatch());

    final loaded = await repo.getWatch('w1');
    expect(loaded, isNotNull);
    expect(loaded!.brand, 'Seiko');
    expect(loaded.model, 'SPB143');
    expect(loaded.referenceNo, 'SPB143J1');
    expect(loaded.movementType, MovementType.auto);
    expect(loaded.caliber, '6R35');
    expect(loaded.powerReserve, 70);
    expect(loaded.vph, 21600);
    expect(loaded.diameter, 40.5);
    expect(loaded.lugWidth, 20);
    expect(loaded.thickness, 13.2);
    expect(loaded.caseMaterial, 'Stainless steel');
    expect(loaded.purchaseDate, DateTime(2023, 5, 1));
    expect(loaded.purchasePrice, 1000);
    expect(loaded.notes, 'Great diver');
    // Complications preserve their insertion order.
    expect(loaded.complications, ['Date', 'GMT']);
  });

  test('getWatches returns saved watches with their complications', () async {
    await repo.saveWatch(sampleWatch());

    final all = await repo.getWatches();
    expect(all, hasLength(1));
    expect(all.single.complications, ['Date', 'GMT']);
  });

  test('editing a watch replaces its complication set', () async {
    await repo.saveWatch(sampleWatch(complications: ['Date', 'GMT']));
    await repo.saveWatch(sampleWatch(complications: ['Chronograph']));

    final loaded = await repo.getWatch('w1');
    expect(loaded!.complications, ['Chronograph']);

    // No orphaned complication rows remain.
    final rows = await db.select(db.complications).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Chronograph');
  });

  test('deleting a watch cascades to its complications', () async {
    await repo.saveWatch(sampleWatch());
    await repo.deleteWatch('w1');

    expect(await repo.getWatch('w1'), isNull);
    expect(await db.select(db.complications).get(), isEmpty);
  });

  test('getWatch returns null for an unknown id', () async {
    expect(await repo.getWatch('missing'), isNull);
  });
}
