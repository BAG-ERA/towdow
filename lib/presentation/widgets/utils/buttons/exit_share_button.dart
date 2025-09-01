// Exit Share Button component
// Reusable button for exiting shared projects with consistent styling across the app
// Uses FlowIt typography system with automatic capitalization

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/logger.dart';
import '../../../../core/result.dart';
import '../../../../core/theme/chart_theme.dart';
import '../../../../data/providers/providers.dart';

class ExitShareButton extends ConsumerWidget {
  /// Project path to exit share (required)
  final String projectPath;
  
  /// Project display name for user feedback
  final String projectDisplayName;
  
  /// Custom button color (defaults to theme error color for exit actions)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button text (will be automatically capitalized). If null, uses localized default
  final String? text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final ExitShareButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// Custom callback when project share is exited (optional)
  final VoidCallback? onShareExited;

  const ExitShareButton({
    super.key,
    required this.projectPath,
    required this.projectDisplayName,
    this.backgroundColor,
    this.textColor,
    this.text,
    this.icon = Icons.exit_to_app_rounded,
    this.size = ExitShareButtonSize.medium,
    this.isFullWidth = false,
    this.onShareExited,
  });

  /// Factory constructor for a compact exit share button (commonly used in toolbars)
  factory ExitShareButton.compact({
    Key? key,
    required String projectPath,
    required String projectDisplayName,
    Color? backgroundColor,
    Color? textColor,
    VoidCallback? onShareExited,
  }) {
    return ExitShareButton(
      key: key,
      projectPath: projectPath,
      projectDisplayName: projectDisplayName,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: null,
      icon: Icons.exit_to_app_rounded,
      size: ExitShareButtonSize.small,
      onShareExited: onShareExited,
    );
  }

  /// Factory constructor for a prominent exit share button (commonly used in main areas)
  factory ExitShareButton.prominent({
    Key? key,
    required String projectPath,
    required String projectDisplayName,
    Color? backgroundColor,
    Color? textColor,
    bool isFullWidth = false,
    VoidCallback? onShareExited,
  }) {
    return ExitShareButton(
      key: key,
      projectPath: projectPath,
      projectDisplayName: projectDisplayName,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: null,
      icon: Icons.exit_to_app_rounded,
      size: ExitShareButtonSize.large,
      isFullWidth: isFullWidth,
      onShareExited: onShareExited,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartTheme = context.chartTheme;
    final effectiveBackgroundColor = backgroundColor ?? chartTheme.colors.primary;
    
    final buttonPadding = _getPadding(chartTheme);
    final scale = (chartTheme.typography.primaryButton.fontSize ?? 14) / 14.0;
    
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton.icon(
        onPressed: () => _handleExitShare(context, ref),
        icon: icon != null ? Icon(icon, size: _getIconSize() * scale) : const SizedBox.shrink(),
        label: Text(
          (text ?? AppLocalizations.of(context)!.exitShare).toUpperCase(),
          style: chartTheme.typography.primaryButton.copyWith(
            color: effectiveBackgroundColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: effectiveBackgroundColor,
          side: BorderSide(color: effectiveBackgroundColor),
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
          ),
        ),
      ),
    );
  }

  EdgeInsets _getPadding(ChartTheme chartTheme) {
    switch (size) {
      case ExitShareButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingMedium,
          vertical: chartTheme.dimensions.paddingSmall,
        );
      case ExitShareButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        );
      case ExitShareButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge * 1.5,
          vertical: chartTheme.dimensions.paddingMedium * 1.2,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case ExitShareButtonSize.small:
        return 16;
      case ExitShareButtonSize.medium:
        return 20;
      case ExitShareButtonSize.large:
        return 24;
    }
  }

  Future<void> _handleExitShare(BuildContext context, WidgetRef ref) async {
    try {
      AppLogger.info('ExitShareButton: Exiting share for project $projectPath');
      
      // Use calendar repository delete with path directly
      final calendarRepository = ref.read(calendarRepositoryProvider);
      AppLogger.info('ExitShareButton: Got calendar repository, calling delete with path...');
      final deleteResult = await calendarRepository.delete(projectPath);
      
      AppLogger.info('ExitShareButton: calendarRepository.delete completed, processing result...');
      
      await deleteResult.when(
        success: (_) async {
          AppLogger.info('ExitShareButton: Successfully exited share for project $projectPath');
          
          // Invalidate providers to refresh UI (check if still mounted)
          if (context.mounted) {
            ref.invalidate(projectListProvider);
            ref.invalidate(activeCalendarListProvider);
          }
          
          // Navigate away from project if currently viewing it
          if (context.mounted) {
            final currentRoute = GoRouterState.of(context).uri.path;
            if (currentRoute == '/project/${Uri.encodeComponent(projectPath)}') {
              AppLogger.info('ExitShareButton: Navigating away from exited shared project');
              // Deterministic navigation after exit-share: always go to Projects
              context.go('/projects');
            }
          }
          
          // Call optional callback
          onShareExited?.call();
        },
        failure: (failure) async {
          AppLogger.error('ExitShareButton: Failed to exit share: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('ExitShareButton: Exception while exiting share for project $projectPath: $e');
    }
  }
}

/// Size variants for the exit share button
enum ExitShareButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
} 