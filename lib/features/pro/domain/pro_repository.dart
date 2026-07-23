/// Free-tier limit: the number of watches a user may keep without Pro.
///
/// The brief (§4.1, §9) caps the free plan at 3–5 watches; we use the upper
/// bound so the free experience feels generous while still surfacing the
/// paywall for larger collections.
const int freeWatchLimit = 5;

/// Whether a collection of [watchCount] watches may add another watch given the
/// current Pro status. Pro unlocks an unlimited collection; free users are
/// capped at [freeWatchLimit].
bool canAddWatch({required int watchCount, required bool proUnlocked}) {
  if (proUnlocked) return true;
  return watchCount < freeWatchLimit;
}

/// Abstraction over the Pro-entitlement flag.
///
/// The flag is persisted in app settings (`pro_unlocked`). Concrete
/// implementations live in the data layer, keeping the storage choice
/// (local-only, offline) an implementation detail. Purchase/restore wiring is
/// out of scope for the MVP gate — [setProUnlocked] stands in for the eventual
/// billing callback.
abstract interface class ProRepository {
  /// Reads the persisted `pro_unlocked` flag. Defaults to `false` when unset.
  Future<bool> isProUnlocked();

  /// Persists the `pro_unlocked` flag.
  Future<void> setProUnlocked(bool value);
}
