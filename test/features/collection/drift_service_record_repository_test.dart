import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_service_record_repository.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/data/photo_storage.dart';
import 'package:watch_collection/features/collection/domain/service_record.dart';
import 'package:watch_collection/features/collection/domain/service_record_repository.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';

void main() {
  late AppDatabase db;
  late DriftServiceRecordRepository repo;
  late DriftWatchRepository watches;
  late Directory tempDir;
  late PhotoStorage storage;

  /// Creates a throwaway source image file and returns its path.
  Future<String> makeSourceImage(String name) async {
    final file = File('${tempDir.path}/$name.jpg');
    await file.writeAsBytes([1, 2, 3, 4]);
    return file.path;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('service_records_test');
    storage = PhotoStorage(rootOverride: tempDir);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftServiceRecordRepository(db, storage);
    watches = DriftWatchRepository(db);
    await watches.saveWatch(
      const Watch(id: 'w1', brand: 'Seiko', model: 'SPB143'),
    );
    await watches.saveWatch(
      const Watch(id: 'w2', brand: 'Casio', model: 'A168'),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('addRecord stores a reminder and reads it back', () async {
    await repo.addRecord(
      'w1',
      type: ServiceRecordType.warranty,
      dueDate: DateTime(2027, 1, 15),
      note: 'Keep the receipt',
    );

    final records = await repo.getRecordsForWatch('w1');
    expect(records, hasLength(1));
    final record = records.single;
    expect(record.type, ServiceRecordType.warranty);
    expect(record.dueDate, DateTime(2027, 1, 15));
    expect(record.note, 'Keep the receipt');
    expect(record.watchId, 'w1');
    expect(record.hasCardPhoto, isFalse);
  });

  test('records are returned soonest due first', () async {
    await repo.addRecord('w1',
        type: ServiceRecordType.service, dueDate: DateTime(2027, 5, 1),);
    await repo.addRecord('w1',
        type: ServiceRecordType.service, dueDate: DateTime(2026, 12, 1),);
    await repo.addRecord('w1',
        type: ServiceRecordType.warranty, dueDate: DateTime(2027, 1, 1),);

    final dates = (await repo.getRecordsForWatch('w1'))
        .map((r) => r.dueDate)
        .toList();
    expect(dates, [
      DateTime(2026, 12, 1),
      DateTime(2027, 1, 1),
      DateTime(2027, 5, 1),
    ]);
  });

  test('note is trimmed; blank note stored as null', () async {
    await repo.addRecord(
      'w1',
      type: ServiceRecordType.service,
      dueDate: DateTime(2027, 1, 1),
      note: '   ',
    );
    expect((await repo.getRecordsForWatch('w1')).single.note, isNull);
  });

  test('records are scoped to their watch', () async {
    await repo.addRecord('w1',
        type: ServiceRecordType.service, dueDate: DateTime(2027, 1, 1),);
    await repo.addRecord('w2',
        type: ServiceRecordType.warranty, dueDate: DateTime(2027, 2, 1),);

    expect((await repo.getRecordsForWatch('w1')).single.type,
        ServiceRecordType.service,);
    expect((await repo.getRecordsForWatch('w2')).single.type,
        ServiceRecordType.warranty,);
  });

  test('getAllRecords spans watches, soonest due first', () async {
    await repo.addRecord('w1',
        type: ServiceRecordType.service, dueDate: DateTime(2027, 3, 1),);
    await repo.addRecord('w2',
        type: ServiceRecordType.warranty, dueDate: DateTime(2027, 1, 1),);

    final all = await repo.getAllRecords();
    expect(all.map((r) => r.watchId), ['w2', 'w1']);
  });

  test('updateRecord changes type, due date, and note', () async {
    final id = await repo.addRecord('w1',
        type: ServiceRecordType.service, dueDate: DateTime(2027, 1, 1),);

    await repo.updateRecord(
      id,
      type: ServiceRecordType.warranty,
      dueDate: DateTime(2028, 6, 30),
      note: 'Extended warranty',
    );

    final record = (await repo.getRecordsForWatch('w1')).single;
    expect(record.type, ServiceRecordType.warranty);
    expect(record.dueDate, DateTime(2028, 6, 30));
    expect(record.note, 'Extended warranty');
  });

  test('deleteRecord removes just that record', () async {
    final keep = await repo.addRecord('w1',
        type: ServiceRecordType.service, dueDate: DateTime(2027, 1, 1),);
    final remove = await repo.addRecord('w1',
        type: ServiceRecordType.warranty, dueDate: DateTime(2027, 2, 1),);

    await repo.deleteRecord(remove);

    final records = await repo.getRecordsForWatch('w1');
    expect(records, hasLength(1));
    expect(records.single.id, keep);
  });

  test('deleting a watch cascades to its service records', () async {
    await repo.addRecord('w1',
        type: ServiceRecordType.service, dueDate: DateTime(2027, 1, 1),);
    await watches.deleteWatch('w1');
    expect(await repo.getRecordsForWatch('w1'), isEmpty);
  });

  group('warranty card photo', () {
    test('addRecord imports the card photo into storage', () async {
      final source = await makeSourceImage('card');
      await repo.addRecord(
        'w1',
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 1, 1),
        cardPhotoSourcePath: source,
      );

      final record = (await repo.getRecordsForWatch('w1')).single;
      expect(record.hasCardPhoto, isTrue);
      // Copied into app storage, not left pointing at the source.
      expect(record.cardPhotoPath, isNot(source));
      expect(await File(record.cardPhotoPath!).exists(), isTrue);
    });

    test('setting a new card photo removes the old file', () async {
      final first = await makeSourceImage('first');
      final id = await repo.addRecord(
        'w1',
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 1, 1),
        cardPhotoSourcePath: first,
      );
      final oldPath = (await repo.getRecord(id))!.cardPhotoPath!;

      final second = await makeSourceImage('second');
      await repo.updateRecord(
        id,
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 1, 1),
        cardPhoto: CardPhotoChange.set(second),
      );

      final newPath = (await repo.getRecord(id))!.cardPhotoPath!;
      expect(newPath, isNot(oldPath));
      expect(await File(newPath).exists(), isTrue);
      expect(await File(oldPath).exists(), isFalse);
    });

    test('keep leaves the existing photo untouched', () async {
      final source = await makeSourceImage('card');
      final id = await repo.addRecord(
        'w1',
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 1, 1),
        cardPhotoSourcePath: source,
      );
      final path = (await repo.getRecord(id))!.cardPhotoPath!;

      await repo.updateRecord(
        id,
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 2, 2),
      );

      expect((await repo.getRecord(id))!.cardPhotoPath, path);
      expect(await File(path).exists(), isTrue);
    });

    test('clearing removes the photo and its file', () async {
      final source = await makeSourceImage('card');
      final id = await repo.addRecord(
        'w1',
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 1, 1),
        cardPhotoSourcePath: source,
      );
      final path = (await repo.getRecord(id))!.cardPhotoPath!;

      await repo.updateRecord(
        id,
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 1, 1),
        cardPhoto: const CardPhotoChange.clear(),
      );

      expect((await repo.getRecord(id))!.cardPhotoPath, isNull);
      expect(await File(path).exists(), isFalse);
    });

    test('deleteRecord removes the card photo file', () async {
      final source = await makeSourceImage('card');
      final id = await repo.addRecord(
        'w1',
        type: ServiceRecordType.warranty,
        dueDate: DateTime(2027, 1, 1),
        cardPhotoSourcePath: source,
      );
      final path = (await repo.getRecord(id))!.cardPhotoPath!;

      await repo.deleteRecord(id);
      expect(await File(path).exists(), isFalse);
    });
  });
}
