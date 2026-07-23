import 'package:flutter/foundation.dart';

import 'package:watch_collection/features/collection/domain/watch.dart';
import 'package:watch_collection/features/collection/domain/wear_entry.dart';

/// A single "wear this next" recommendation for one watch (issue #17).
///
/// Pure value object describing how neglected a watch is: when it was last
/// worn, how long ago that was, and how many times it has been worn all-time.
/// The Stats and Home screens render these to nudge the owner toward watches
/// that have been sitting idle.
@immutable
class RotationSuggestion {
  const RotationSuggestion({
    required this.watch,
    required this.wearCount,
    required this.lastWornOn,
    required this.daysSinceLastWorn,
  });

  final Watch watch;

  /// All-time number of days this watch was worn.
  final int wearCount;

  /// The most recent day the watch was worn, or null if it never has been.
  final DateTime? lastWornOn;

  /// Whole days between [lastWornOn] and "today", or null when the watch has
  /// never been worn (there is no last-worn day to measure from).
  final int? daysSinceLastWorn;

  /// Whether the watch has no wear records at all — the most neglected case.
  bool get neverWorn => lastWornOn == null;
}

/// Ranks [watches] by how overdue they are for a wearing, most neglected first
/// (issue #17).
///
/// The recommendation is "smart" in that it blends two signals rather than a
/// single count: how long a watch has sat idle (recency) and how rarely it is
/// worn overall (frequency). Watches never worn rank above everything, then
/// those idle longest, with all-time wear count breaking ties so an evenly
/// idle pair still favours the less-loved piece. Brand then model give a stable
/// final order.
///
/// Watches worn today are dropped — there is nothing to suggest about a watch
/// already on the wrist. Collections with fewer than two candidates return an
/// empty list, since a lone watch is a trivial, unhelpful "suggestion".
///
/// [now] defaults to the current time and is injectable so tests can pin the
/// day window deterministically. [limit], when given, caps the number of
/// suggestions returned (the highest-ranked ones).
List<RotationSuggestion> computeRotationSuggestions(
  List<Watch> watches,
  List<WearEntry> entries, {
  DateTime? now,
  int? limit,
}) {
  final today = _dayOf(now ?? DateTime.now());

  // All-time wear count and most-recent wear day per watch id.
  final wearCounts = <String, int>{};
  final lastWorn = <String, DateTime>{};
  for (final entry in entries) {
    wearCounts.update(entry.watchId, (n) => n + 1, ifAbsent: () => 1);
    final day = _dayOf(entry.wornOn);
    lastWorn.update(
      entry.watchId,
      (current) => day.isAfter(current) ? day : current,
      ifAbsent: () => day,
    );
  }

  final suggestions = <RotationSuggestion>[];
  for (final watch in watches) {
    final last = lastWorn[watch.id];
    final daysSince = last == null ? null : today.difference(last).inDays;
    // Skip watches already worn today; they need no suggesting.
    if (daysSince == 0) continue;
    suggestions.add(
      RotationSuggestion(
        watch: watch,
        wearCount: wearCounts[watch.id] ?? 0,
        lastWornOn: last,
        daysSinceLastWorn: daysSince,
      ),
    );
  }

  // A single candidate makes for a pointless recommendation.
  if (suggestions.length < 2) return const [];

  suggestions.sort((a, b) {
    // Never-worn watches are the most overdue; among the worn, longest-idle
    // first. Treat "never worn" as an infinitely large idle gap.
    final aIdle = a.daysSinceLastWorn ?? _infinite;
    final bIdle = b.daysSinceLastWorn ?? _infinite;
    final byIdle = bIdle.compareTo(aIdle);
    if (byIdle != 0) return byIdle;

    final byCount = a.wearCount.compareTo(b.wearCount);
    if (byCount != 0) return byCount;

    final byBrand =
        a.watch.brand.toLowerCase().compareTo(b.watch.brand.toLowerCase());
    if (byBrand != 0) return byBrand;
    return a.watch.model.toLowerCase().compareTo(b.watch.model.toLowerCase());
  });

  if (limit != null && limit < suggestions.length) {
    return List.unmodifiable(suggestions.sublist(0, limit));
  }
  return List.unmodifiable(suggestions);
}

/// Sentinel idle gap for never-worn watches, larger than any real day count.
const int _infinite = 1 << 31;

DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
