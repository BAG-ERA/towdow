// Chart theme constants and typography for FlowIt application
// Extends Material Design 3 theme system with chart-specific styling

import 'package:flutter/material.dart';

/// Chart theme extension for consistent chart styling across the app
/// Integrates with Material Design 3 color system for light/dark mode support
@immutable
class ChartTheme extends ThemeExtension<ChartTheme> {
  const ChartTheme({
    required this.colors,
    required this.typography,
    required this.dimensions,
  });

  final ChartColors colors;
  final ChartTypography typography;
  final ChartDimensions dimensions;

  /// Factory constructor for light theme
  factory ChartTheme.light(ColorScheme colorScheme) {
    return ChartTheme(
      colors: ChartColors.light(colorScheme),
      typography: const ChartTypography.light(),
      dimensions: const ChartDimensions(),
    );
  }

  /// Factory constructor for dark theme
  factory ChartTheme.dark(ColorScheme colorScheme) {
    return ChartTheme(
      colors: ChartColors.dark(colorScheme),
      typography: const ChartTypography.dark(),
      dimensions: const ChartDimensions(),
    );
  }

  @override
  ChartTheme copyWith({
    ChartColors? colors,
    ChartTypography? typography,
    ChartDimensions? dimensions,
  }) {
    return ChartTheme(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      dimensions: dimensions ?? this.dimensions,
    );
  }

  @override
  ChartTheme lerp(ThemeExtension<ChartTheme>? other, double t) {
    if (other is! ChartTheme) return this;
    return ChartTheme(
      colors: colors.lerp(other.colors, t),
      typography: typography.lerp(other.typography, t),
      dimensions: dimensions.lerp(other.dimensions, t),
    );
  }
}

/// Chart color scheme following Material Design 3 principles
@immutable
class ChartColors {
  const ChartColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.quaternary,
    required this.success,
    required this.warning,
    required this.error,
    required this.background,
    required this.surface,
    required this.outline,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.progressGradient,
    required this.taskStatusColors,
  });

  // Primary chart colors derived from Material theme
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color quaternary;

  // Semantic colors
  final Color success;
  final Color warning;
  final Color error;

  // Surface colors
  final Color background;
  final Color surface;
  final Color outline;
  final Color onSurface;
  final Color onSurfaceVariant;

  // Special chart elements
  final List<Color> progressGradient;
  final Map<String, Color> taskStatusColors;

  /// Light theme chart colors
  factory ChartColors.light(ColorScheme colorScheme) {
    return ChartColors(
      primary: colorScheme.primary,
      secondary: colorScheme.secondary,
      tertiary: colorScheme.tertiary,
      quaternary: const Color(0xFF6750A4), // Material purple
      success: const Color(0xFF4CAF50),
      warning: const Color(0xFFFF9800),
      error: colorScheme.error,
      background: colorScheme.surface,
      surface: colorScheme.surfaceContainerHighest,
      outline: colorScheme.outline,
      onSurface: colorScheme.onSurface,
      onSurfaceVariant: colorScheme.onSurfaceVariant,
      progressGradient: [
        colorScheme.primary,
        colorScheme.primaryContainer,
      ],
      taskStatusColors: {
        'COMPLETED': const Color(0xFF4CAF50),
        'NEEDS-ACTION': colorScheme.primary,
        'CANCELLED': colorScheme.error,
        'IN-PROGRESS': const Color(0xFFFF9800),
      },
    );
  }

  /// Dark theme chart colors
  factory ChartColors.dark(ColorScheme colorScheme) {
    return ChartColors(
      primary: colorScheme.primary,
      secondary: colorScheme.secondary,
      tertiary: colorScheme.tertiary,
      quaternary: const Color(0xFFD0BCFF), // Material purple dark
      success: const Color(0xFF81C784),
      warning: const Color(0xFFFFB74D),
      error: colorScheme.error,
      background: colorScheme.surface,
      surface: colorScheme.surfaceContainerHighest,
      outline: colorScheme.outline,
      onSurface: colorScheme.onSurface,
      onSurfaceVariant: colorScheme.onSurfaceVariant,
      progressGradient: [
        colorScheme.primary,
        colorScheme.primaryContainer,
      ],
      taskStatusColors: {
        'COMPLETED': const Color(0xFF81C784),
        'NEEDS-ACTION': colorScheme.primary,
        'CANCELLED': colorScheme.error,
        'IN-PROGRESS': const Color(0xFFFFB74D),
      },
    );
  }

  /// Interpolate between two ChartColors
  ChartColors lerp(ChartColors other, double t) {
    return ChartColors(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      quaternary: Color.lerp(quaternary, other.quaternary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      progressGradient: progressGradient.map((color) => 
        Color.lerp(color, other.progressGradient[progressGradient.indexOf(color)], t)!
      ).toList(),
      taskStatusColors: taskStatusColors.map((key, color) => 
        MapEntry(key, Color.lerp(color, other.taskStatusColors[key], t)!)
      ),
    );
  }

  /// Get a series of colors for multi-line charts
  List<Color> get chartSeries => [
    primary,
    secondary,
    tertiary,
    quaternary,
    success,
    warning,
  ];
}

/// Chart typography following Material Design 3 type scale
@immutable
class ChartTypography {
  const ChartTypography({
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.bodyMedium,
    required this.bodySmall,
  });

  // Chart titles and headers
  final TextStyle titleLarge;   // Chart main title
  final TextStyle titleMedium;  // Section titles
  final TextStyle titleSmall;   // Legend headers

  // Chart labels and data
  final TextStyle labelLarge;   // Axis labels
  final TextStyle labelMedium;  // Data point labels
  final TextStyle labelSmall;   // Tooltips and annotations

  // Chart content
  final TextStyle bodyMedium;   // General text
  final TextStyle bodySmall;    // Secondary text

  /// Light theme typography
  const ChartTypography.light() : this(
    titleLarge: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Color(0xFF1C1B1F),
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: Color(0xFF1C1B1F),
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: Color(0xFF1C1B1F),
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Color(0xFF49454F),
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFF49454F),
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFF49454F),
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: Color(0xFF1C1B1F),
    ),
    bodySmall: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: Color(0xFF49454F),
    ),
  );

  /// Dark theme typography
  const ChartTypography.dark() : this(
    titleLarge: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: Color(0xFFE6E1E5),
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
      color: Color(0xFFE6E1E5),
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: Color(0xFFE6E1E5),
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Color(0xFFCAC4D0),
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFFCAC4D0),
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      color: Color(0xFFCAC4D0),
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
      color: Color(0xFFE6E1E5),
    ),
    bodySmall: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
      color: Color(0xFFCAC4D0),
    ),
  );

  /// Interpolate between two ChartTypography
  ChartTypography lerp(ChartTypography other, double t) {
    return ChartTypography(
      titleLarge: TextStyle.lerp(titleLarge, other.titleLarge, t)!,
      titleMedium: TextStyle.lerp(titleMedium, other.titleMedium, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      labelLarge: TextStyle.lerp(labelLarge, other.labelLarge, t)!,
      labelMedium: TextStyle.lerp(labelMedium, other.labelMedium, t)!,
      labelSmall: TextStyle.lerp(labelSmall, other.labelSmall, t)!,
      bodyMedium: TextStyle.lerp(bodyMedium, other.bodyMedium, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
    );
  }
}

/// Chart dimensions and spacing constants
@immutable
class ChartDimensions {
  const ChartDimensions({
    this.paddingSmall = 8.0,
    this.paddingMedium = 16.0,
    this.paddingLarge = 24.0,
    this.cornerRadius = 12.0,
    this.strokeWidth = 2.0,
    this.dotRadius = 4.0,
    this.legendItemSpacing = 12.0,
    this.axisLabelPadding = 8.0,
    this.chartMinHeight = 200.0,
    this.chartMaxHeight = 400.0,
  });

  // Spacing and padding
  final double paddingSmall;
  final double paddingMedium;
  final double paddingLarge;

  // Visual elements
  final double cornerRadius;
  final double strokeWidth;
  final double dotRadius;

  // Layout specific
  final double legendItemSpacing;
  final double axisLabelPadding;
  final double chartMinHeight;
  final double chartMaxHeight;

  /// Interpolate between two ChartDimensions
  ChartDimensions lerp(ChartDimensions other, double t) {
    return ChartDimensions(
      paddingSmall: _lerpDouble(paddingSmall, other.paddingSmall, t),
      paddingMedium: _lerpDouble(paddingMedium, other.paddingMedium, t),
      paddingLarge: _lerpDouble(paddingLarge, other.paddingLarge, t),
      cornerRadius: _lerpDouble(cornerRadius, other.cornerRadius, t),
      strokeWidth: _lerpDouble(strokeWidth, other.strokeWidth, t),
      dotRadius: _lerpDouble(dotRadius, other.dotRadius, t),
      legendItemSpacing: _lerpDouble(legendItemSpacing, other.legendItemSpacing, t),
      axisLabelPadding: _lerpDouble(axisLabelPadding, other.axisLabelPadding, t),
      chartMinHeight: _lerpDouble(chartMinHeight, other.chartMinHeight, t),
      chartMaxHeight: _lerpDouble(chartMaxHeight, other.chartMaxHeight, t),
    );
  }

  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

/// Extension to easily access chart theme from context
extension ChartThemeExtension on BuildContext {
  ChartTheme get chartTheme {
    return Theme.of(this).extension<ChartTheme>() ?? 
           ChartTheme.light(Theme.of(this).colorScheme);
  }
} 