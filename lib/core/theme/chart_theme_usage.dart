// Practical usage examples and patterns for ChartTheme
// Common patterns for using chart constants throughout FlowIt
// Includes typography helpers for Roboto Flex system

import 'package:flutter/material.dart';
import 'chart_theme.dart';

/// Common chart theme usage patterns for FlowIt
class ChartThemeUsage {
  
  /// Task status visualization colors
  static Color getTaskStatusColor(BuildContext context, String status) {
    final chartTheme = context.chartTheme;
    return chartTheme.colors.taskStatusColors[status] ?? 
           chartTheme.colors.onSurfaceVariant;
  }
  
  /// Primary button text with automatic capitalization
  /// Use this for Create, Add Task, and other primary action buttons
  static Widget buildPrimaryButtonText(
    BuildContext context, 
    String text, {
    Color? textColor,
  }) {
    final chartTheme = context.chartTheme;
    return Text(
      text.toUpperCase(), // Automatic capitalization as requested
      style: chartTheme.typography.primaryButton.copyWith(
        color: textColor ?? chartTheme.typography.primaryButton.color,
      ),
    );
  }
  
  /// Domain name text with Roboto Serif thin styling
  static Widget buildDomainNameText(
    BuildContext context, 
    String domainName, {
    Color? textColor,
  }) {
    final chartTheme = context.chartTheme;
    return Text(
      domainName,
      style: chartTheme.typography.domainName.copyWith(
        color: textColor ?? chartTheme.typography.domainName.color,
      ),
    );
  }
  
  /// Primary action button with FlowIt styling
  static Widget buildPrimaryButton(
    BuildContext context, {
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    Widget? icon,
  }) {
    final chartTheme = context.chartTheme;
    
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading 
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                chartTheme.typography.primaryButton.color!,
              ),
            ),
          )
        : (icon ?? const SizedBox.shrink()),
      label: buildPrimaryButtonText(context, text),
      style: ElevatedButton.styleFrom(
        backgroundColor: chartTheme.colors.primary,
        foregroundColor: chartTheme.typography.primaryButton.color,
        padding: EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
        ),
      ),
    );
  }

  /// Progress bar with theme colors
  static Widget buildProgressBar(
    BuildContext context, {
    required double progress,
    double? width,
    double? height,
  }) {
    final chartTheme = context.chartTheme;
    
    return Container(
      width: width ?? double.infinity,
      height: height ?? 8.0,
      decoration: BoxDecoration(
        color: chartTheme.colors.surface,
        borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            chartTheme.colors.primary,
          ),
        ),
      ),
    );
  }
  
  /// Chart container with consistent styling
  static Widget chartContainer(
    BuildContext context, {
    required Widget child,
    String? title,
    double? height,
  }) {
    final chartTheme = context.chartTheme;
    
    return Container(
      height: height,
      padding: EdgeInsets.all(chartTheme.dimensions.paddingMedium),
      decoration: BoxDecoration(
        color: chartTheme.colors.surface,
        borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
        border: Border.all(
          color: chartTheme.colors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: chartTheme.typography.titleMedium),
            SizedBox(height: chartTheme.dimensions.paddingMedium),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
  
  /// Legend item widget
  static Widget legendItem(
    BuildContext context, {
    required Color color,
    required String label,
    String? value,
  }) {
    final chartTheme = context.chartTheme;
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: chartTheme.dimensions.paddingSmall),
        Expanded(
          child: Text(
            label,
            style: chartTheme.typography.bodySmall,
          ),
        ),
        if (value != null)
          Text(
            value,
            style: chartTheme.typography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Pre-configured chart styles for common FlowIt use cases
class FlowItChartStyles {
  
  /// Task completion status chart configuration using FlowIt colors
  static Map<String, ChartStyle> get taskStatusStyles {
    return {
      'COMPLETED': const ChartStyle(
        color: FlowItColors.waterGreen,
        icon: Icons.check_circle,
        label: 'Completed',
      ),
      'NEEDS-ACTION': const ChartStyle(
        color: FlowItColors.primary,
        icon: Icons.radio_button_unchecked,
        label: 'To Do',
      ),
      'IN-PROGRESS': const ChartStyle(
        color: FlowItColors.yellowDark,
        icon: Icons.timelapse,
        label: 'In Progress',
      ),
      'CANCELLED': const ChartStyle(
        color: FlowItColors.pink,
        icon: Icons.cancel,
        label: 'Cancelled',
      ),
    };
  }
  
  /// Project priority chart configuration using FlowIt colors
  static Map<String, ChartStyle> get priorityStyles {
    return {
      'HIGH': const ChartStyle(
        color: FlowItColors.pink,
        icon: Icons.priority_high,
        label: 'High Priority',
      ),
      'MEDIUM': const ChartStyle(
        color: FlowItColors.yellowDark,
        icon: Icons.remove,
        label: 'Medium Priority',
      ),
      'LOW': const ChartStyle(
        color: FlowItColors.waterGreen,
        icon: Icons.keyboard_arrow_down,
        label: 'Low Priority',
      ),
    };
  }
}

/// Chart style configuration
@immutable
class ChartStyle {
  const ChartStyle({
    required this.color,
    required this.icon,
    required this.label,
  });
  
  final Color color;
  final IconData icon;
  final String label;
}

/// Quick access methods for common chart operations
extension QuickChartAccess on BuildContext {
  
  /// Quick access to chart colors
  ChartColors get chartColors => chartTheme.colors;
  
  /// Quick access to chart typography
  ChartTypography get chartTypography => chartTheme.typography;
  
  /// Quick access to chart dimensions
  ChartDimensions get chartDimensions => chartTheme.dimensions;
  
  /// Get task status color quickly
  Color taskStatusColor(String status) =>
      ChartThemeUsage.getTaskStatusColor(this, status);
      
  /// Quick access to primary button text style
  TextStyle get primaryButtonStyle => chartTheme.typography.primaryButton;
  
  /// Quick access to domain name text style
  TextStyle get domainNameStyle => chartTheme.typography.domainName;
  
  /// Create primary button text widget with automatic capitalization
  Widget primaryButtonText(String text, {Color? color}) =>
      ChartThemeUsage.buildPrimaryButtonText(this, text, textColor: color);
      
  /// Create domain name text widget with Roboto Serif styling
  Widget domainNameText(String text, {Color? color}) =>
      ChartThemeUsage.buildDomainNameText(this, text, textColor: color);
} 