import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF2A9D8F);

  static const _lightBackground = Color(0xFFFAF6F0);
  static const _lightSurface = Color(0xFFFFFDF9);
  static const _lightSurfaceLow = Color(0xFFF5F0E8);
  static const _lightSurfaceContainer = Color(0xFFEDE6DA);

  static ThemeData get light {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    final colorScheme = baseScheme.copyWith(
      surface: _lightSurface,
      surfaceContainerHighest: _lightSurfaceContainer,
      surfaceContainerHigh: _lightSurfaceLow,
      surfaceContainer: _lightSurfaceLow,
      surfaceContainerLow: _lightSurfaceLow,
      surfaceContainerLowest: _lightBackground,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: _lightBackground,
      appBarBackground: _lightSurface,
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5EEAD4),
      brightness: Brightness.dark,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: colorScheme.surface,
      appBarBackground: colorScheme.surfaceContainer,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color appBarBackground,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
