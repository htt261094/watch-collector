import 'dart:math';

/// Generates opaque, reasonably-unique string ids for locally-created rows.
///
/// The app is fully offline and single-user, so ids only need to be unique
/// within one device's database — not globally. We combine a monotonic-ish
/// timestamp (microseconds) with random bits to make collisions effectively
/// impossible in practice without pulling in a UUID dependency.
abstract final class IdGenerator {
  static final Random _random = Random();

  /// Returns a new id such as `1706006400000000-4f2a9c`.
  static String newId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final suffix = _random.nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
    return '$micros-$suffix';
  }
}
