// Practical usage examples and patterns for ChartTheme
// Common patterns for using chart constants throughout FlowIt

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
} 