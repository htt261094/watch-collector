import 'package:flutter/material.dart';

/// Centralised Material 3 theme configuration for the app.
///
/// Light and dark variants are derived from a single seed colour so the whole
/// app stays visually consistent. Theme tokens live here rather than being
/// scattered across widgets.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF1F5C8B);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}
