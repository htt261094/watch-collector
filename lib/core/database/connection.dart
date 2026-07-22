import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the on-device SQLite database backing [AppDatabase].
///
/// `drift_flutter` resolves a writable path in the app's documents directory
/// (via `path_provider`) and bundles the native SQLite libraries
/// (`sqlite3_flutter_libs`), so no platform-specific wiring is needed here.
/// The work is done lazily on first query, keeping construction cheap.
QueryExecutor openConnection() {
  return driftDatabase(name: 'watch_collection');
}
