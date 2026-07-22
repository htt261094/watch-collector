import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the on-disk image files backing the watch gallery.
///
/// Files live under `<app-documents>/watch_photos/<watchId>/<photoId><ext>`.
/// The database only ever stores the resulting absolute path (see the
/// `WatchPhotos` table); this service handles copying picked files in and
/// removing them again. A [rootOverride] lets tests point storage at a temp
/// directory instead of the platform documents directory.
class PhotoStorage {
  PhotoStorage({Directory? rootOverride}) : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  static const _folder = 'watch_photos';

  Future<Directory> _root() async {
    final base = _rootOverride ?? await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, _folder));
  }

  Future<Directory> _watchDir(String watchId) async {
    final dir = Directory(p.join((await _root()).path, watchId));
    await dir.create(recursive: true);
    return dir;
  }

  /// Copies the file at [sourcePath] into the watch's storage folder under a
  /// stable [photoId] filename, returning the absolute destination path.
  Future<String> importPhoto({
    required String watchId,
    required String photoId,
    required String sourcePath,
  }) async {
    final dir = await _watchDir(watchId);
    // Preserve the original extension so the OS/image decoder is happy.
    final ext = p.extension(sourcePath);
    final dest = p.join(dir.path, '$photoId$ext');
    await File(sourcePath).copy(dest);
    return dest;
  }

  /// Deletes a single image file, ignoring a file that is already gone.
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Removes a watch's entire photo folder (used when the watch is deleted).
  Future<void> deleteWatchDir(String watchId) async {
    final dir = Directory(p.join((await _root()).path, watchId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
