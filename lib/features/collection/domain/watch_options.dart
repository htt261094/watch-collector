/// Predefined option lists that power the quick-entry suggestions in the
/// Add/Edit Watch form (issue #3).
///
/// These are *suggestions*, not a closed vocabulary: the movement type is
/// constrained to [MovementType], but case material is free text with these
/// values offered as autocomplete hints, and complications are picked from
/// [commonComplications] while still allowing custom entries.
abstract final class WatchOptions {
  /// Common case materials offered as autocomplete suggestions.
  static const List<String> caseMaterials = [
    'Stainless steel',
    'Titanium',
    'Gold',
    'Rose gold',
    'White gold',
    'Platinum',
    'Ceramic',
    'Bronze',
    'Carbon',
    'Aluminium',
    'PVD-coated steel',
  ];

  /// The maximum number of complications a watch may have (issue #3 spec).
  static const int maxComplications = 6;

  /// Commonly seen complications offered in the multi-select picker.
  static const List<String> commonComplications = [
    'Date',
    'Day-date',
    'GMT',
    'Chronograph',
    'Moonphase',
    'Power reserve indicator',
    'Annual calendar',
    'Perpetual calendar',
    'Tourbillon',
    'World time',
    'Alarm',
    'Small seconds',
  ];
}
