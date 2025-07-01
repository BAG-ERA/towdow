// Chart theme constants and typography for FlowIt application
// Extends Material Design 3 theme system with chart-specific styling
// Uses FlowIt brand color palette

import 'package:flutter/material.dart';

/// FlowIt brand color palette
class FlowItColors {
  // Water Green family
  static const Color waterGreen = Color(0xFF6CBD97);
  static const Color waterGreenLight = Color(0xFFD3E6C7);
  
  // Blue family (Primary color family)
  static const Color blueDark = Color(0xFF192440);
  static const Color blue = Color(0xFF223A7B);
  static const Color blueMedium = Color(0xFF0068B3);
  static const Color blueLight = Color(0xFF85CAED);
  
  // Violet family
  static const Color violetDark = Color(0xFF463077);
  static const Color violet = Color(0xFF6A5195);
  static const Color violetLight = Color(0xFF8C89C2);
  
  // Green family
  static const Color greenApple = Color(0xFF96B522);
  static const Color greenAnis = Color(0xFFC5C741);
  static const Color greenLight = Color(0xFFD8D596);
  
  // Red/Pink family
  static const Color pink = Color(0xFFE83947);
  static const Color pinkLight = Color(0xFFEF7E6F);
  static const Color coral = Color(0xFFF6A66D);
  
  // Yellow family
  static const Color yellowDark = Color(0xFFF59E00);
  static const Color yellow = Color(0xFFFDC61E);
  static const Color yellowLight = Color(0xFFFFE37E);
  
  // Neutral colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color separator = Color(0xFFE0E0E0);
  static const Color separatorDark = Color(0xFF2C2C2C);
  
  // Primary brand color (Medium Blue)
  static const Color primary = blueMedium;
}

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

  /// Light theme chart colors using FlowIt brand palette
  factory ChartColors.light(ColorScheme colorScheme) {
    return ChartColors(
      primary: FlowItColors.primary,
      secondary: FlowItColors.waterGreen,
      tertiary: FlowItColors.violet,
      quaternary: FlowItColors.greenApple,
      success: FlowItColors.waterGreen,
      warning: FlowItColors.yellowDark,
      error: FlowItColors.pink,
      background: FlowItColors.surface,
      surface: FlowItColors.surface,
      outline: FlowItColors.separator,
      onSurface: FlowItColors.blueDark,
      onSurfaceVariant: FlowItColors.blue.withValues(alpha: 0.7),
      progressGradient: [
        FlowItColors.primary,
        FlowItColors.blueLight,
      ],
      taskStatusColors: {
        'COMPLETED': FlowItColors.waterGreen,
        'NEEDS-ACTION': FlowItColors.primary,
        'CANCELLED': FlowItColors.pink,
        'IN-PROGRESS': FlowItColors.yellowDark,
      },
    );
  }

  /// Dark theme chart colors using FlowIt brand palette
  factory ChartColors.dark(ColorScheme colorScheme) {
    return ChartColors(
      primary: FlowItColors.blueLight,
      secondary: FlowItColors.waterGreenLight,
      tertiary: FlowItColors.violetLight,
      quaternary: FlowItColors.greenLight,
      success: FlowItColors.waterGreenLight,
      warning: FlowItColors.yellow,
      error: FlowItColors.pinkLight,
      background: FlowItColors.surfaceDark,
      surface: FlowItColors.surfaceDark,
      outline: FlowItColors.separatorDark,
      onSurface: FlowItColors.surface,
      onSurfaceVariant: FlowItColors.blueLight.withValues(alpha: 0.8),
      progressGradient: [
        FlowItColors.blueLight,
        FlowItColors.primary,
      ],
      taskStatusColors: {
        'COMPLETED': FlowItColors.waterGreenLight,
        'NEEDS-ACTION': FlowItColors.blueLight,
        'CANCELLED': FlowItColors.pinkLight,
        'IN-PROGRESS': FlowItColors.yellow,
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

  /// Get a series of colors for multi-line charts using FlowIt palette
  List<Color> get chartSeries => [
    primary,           // Blue Medium
    secondary,         // Water Green (Light)
    tertiary,          // Violet (Light)
    quaternary,        // Green Apple/Light
    warning,           // Yellow Dark/Yellow
    error,             // Pink Light
    FlowItColors.coral, // Additional coral color
    FlowItColors.greenAnis, // Additional anis green
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