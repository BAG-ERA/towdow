// Styled tab bar widget with rounded tabs and background colors for selected state
// Features width that fits content and improved padding
// Uses FlowIt primary color system for consistent theming
// Responsive padding reduces vertical space on mobile while preserving icon-only inactive tabs

import 'package:flutter/material.dart';
import '../../../core/theme/chart_theme.dart';

class StyledTabItem {
  final String label;
  final IconData? icon;
  final bool isDisabled;

  const StyledTabItem({
    required this.label,
    this.icon,
    this.isDisabled = false,
  });
}

class StyledTabBar extends StatelessWidget {
  final List<StyledTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final EdgeInsets? padding; // Made nullable to enable responsive padding
  final double tabSpacing;
  final Duration animationDuration;
  final EdgeInsets? tabPadding; // Made nullable to enable responsive padding
  final bool enableResponsiveMode;

  const StyledTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabSelected,
    this.padding, // No default value - will be calculated responsively
    this.tabSpacing = 8.0,
    this.animationDuration = const Duration(milliseconds: 200),
    this.tabPadding, // No default value - will be calculated responsively
    this.enableResponsiveMode = true,
  });

  /// Gets responsive padding based on screen size
  EdgeInsets _getResponsivePadding(BuildContext context) {
    if (padding != null) return padding!;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600; // Mobile breakpoint
    
    return EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: isMobile ? 6.0 : 12.0, // Reduced vertical padding on mobile
    );
  }

  /// Gets responsive tab padding based on screen size
  EdgeInsets _getResponsiveTabPadding(BuildContext context) {
    if (tabPadding != null) return tabPadding!;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600; // Mobile breakpoint
    
    return EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: isMobile ? 6.0 : 10.0, // Reduced vertical padding on mobile
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chartTheme = context.chartTheme; // Access FlowIt chart theme for enhanced color consistency
    final responsivePadding = _getResponsivePadding(context);

    return Padding(
      padding: responsivePadding,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: enableResponsiveMode
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth - 8.0; // Account for container padding
                      final shouldUseCompactMode = _shouldUseCompactMode(context, availableWidth);
                      
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(items.length, (index) {
                            return _buildTab(
                              context,
                              index,
                              shouldUseCompactMode,
                              colorScheme,
                              chartTheme,
                            );
                          }),
                        ),
                      );
                    },
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(items.length, (index) {
                        return _buildTab(
                          context,
                          index,
                          false, // Never use compact mode when responsive is disabled
                          colorScheme,
                          chartTheme,
                        );
                      }),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Determines if compact mode should be used based on available width
  bool _shouldUseCompactMode(BuildContext context, double availableWidth) {
    if (!enableResponsiveMode) return false;
    
    final responsiveTabPadding = _getResponsiveTabPadding(context);
    
    // Estimate the width needed for all tabs with full text
    double estimatedFullWidth = 0;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      
      // Estimate text width (rough calculation)
      final textWidth = _estimateTextWidth(context, item.label);
      
      // Add icon width if present
      final iconWidth = item.icon != null ? 18.0 + 8.0 : 0; // icon + spacing
      
      // Add padding
      final totalTabWidth = responsiveTabPadding.horizontal + iconWidth + textWidth;
      
      estimatedFullWidth += totalTabWidth;
      
      // Add spacing between tabs
      if (i < items.length - 1) {
        estimatedFullWidth += tabSpacing;
      }
    }
    
    // Use compact mode if estimated width exceeds available width
    return estimatedFullWidth > availableWidth;
  }

  /// Estimates text width for a given string
  double _estimateTextWidth(BuildContext context, String text) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.size.width;
  }

  /// Builds an individual tab with responsive behavior
  /// Uses exact FlowIt primary color (#192440) for selected state
  Widget _buildTab(
    BuildContext context,
    int index,
    bool useCompactMode,
    ColorScheme colorScheme,
    ChartTheme chartTheme,
  ) {
    final item = items[index];
    final isSelected = index == selectedIndex;
    final isDisabled = item.isDisabled;
    final showText = isSelected || !useCompactMode;
    final responsiveTabPadding = _getResponsiveTabPadding(context);

    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOut,
      margin: EdgeInsets.only(
        right: index < items.length - 1 ? tabSpacing : 0,
      ),
      decoration: BoxDecoration(
        // Use exact FlowIt primary color instead of generated colorScheme.primary
        color: isSelected
            ? FlowItColors.primary // Directly use FlowIt blue dark (#192440)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  // Use exact FlowIt primary color for shadow
                  color: FlowItColors.primary.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : () => onTabSelected(index),
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: showText
                ? responsiveTabPadding
                : EdgeInsets.symmetric(
                    horizontal: responsiveTabPadding.horizontal * 0.6, // Reduced padding for icon-only
                    vertical: responsiveTabPadding.vertical,
                  ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.icon != null) ...[
                  AnimatedSwitcher(
                    duration: animationDuration,
                    child: Icon(
                      item.icon,
                      key: ValueKey('$index-$isSelected-$showText'),
                      size: 18,
                      // Use white for good contrast against FlowIt primary blue
                      color: isSelected
                          ? Colors.white
                          : isDisabled
                              ? colorScheme.onSurface.withValues(alpha: 0.38)
                              : colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  if (showText) const SizedBox(width: 8),
                ],
                if (showText)
                  AnimatedSwitcher(
                    duration: animationDuration,
                    child: Text(
                      item.label,
                      key: ValueKey('text-$index-$isSelected'),
                      style: TextStyle(
                        // Use white for good contrast against FlowIt primary blue
                        color: isSelected
                            ? Colors.white
                            : isDisabled
                                ? colorScheme.onSurface.withValues(alpha: 0.38)
                                : colorScheme.onSurface.withValues(alpha: 0.8),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
