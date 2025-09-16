// Archive Project Button component
// Reusable button for archiving projects with consistent styling across the app
// Uses PrimaryButton for consistent styling and behavior

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/logger.dart';
import '../../../../core/result.dart';
import '../../../../data/providers/providers.dart';
import 'primary_button.dart';

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
  final PrimaryButtonSize size;
  
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
    this.size = PrimaryButtonSize.medium,
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
      size: PrimaryButtonSize.small,
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
      size: PrimaryButtonSize.large,
      isFullWidth: isFullWidth,
      onProjectArchived: onProjectArchived,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrimaryButton(
      text: text,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      onPressed: () => _handleArchiveProject(context, ref),
    );
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
