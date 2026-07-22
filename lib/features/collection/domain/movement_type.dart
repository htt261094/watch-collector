/// The kind of movement powering a watch.
///
/// The [storageValue] is the stable string persisted in the database
/// (`movement_type` column); [label] is the human-readable text shown in the
/// UI. Keeping the two separate lets us tweak wording without a migration.
enum MovementType {
  auto('auto', 'Automatic'),
  manual('manual', 'Manual'),
  quartz('quartz', 'Quartz'),
  other('other', 'Other');

  const MovementType(this.storageValue, this.label);

  final String storageValue;
  final String label;

  /// Resolves a persisted [storageValue] back to an enum, or `null` when the
  /// value is missing or unrecognised.
  static MovementType? fromStorage(String? value) {
    if (value == null) return null;
    for (final type in MovementType.values) {
      if (type.storageValue == value) return type;
    }
    return null;
  }
}
