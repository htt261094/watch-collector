import 'package:watch_collection/features/collection/domain/service_record.dart';

/// How the warranty-card photo should change when updating a record.
///
/// A three-way choice is needed because "leave as-is" and "remove the photo"
/// are distinct from "set a new photo" — a plain nullable path could not tell
/// "keep" apart from "clear".
sealed class CardPhotoChange {
  const CardPhotoChange();

  /// Leave the existing card photo (if any) untouched.
  const factory CardPhotoChange.keep() = KeepCardPhoto;

  /// Replace the card photo with the image at [sourcePath].
  const factory CardPhotoChange.set(String sourcePath) = SetCardPhoto;

  /// Remove the card photo entirely.
  const factory CardPhotoChange.clear() = ClearCardPhoto;
}

class KeepCardPhoto extends CardPhotoChange {
  const KeepCardPhoto();
}

class SetCardPhoto extends CardPhotoChange {
  const SetCardPhoto(this.sourcePath);

  /// Path to the picked image file to import into app storage.
  final String sourcePath;
}

class ClearCardPhoto extends CardPhotoChange {
  const ClearCardPhoto();
}

/// Abstraction over per-watch service & warranty reminders (M6 — issue #16).
///
/// Records are returned soonest-due first. Warranty-card photos are copied into
/// app storage on write and removed when the record is deleted or its photo is
/// replaced/cleared, so a row's image file is always managed alongside the row.
abstract interface class ServiceRecordRepository {
  /// All records for [watchId], soonest due first.
  Future<List<ServiceRecord>> getRecordsForWatch(String watchId);

  /// Every record across the collection, soonest due first — used to rebuild
  /// reminder notifications.
  Future<List<ServiceRecord>> getAllRecords();

  /// The record with the given [id], or null if none exists.
  Future<ServiceRecord?> getRecord(String id);

  /// Adds a new record to [watchId] and returns its generated id. When
  /// [cardPhotoSourcePath] is non-null the image is imported into app storage.
  Future<String> addRecord(
    String watchId, {
    required ServiceRecordType type,
    required DateTime dueDate,
    String? note,
    String? cardPhotoSourcePath,
  });

  /// Updates the record [id]. [cardPhoto] controls whether the warranty-card
  /// image is kept, replaced, or removed. A no-op if no record with that id
  /// exists.
  Future<void> updateRecord(
    String id, {
    required ServiceRecordType type,
    required DateTime dueDate,
    String? note,
    CardPhotoChange cardPhoto = const CardPhotoChange.keep(),
  });

  /// Deletes the record with the given [id], removing any attached card photo.
  /// A no-op if none exists.
  Future<void> deleteRecord(String id);
}
