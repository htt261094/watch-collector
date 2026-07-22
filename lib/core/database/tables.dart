import 'package:drift/drift.dart';

/// Local database schema for the watch collection (drift / SQLite).
///
/// Design notes:
/// - Primary keys are opaque `TEXT` ids (UUID strings) so rows can be created
///   client-side and stay stable across export/backup without relying on
///   autoincrement counters.
/// - Photos are stored as files in app storage; the database only keeps the
///   file **path**, never the binary. See [WatchPhotos].
/// - Every child table references [Watches] with `ON DELETE CASCADE`, so
///   deleting a watch removes all of its photos, logs, measurements, etc.
/// - Generated row data classes are given a `Row` suffix (via
///   [DataClassName]) to keep them clearly distinct from the pure domain
///   entities in `features/*/domain`.

/// The catalog of watches — one row per watch in the collection.
@DataClassName('WatchRow')
class Watches extends Table {
  TextColumn get id => text()();

  TextColumn get brand => text().withLength(min: 1, max: 120)();
  TextColumn get model => text().withLength(min: 1, max: 120)();
  TextColumn get referenceNo => text().nullable()();
  TextColumn get serialNo => text().nullable()();

  /// One of `auto` / `manual` / `quartz` / `other` (validated in the app layer).
  TextColumn get movementType => text().nullable()();
  TextColumn get caliber => text().nullable()();

  /// Power reserve in hours.
  IntColumn get powerReserve => integer().nullable()();

  /// Beat rate in vibrations per hour.
  IntColumn get vph => integer().nullable()();

  /// Case dimensions in millimetres.
  RealColumn get diameter => real().nullable()();
  RealColumn get lugWidth => real().nullable()();
  RealColumn get thickness => real().nullable()();

  TextColumn get caseMaterial => text().nullable()();

  DateTimeColumn get purchaseDate => dateTime().nullable()();

  /// Purchase price in the smallest currency unit is avoided here; stored as a
  /// plain amount. Currency handling is out of scope for M1.
  RealColumn get purchasePrice => real().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Multiple photos per watch. Exactly one may be flagged [isThumbnail] to act
/// as the representative image on the gallery/home screen.
@DataClassName('WatchPhotoRow')
class WatchPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get watchId =>
      text().references(Watches, #id, onDelete: KeyAction.cascade)();

  /// Path to the image file inside the app's storage directory.
  TextColumn get filePath => text()();
  BoolColumn get isThumbnail => boolean().withDefault(const Constant(false))();

  /// Manual ordering within a watch's gallery.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Complications belonging to a watch (max 6 enforced in the app layer).
@DataClassName('ComplicationRow')
class Complications extends Table {
  TextColumn get id => text()();
  TextColumn get watchId =>
      text().references(Watches, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A record that a watch was worn on a given day (M2 — wear tracking).
@DataClassName('WearLogRow')
class WearLogs extends Table {
  TextColumn get id => text()();
  TextColumn get watchId =>
      text().references(Watches, #id, onDelete: KeyAction.cascade)();

  /// The day the watch was worn (time component is not significant).
  DateTimeColumn get wornOn => dateTime()();
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Accuracy measurement sessions (M4). A session opens with a reference offset
/// at [startTime]; when it is ended the offset at [endTime] is recorded and
/// [computedSpd] (seconds per day) is derived. Open sessions leave the `end*`
/// columns null.
@DataClassName('AccuracyMeasurementRow')
class AccuracyMeasurements extends Table {
  TextColumn get id => text()();
  TextColumn get watchId =>
      text().references(Watches, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get startTime => dateTime()();

  /// Offset (in seconds) of the watch vs. the time reference at start.
  IntColumn get startReferenceOffset => integer()();

  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get endReferenceOffset => integer().nullable()();

  /// Derived seconds-per-day deviation once the session is closed.
  RealColumn get computedSpd => real().nullable()();

  /// Optional resting position (e.g. `dial up`, `crown down`).
  TextColumn get position => text().nullable()();

  /// Whether the measurement is considered valid; if not, [invalidReason]
  /// explains why (e.g. session too short, reference changed).
  BoolColumn get isValid => boolean().withDefault(const Constant(true))();
  TextColumn get invalidReason => text().nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Arbitrary key-value attributes attached to a watch (M5 — custom fields).
@DataClassName('CustomFieldRow')
class CustomFields extends Table {
  TextColumn get id => text()();
  TextColumn get watchId =>
      text().references(Watches, #id, onDelete: KeyAction.cascade)();

  TextColumn get fieldKey => text()();
  TextColumn get fieldValue => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Service / maintenance history for a watch (M6 — service & rotation).
@DataClassName('ServiceRecordRow')
class ServiceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get watchId =>
      text().references(Watches, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get serviceDate => dateTime()();
  TextColumn get serviceType => text().nullable()();
  TextColumn get provider => text().nullable()();
  RealColumn get cost => real().nullable()();
  DateTimeColumn get nextServiceDate => dateTime().nullable()();
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Application-level key-value settings (single row per key).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
