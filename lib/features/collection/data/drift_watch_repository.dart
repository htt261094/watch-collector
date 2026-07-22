import 'package:drift/drift.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/domain/movement_type.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_repository.dart';

/// Local-storage backed [WatchRepository] implementation, reading and writing
/// through the drift [AppDatabase].
///
/// It maps persistence rows ([WatchRow], [ComplicationRow]) onto the pure
/// domain [Watch] entity so the rest of the app stays unaware of drift.
/// Complications live in their own table, so saving a watch replaces its
/// complication rows inside a transaction to keep the two in sync.
class DriftWatchRepository implements WatchRepository {
  DriftWatchRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Watch>> getWatches() async {
    final rows = await _db.watchDao.getAllWatches();

    // Fetch all complications in one query and group by watch, avoiding an
    // N+1 round-trip per watch.
    final complicationRows = await (_db.select(_db.complications)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
    final byWatch = <String, List<String>>{};
    for (final c in complicationRows) {
      (byWatch[c.watchId] ??= []).add(c.name);
    }

    return rows
        .map((row) => _toDomain(row, byWatch[row.id] ?? const []))
        .toList();
  }

  @override
  Future<Watch?> getWatch(String id) async {
    final row = await _db.watchDao.getWatchById(id);
    if (row == null) return null;
    return _toDomain(row, await _complicationsFor(id));
  }

  @override
  Future<void> saveWatch(Watch watch) async {
    await _db.transaction(() async {
      await _db.watchDao.upsertWatch(_toCompanion(watch));

      // Replace the complication set: clear existing rows, then re-insert in
      // display order.
      await (_db.delete(_db.complications)
            ..where((c) => c.watchId.equals(watch.id)))
          .go();
      for (var i = 0; i < watch.complications.length; i++) {
        await _db.into(_db.complications).insert(
              ComplicationsCompanion.insert(
                id: '${watch.id}-c$i',
                watchId: watch.id,
                name: watch.complications[i],
                sortOrder: Value(i),
              ),
            );
      }
    });
  }

  @override
  Future<void> deleteWatch(String id) async {
    await _db.watchDao.deleteWatch(id);
  }

  Future<List<String>> _complicationsFor(String watchId) async {
    final rows = await (_db.select(_db.complications)
          ..where((c) => c.watchId.equals(watchId))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
    return rows.map((c) => c.name).toList();
  }

  Watch _toDomain(WatchRow row, List<String> complications) {
    return Watch(
      id: row.id,
      brand: row.brand,
      model: row.model,
      referenceNo: row.referenceNo,
      serialNo: row.serialNo,
      movementType: MovementType.fromStorage(row.movementType),
      caliber: row.caliber,
      powerReserve: row.powerReserve,
      vph: row.vph,
      diameter: row.diameter,
      lugWidth: row.lugWidth,
      thickness: row.thickness,
      caseMaterial: row.caseMaterial,
      complications: complications,
      purchaseDate: row.purchaseDate,
      purchasePrice: row.purchasePrice,
      notes: row.notes,
    );
  }

  WatchesCompanion _toCompanion(Watch watch) {
    return WatchesCompanion(
      id: Value(watch.id),
      brand: Value(watch.brand),
      model: Value(watch.model),
      referenceNo: Value(watch.referenceNo),
      serialNo: Value(watch.serialNo),
      movementType: Value(watch.movementType?.storageValue),
      caliber: Value(watch.caliber),
      powerReserve: Value(watch.powerReserve),
      vph: Value(watch.vph),
      diameter: Value(watch.diameter),
      lugWidth: Value(watch.lugWidth),
      thickness: Value(watch.thickness),
      caseMaterial: Value(watch.caseMaterial),
      purchaseDate: Value(watch.purchaseDate),
      purchasePrice: Value(watch.purchasePrice),
      notes: Value(watch.notes),
      // Refresh the modification stamp on every save. `createdAt` is left
      // absent so its default is used on insert and preserved on update.
      updatedAt: Value(DateTime.now()),
    );
  }
}
