// Create Project Button component
// Reusable button for creating new projects with consistent styling across the app
// Uses FlowIt typography system with automatic capitalization

import 'package:flutter/material.dart';
import '../../../../core/theme/chart_theme.dart';
import '../popup/project_creation_dialog.dart';

class CreateProjectButton extends StatelessWidget {
  /// Custom button color (defaults to theme primary color)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button text (will be automatically capitalized)
  final String text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final CreateProjectButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// Custom callback when project is created (optional)
  final Function(String projectName)? onProjectCreated;

  const CreateProjectButton({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.text = 'Create Project',
    this.icon = Icons.add,
    this.size = CreateProjectButtonSize.medium,
    this.isFullWidth = false,
    this.onProjectCreated,
  });

  /// Factory constructor for a compact create project button (commonly used in toolbars)
  factory CreateProjectButton.compact({
    Key? key,
    Color? backgroundColor,
    Color? textColor,
    Function(String)? onProjectCreated,
  }) {
    return CreateProjectButton(
      key: key,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: 'Create Project',
      icon: Icons.add,
      size: CreateProjectButtonSize.small,
      onProjectCreated: onProjectCreated,
    );
  }

  /// Factory constructor for a prominent create project button (commonly used in main areas)
  factory CreateProjectButton.prominent({
    Key? key,
    Color? backgroundColor,
    Color? textColor,
    bool isFullWidth = false,
    Function(String)? onProjectCreated,
  }) {
    return CreateProjectButton(
      key: key,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: 'Create New Project',
      icon: Icons.add_rounded,
      size: CreateProjectButtonSize.large,
      isFullWidth: isFullWidth,
      onProjectCreated: onProjectCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartTheme = context.chartTheme;
    final effectiveBackgroundColor = backgroundColor ?? chartTheme.colors.primary;
    final effectiveTextColor = textColor ?? chartTheme.typography.primaryButton.color;
    
    final buttonPadding = _getPadding(chartTheme);
    final scale = (chartTheme.typography.primaryButton.fontSize ?? 14) / 14.0;
    
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: () => _showCreateProjectDialog(context),
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
          elevation: size == CreateProjectButtonSize.large ? 2 : 1,
        ),
      ),
    );
  }

  EdgeInsets _getPadding(ChartTheme chartTheme) {
    switch (size) {
      case CreateProjectButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingMedium,
          vertical: chartTheme.dimensions.paddingSmall,
        );
      case CreateProjectButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        );
      case CreateProjectButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge * 1.5,
          vertical: chartTheme.dimensions.paddingMedium * 1.2,
        );
    }
  }

  double _getIconSize() {
    // Scale icon sizes using dimensions scale by referencing paddingMedium baseline
    switch (size) {
      case CreateProjectButtonSize.small:
        return 16;
      case CreateProjectButtonSize.medium:
        return 20;
      case CreateProjectButtonSize.large:
        return 24;
    }
  }

  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const ProjectCreationDialog(),
    );
    
    if (result != null && onProjectCreated != null) {
      onProjectCreated!(result);
    }
  }
}

/// Size variants for the create project button
enum CreateProjectButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
}
