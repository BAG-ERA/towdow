// Create Project or Domain Button component
// Reusable button for creating new projects and domains with consistent styling
// Contains the dialog selection logic for choosing between project and domain creation
// Uses FlowIt typography system with automatic capitalization

import 'package:flutter/material.dart';
import '../../../../core/theme/chart_theme.dart';
import '../popup/domain_creation_dialog.dart';
import '../popup/project_creation_dialog.dart';

class CreateProjectOrDomainButton extends StatelessWidget {
  /// Custom button color (defaults to theme primary color)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button text (will be automatically capitalized)
  final String text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final CreateProjectOrDomainButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// Optional callback when project is created
  final Function(String projectName)? onProjectCreated;
  
  /// Optional callback when domain is created
  final Function(String domainName)? onDomainCreated;

  const CreateProjectOrDomainButton({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.text = 'Create',
    this.icon = Icons.add_rounded,
    this.size = CreateProjectOrDomainButtonSize.medium,
    this.isFullWidth = false,
    this.onProjectCreated,
    this.onDomainCreated,
  });

  /// Factory constructor for a compact create button (commonly used in toolbars)
  factory CreateProjectOrDomainButton.compact({
    Key? key,
    Color? backgroundColor,
    Color? textColor,
    bool isFullWidth = false,
    Function(String)? onProjectCreated,
    Function(String)? onDomainCreated,
  }) {
    return CreateProjectOrDomainButton(
      key: key,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: 'Create',
      icon: Icons.add,
      size: CreateProjectOrDomainButtonSize.small,
      isFullWidth: isFullWidth,
      onProjectCreated: onProjectCreated,
      onDomainCreated: onDomainCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartTheme = context.chartTheme;
    final effectiveBackgroundColor = backgroundColor ?? chartTheme.colors.primary;
    final effectiveTextColor = textColor ?? chartTheme.typography.primaryButton.color;
    
    final buttonPadding = _getPadding(chartTheme);
    final fontSize = _getFontSize();
    
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: () => _showCreateDialog(context),
        icon: icon != null ? Icon(icon, size: _getIconSize()) : const SizedBox.shrink(),
        label: Text(
          text.toUpperCase(), // Automatic capitalization as per FlowIt typography system
          style: chartTheme.typography.primaryButton.copyWith(
            color: effectiveTextColor,
            fontSize: fontSize,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          padding: buttonPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
          ),
          elevation: size == CreateProjectOrDomainButtonSize.large ? 2 : 1,
        ),
      ),
    );
  }

  EdgeInsets _getPadding(ChartTheme chartTheme) {
    switch (size) {
      case CreateProjectOrDomainButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingMedium,
          vertical: chartTheme.dimensions.paddingSmall,
        );
      case CreateProjectOrDomainButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        );
      case CreateProjectOrDomainButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge * 1.5,
          vertical: chartTheme.dimensions.paddingMedium * 1.2,
        );
    }
  }

  double _getFontSize() {
    switch (size) {
      case CreateProjectOrDomainButtonSize.small:
        return 12;
      case CreateProjectOrDomainButtonSize.medium:
        return 14;
      case CreateProjectOrDomainButtonSize.large:
        return 16;
    }
  }

  double _getIconSize() {
    switch (size) {
      case CreateProjectOrDomainButtonSize.small:
        return 16;
      case CreateProjectOrDomainButtonSize.medium:
        return 20;
      case CreateProjectOrDomainButtonSize.large:
        return 24;
    }
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.domain_rounded),
              title: const Text('Domain'),
              subtitle: const Text('Create a new domain'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateDomainDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: const Text('Project'),
              subtitle: const Text('Create a new project'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateProjectDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDomainDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DomainCreationDialog(),
    ).then((result) {
      // If domain was created successfully and we have a callback, call it
      if (result != null && result is String && onDomainCreated != null) {
        onDomainCreated!(result);
      }
    });
  }

  void _showCreateProjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ProjectCreationDialog(),
    ).then((result) {
      // If project was created successfully and we have a callback, call it
      if (result != null && result is String && onProjectCreated != null) {
        onProjectCreated!(result);
      }
    });
  }
}

/// Size variants for the create project or domain button
enum CreateProjectOrDomainButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
} 