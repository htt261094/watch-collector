import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:watch_collection/core/database/app_database.dart';
import 'package:watch_collection/features/collection/data/drift_watch_photo_repository.dart';
import 'package:watch_collection/features/collection/data/drift_watch_repository.dart';
import 'package:watch_collection/features/collection/data/photo_storage.dart';
import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/watch_photo_repository.dart';

void main() {
  late AppDatabase db;
  late DriftWatchRepository watchRepo;
  late DriftWatchPhotoRepository photoRepo;
  late PhotoStorage storage;
  late Directory storageRoot;
  late Directory sourceDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storageRoot = await Directory.systemTemp.createTemp('photo_store_');
    sourceDir = await Directory.systemTemp.createTemp('photo_src_');
    storage = PhotoStorage(rootOverride: storageRoot);
    watchRepo = DriftWatchRepository(db);
    photoRepo = DriftWatchPhotoRepository(db, storage);

    // A photo row's watchId is a foreign key, so a watch must exist first.
    await watchRepo.saveWatch(
      const Watch(id: 'w1', brand: 'Seiko', model: 'SPB143'),
    );
  });

  tearDown(() async {
    await db.close();
    for (final dir in [storageRoot, sourceDir]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  /// Creates a throwaway source image file and returns its path.
  Future<String> makeSource(String name) async {
    final file = File(p.join(sourceDir.path, name));
    await file.writeAsBytes([1, 2, 3, 4]);
    return file.path;
  }

  test('imports new photos, copies files, and defaults the first as thumbnail',
      () async {
    await photoRepo.savePhotos('w1', [
      NewPhoto(sourcePath: await makeSource('a.jpg'), isThumbnail: false),
      NewPhoto(sourcePath: await makeSource('b.jpg'), isThumbnail: false),
    ]);

    final photos = await photoRepo.getPhotos('w1');
    expect(photos, hasLength(2));
    // Gallery order preserved.
    expect(photos[0].sortOrder, 0);
    expect(photos[1].sortOrder, 1);
    // No explicit thumbnail -> first photo becomes the thumbnail.
    expect(photos[0].isThumbnail, isTrue);
    expect(photos[1].isThumbnail, isFalse);
    // Files were copied into app storage (not the source dir).
    for (final photo in photos) {
      expect(await File(photo.filePath).exists(), isTrue);
      expect(photo.filePath.startsWith(storageRoot.path), isTrue);
      expect(p.extension(photo.filePath), '.jpg');
    }
  });

  test('honours an explicitly chosen thumbnail', () async {
    await photoRepo.savePhotos('w1', [
      NewPhoto(sourcePath: await makeSource('a.jpg'), isThumbnail: false),
      NewPhoto(sourcePath: await makeSource('b.jpg'), isThumbnail: true),
    ]);

    final photos = await photoRepo.getPhotos('w1');
    expect(photos[0].isThumbnail, isFalse);
    expect(photos[1].isThumbnail, isTrue);
  });

  test('getThumbnails maps each watch to its thumbnail path', () async {
    await photoRepo.savePhotos('w1', [
      NewPhoto(sourcePath: await makeSource('a.jpg'), isThumbnail: true),
    ]);

    final thumbs = await photoRepo.getThumbnails();
    final photos = await photoRepo.getPhotos('w1');
    expect(thumbs['w1'], photos.single.filePath);
  });

  test('editing keeps existing photos, adds new ones, and deletes removed files',
      () async {
    await photoRepo.savePhotos('w1', [
      NewPhoto(sourcePath: await makeSource('a.jpg'), isThumbnail: true),
      NewPhoto(sourcePath: await makeSource('b.jpg'), isThumbnail: false),
    ]);
    final initial = await photoRepo.getPhotos('w1');
    final keptPath = initial[0].filePath;
    final removedPath = initial[1].filePath;

    // Keep the first, drop the second, add a third.
    await photoRepo.savePhotos('w1', [
      ExistingPhoto(id: initial[0].id, isThumbnail: true),
      NewPhoto(sourcePath: await makeSource('c.jpg'), isThumbnail: false),
    ]);

    final after = await photoRepo.getPhotos('w1');
    expect(after, hasLength(2));
    expect(after[0].id, initial[0].id);
    // Kept file stays; removed file is gone from disk.
    expect(await File(keptPath).exists(), isTrue);
    expect(await File(removedPath).exists(), isFalse);
    // Only the kept + new rows remain.
    final rows = await db.select(db.watchPhotos).get();
    expect(rows, hasLength(2));
  });

  test('deleting the watch cascades photo rows; deletePhotosForWatch clears '
      'files', () async {
    await photoRepo.savePhotos('w1', [
      NewPhoto(sourcePath: await makeSource('a.jpg'), isThumbnail: true),
    ]);
    final watchDir = Directory(p.join(storageRoot.path, 'watch_photos', 'w1'));
    expect(await watchDir.exists(), isTrue);

    await watchRepo.deleteWatch('w1');
    await photoRepo.deletePhotosForWatch('w1');

    expect(await db.select(db.watchPhotos).get(), isEmpty);
    expect(await watchDir.exists(), isFalse);
  });

  test('saving an empty gallery removes all photos and files', () async {
    await photoRepo.savePhotos('w1', [
      NewPhoto(sourcePath: await makeSource('a.jpg'), isThumbnail: true),
    ]);
    final path = (await photoRepo.getPhotos('w1')).single.filePath;

    await photoRepo.savePhotos('w1', const []);

    expect(await photoRepo.getPhotos('w1'), isEmpty);
    expect(await File(path).exists(), isFalse);
  });
}
