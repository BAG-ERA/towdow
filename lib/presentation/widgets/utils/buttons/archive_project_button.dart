// Archive Project Button component
// Reusable button for archiving projects with consistent styling across the app
// Uses FlowIt typography system with automatic capitalization

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/logger.dart';
import '../../../../core/theme/chart_theme.dart';
import '../../../../data/providers/providers.dart';

class ArchiveProjectButton extends ConsumerWidget {
  /// Project path to archive (required)
  final String projectPath;
  
  /// Project display name for user feedback
  final String projectDisplayName;
  
  /// Custom button color (defaults to theme error color for archive actions)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button text (will be automatically capitalized)
  final String text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final ArchiveProjectButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// Custom callback when project is archived (optional)
  final VoidCallback? onProjectArchived;

  const ArchiveProjectButton({
    super.key,
    required this.projectPath,
    required this.projectDisplayName,
    this.backgroundColor,
    this.textColor,
    this.text = 'Archive Project',
    this.icon = Icons.archive_rounded,
    this.size = ArchiveProjectButtonSize.medium,
    this.isFullWidth = false,
    this.onProjectArchived,
  });

  /// Factory constructor for a compact archive button (commonly used in toolbars)
  factory ArchiveProjectButton.compact({
    Key? key,
    required String projectPath,
    required String projectDisplayName,
    Color? backgroundColor,
    Color? textColor,
    VoidCallback? onProjectArchived,
  }) {
    return ArchiveProjectButton(
      key: key,
      projectPath: projectPath,
      projectDisplayName: projectDisplayName,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: 'Archive',
      icon: Icons.archive_rounded,
      size: ArchiveProjectButtonSize.small,
      onProjectArchived: onProjectArchived,
    );
  }

  /// Factory constructor for a prominent archive button (commonly used in main areas)
  factory ArchiveProjectButton.prominent({
    Key? key,
    required String projectPath,
    required String projectDisplayName,
    Color? backgroundColor,
    Color? textColor,
    bool isFullWidth = false,
    VoidCallback? onProjectArchived,
  }) {
    return ArchiveProjectButton(
      key: key,
      projectPath: projectPath,
      projectDisplayName: projectDisplayName,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: 'Archive Project',
      icon: Icons.archive_rounded,
      size: ArchiveProjectButtonSize.large,
      isFullWidth: isFullWidth,
      onProjectArchived: onProjectArchived,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartTheme = context.chartTheme;
    final effectiveBackgroundColor = backgroundColor ?? chartTheme.colors.primary;
    final effectiveTextColor = textColor ?? chartTheme.typography.primaryButton.color;
    
    final buttonPadding = _getPadding(chartTheme);
    final scale = (chartTheme.typography.primaryButton.fontSize ?? 14) / 14.0;
    
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: () => _handleArchiveProject(context, ref),
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
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
          ),
          elevation: size == ArchiveProjectButtonSize.large ? 2 : 1,
        ),
      ),
    );
  }

  EdgeInsets _getPadding(ChartTheme chartTheme) {
    switch (size) {
      case ArchiveProjectButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingMedium,
          vertical: chartTheme.dimensions.paddingSmall,
        );
      case ArchiveProjectButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        );
      case ArchiveProjectButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge * 1.5,
          vertical: chartTheme.dimensions.paddingMedium * 1.2,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case ArchiveProjectButtonSize.small:
        return 16;
      case ArchiveProjectButtonSize.medium:
        return 20;
      case ArchiveProjectButtonSize.large:
        return 24;
    }
  }

  Future<void> _handleArchiveProject(BuildContext context, WidgetRef ref) async {
    try {
      AppLogger.info('ArchiveProjectButton: Archiving project $projectPath');
      
      // Get the status service from providers
      final statusService = ref.read(statusServiceProvider);
      
      // Archive the project
      final result = await statusService.archiveCalendar(projectPath);
      
      result.when(
        success: (_) {
          AppLogger.info('ArchiveProjectButton: Successfully archived project $projectPath');
          
          // Navigate away from project if currently viewing it
          if (context.mounted) {
            final currentRoute = GoRouterState.of(context).uri.path;
            if (currentRoute == '/project/${Uri.encodeComponent(projectPath)}') {
              AppLogger.info('ArchiveProjectButton: Navigating away from archived project');
              context.go('/');
            }
          }
          
          // Call optional callback
          onProjectArchived?.call();
        },
        failure: (failure) {
          AppLogger.error('ArchiveProjectButton: Failed to archive project $projectPath: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('ArchiveProjectButton: Exception while archiving project $projectPath: $e');
    }
  }

  // _handleUnarchiveProject removed as unused (unarchive is not exposed here)
}

/// Size variants for the archive project button
enum ArchiveProjectButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
} 