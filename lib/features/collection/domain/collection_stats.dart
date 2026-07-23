import 'package:flutter/foundation.dart';

import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/wear_entry.dart';

/// Wear statistics for a single watch, derived from the wear log.
@immutable
class WatchWearStat {
  const WatchWearStat({
    required this.watch,
    required this.wearCount,
    required this.wearsThisYear,
  });

  final Watch watch;

  /// All-time number of days this watch was worn.
  final int wearCount;

  /// Number of days worn in the current calendar year.
  final int wearsThisYear;

  /// Purchase price divided by [wearCount] — how much each wearing has "cost"
  /// so far. Null when no purchase price is recorded or the watch has never
  /// been worn (division by zero has no meaning here).
  double? get costPerWear {
    final price = watch.purchasePrice;
    if (price == null || wearCount == 0) return null;
    return price / wearCount;
  }
}

/// A named bucket in a distribution (e.g. a brand or a movement type) with the
/// number of watches that fall into it.
@immutable
class CategoryCount {
  const CategoryCount(this.label, this.count);

  final String label;
  final int count;
}

/// Aggregate statistics across the whole collection (issue #9).
///
/// Pure value object computed by [computeCollectionStats] from the list of
/// watches and the full wear log — it holds no framework or data-source
/// dependency, so it can be unit-tested in isolation and rendered directly by
/// the Stats screen.
@immutable
class CollectionStats {
  const CollectionStats({
    required this.totalWatches,
    required this.totalWears,
    required this.wearsThisYear,
    required this.perWatch,
    required this.mostWorn,
    required this.leastWorn,
    required this.byBrand,
    required this.byMovement,
  });

  final int totalWatches;

  /// All-time total number of wear records across every watch.
  final int totalWears;

  /// Total wear records dated in the current calendar year.
  final int wearsThisYear;

  /// Per-watch wear stats, ordered most-worn first (ties broken by brand then
  /// model, case-insensitively).
  final List<WatchWearStat> perWatch;

  /// The most-worn watch, or null when nothing has been worn yet.
  final WatchWearStat? mostWorn;

  /// The least-worn watch, or null when there are fewer than two watches (a
  /// single watch is trivially both most and least worn, so it is not shown).
  final WatchWearStat? leastWorn;

  /// Number of watches per brand, most common first.
  final List<CategoryCount> byBrand;

  /// Number of watches per movement type, most common first. Watches with no
  /// recorded movement type fall into an "Unspecified" bucket.
  final List<CategoryCount> byMovement;

  bool get isEmpty => totalWatches == 0;
}

/// Label used for watches whose movement type was left blank.
const String kUnspecifiedMovementLabel = 'Unspecified';

/// Computes [CollectionStats] from [watches] and the full [entries] wear log.
///
/// [now] defaults to the current time and is injectable so tests can pin the
/// "this year" window deterministically.
CollectionStats computeCollectionStats(
  List<Watch> watches,
  List<WearEntry> entries, {
  DateTime? now,
}) {
  final year = (now ?? DateTime.now()).year;

  // Wear counts per watch id (all-time and this-year).
  final wearCounts = <String, int>{};
  final wearCountsThisYear = <String, int>{};
  for (final entry in entries) {
    wearCounts.update(entry.watchId, (n) => n + 1, ifAbsent: () => 1);
    if (entry.wornOn.year == year) {
      wearCountsThisYear.update(entry.watchId, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  final perWatch = [
    for (final watch in watches)
      WatchWearStat(
        watch: watch,
        wearCount: wearCounts[watch.id] ?? 0,
        wearsThisYear: wearCountsThisYear[watch.id] ?? 0,
      ),
  ]..sort((a, b) {
      final byCount = b.wearCount.compareTo(a.wearCount);
      if (byCount != 0) return byCount;
      final byBrand =
          a.watch.brand.toLowerCase().compareTo(b.watch.brand.toLowerCase());
      if (byBrand != 0) return byBrand;
      return a.watch.model.toLowerCase().compareTo(b.watch.model.toLowerCase());
    });

  final totalWears = wearCounts.values.fold<int>(0, (sum, n) => sum + n);
  final wearsThisYear =
      wearCountsThisYear.values.fold<int>(0, (sum, n) => sum + n);

  // Most worn is only meaningful once something has been worn.
  final mostWorn = (perWatch.isNotEmpty && perWatch.first.wearCount > 0)
      ? perWatch.first
      : null;
  // Least worn needs at least two watches to be distinct from most worn.
  final leastWorn = perWatch.length >= 2 ? perWatch.last : null;

  return CollectionStats(
    totalWatches: watches.length,
    totalWears: totalWears,
    wearsThisYear: wearsThisYear,
    perWatch: perWatch,
    mostWorn: mostWorn,
    leastWorn: leastWorn,
    byBrand: _distribution(
      watches.map((w) => w.brand.trim()).map(
            (b) => b.isEmpty ? 'Unspecified' : b,
          ),
    ),
    byMovement: _distribution(
      watches.map(
        (w) => w.movementType?.label ?? kUnspecifiedMovementLabel,
      ),
    ),
  );
}

/// Tallies [labels] into [CategoryCount]s, ordered by count desc then label
/// asc so ties render in a stable, readable order.
List<CategoryCount> _distribution(Iterable<String> labels) {
  final counts = <String, int>{};
  for (final label in labels) {
    counts.update(label, (n) => n + 1, ifAbsent: () => 1);
  }
  final result = [
    for (final entry in counts.entries) CategoryCount(entry.key, entry.value),
  ]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  return result;
}
