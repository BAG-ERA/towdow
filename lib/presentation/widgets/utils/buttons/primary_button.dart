// Primary Button component
// Reusable base button for all primary actions with consistent styling across the app
// Uses FlowIt typography system with automatic capitalization
// Provides common functionality for create, archive, and other primary action buttons

import 'package:flutter/material.dart';
import '../../../../core/theme/chart_theme.dart';

class PrimaryButton extends StatelessWidget {
  /// Button text (will be automatically capitalized)
  final String text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final PrimaryButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// Custom button color (defaults to theme primary color)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button elevation (defaults based on size)
  final double? elevation;
  
  /// Custom padding (defaults based on size)
  final EdgeInsets? padding;
  
  /// Custom border radius (defaults to theme corner radius)
  final double? borderRadius;
  
  /// Callback when button is pressed
  final VoidCallback? onPressed;
  
  /// Whether the button is enabled
  final bool enabled;

  const PrimaryButton({
    super.key,
    required this.text,
    this.icon,
    this.size = PrimaryButtonSize.medium,
    this.isFullWidth = false,
    this.backgroundColor,
    this.textColor,
    this.elevation,
    this.padding,
    this.borderRadius,
    this.onPressed,
    this.enabled = true,
  });

  /// Factory constructor for a compact button (commonly used in toolbars)
  factory PrimaryButton.compact({
    Key? key,
    required String text,
    IconData? icon,
    Color? backgroundColor,
    Color? textColor,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return PrimaryButton(
      key: key,
      text: text,
      icon: icon,
      size: PrimaryButtonSize.small,
      backgroundColor: backgroundColor,
      textColor: textColor,
      onPressed: onPressed,
      enabled: enabled,
    );
  }

  /// Factory constructor for a prominent button (commonly used in main areas)
  factory PrimaryButton.prominent({
    Key? key,
    required String text,
    IconData? icon,
    bool isFullWidth = false,
    Color? backgroundColor,
    Color? textColor,
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return PrimaryButton(
      key: key,
      text: text,
      icon: icon,
      size: PrimaryButtonSize.large,
      isFullWidth: isFullWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      onPressed: onPressed,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartTheme = context.chartTheme;
    final effectiveBackgroundColor = backgroundColor ?? chartTheme.colors.primary;
    final effectiveTextColor = textColor ?? chartTheme.typography.primaryButton.color;
    final effectiveElevation = elevation ?? (size == PrimaryButtonSize.large ? 2.0 : 1.0);
    final effectiveBorderRadius = borderRadius ?? chartTheme.dimensions.cornerRadius;
    final effectivePadding = padding ?? _getPadding(chartTheme);
    
    final scale = (chartTheme.typography.primaryButton.fontSize ?? 14) / 14.0;
    
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: icon != null ? Icon(icon, size: _getIconSize() * scale) : const SizedBox.shrink(),
        label: Text(
          text.toUpperCase(), // Automatic capitalization as per FlowIt typography system
          style: chartTheme.typography.primaryButton.copyWith(
            color: effectiveTextColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          padding: effectivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(effectiveBorderRadius),
          ),
          elevation: effectiveElevation,
        ),
      ),
    );
  }

  EdgeInsets _getPadding(ChartTheme chartTheme) {
    switch (size) {
      case PrimaryButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingMedium,
          vertical: chartTheme.dimensions.paddingSmall,
        );
      case PrimaryButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        );
      case PrimaryButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge * 1.5,
          vertical: chartTheme.dimensions.paddingMedium * 1.2,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case PrimaryButtonSize.small:
        return 16;
      case PrimaryButtonSize.medium:
        return 20;
      case PrimaryButtonSize.large:
        return 24;
    }
  }
}

/// Size variants for the primary button
enum PrimaryButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
}
