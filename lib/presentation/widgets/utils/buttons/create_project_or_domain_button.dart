// Create Project or Domain Button component
// Reusable button for creating new projects and domains with consistent styling
// Contains the dialog selection logic for choosing between project and domain creation
// Uses FlowIt typography system with automatic capitalization

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../../core/theme/chart_theme.dart';
import '../popup/domain_creation_dialog.dart';
import '../popup/project_creation_dialog.dart';
import '../popup/workflow_creation_dialog.dart';

class CreateProjectOrDomainButton extends StatelessWidget {
  /// Custom button color (defaults to theme primary color)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button text (will be automatically capitalized). If null, uses localized default
  final String? text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final CreateProjectOrDomainButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// When true, shows a right-side vertical separator and a down arrow to hint a submenu
  /// This is a visual-only affordance; behaviour remains identical (single onPressed)
  final bool showDropdownAffordance;
  
  /// Optional callback when project is created
  final Function(String projectName)? onProjectCreated;
  
  /// Optional callback when domain is created
  final Function(String domainName)? onDomainCreated;

  const CreateProjectOrDomainButton({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.text,
    this.icon = Icons.add_rounded,
    this.size = CreateProjectOrDomainButtonSize.medium,
    this.isFullWidth = false,
    this.showDropdownAffordance = false,
    this.onProjectCreated,
    this.onDomainCreated,
  });

  /// Factory constructor for a compact create button (commonly used in toolbars)
  factory CreateProjectOrDomainButton.compact({
    Key? key,
    Color? backgroundColor,
    Color? textColor,
    bool isFullWidth = false,
    bool showDropdownAffordance = false,
    Function(String)? onProjectCreated,
    Function(String)? onDomainCreated,
  }) {
    return CreateProjectOrDomainButton(
      key: key,
      backgroundColor: backgroundColor,
      textColor: textColor,
      icon: Icons.add,
      size: CreateProjectOrDomainButtonSize.small,
      isFullWidth: isFullWidth,
      showDropdownAffordance: showDropdownAffordance,
      onProjectCreated: onProjectCreated,
      onDomainCreated: onDomainCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartTheme = context.chartTheme;
    final effectiveBackgroundColor = backgroundColor ?? chartTheme.colors.primary;
    final effectiveTextColor = textColor ?? chartTheme.typography.primaryButton.color;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    
    final buttonPadding = _getPadding(chartTheme);
    final scale = (chartTheme.typography.primaryButton.fontSize ?? 14) / 14.0;
    
    final baseButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: effectiveBackgroundColor,
      foregroundColor: effectiveTextColor,
      padding: buttonPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
      ),
      elevation: size == CreateProjectOrDomainButtonSize.large ? 2 : 1,
    );

    final localizedLabel = (text ?? AppLocalizations.of(context)!.create).toUpperCase();

    if (!showDropdownAffordance) {
      return SizedBox(
        width: isFullWidth ? double.infinity : null,
        child: ElevatedButton.icon(
          onPressed: () => _showCreateDialog(context),
          icon: icon != null ? Icon(icon, size: _getIconSize() * scale) : const SizedBox.shrink(),
          label: Text(
            localizedLabel,
            style: chartTheme.typography.primaryButton.copyWith(
              color: effectiveTextColor,
            ),
          ),
          style: baseButtonStyle,
        ),
      );
    }

    // With dropdown affordance: build a simple custom Material button for full control
    // This guarantees the arrow can be exactly flush to the right border
    final double iconSize = _getIconSize() * scale;
    return Material(
      color: effectiveBackgroundColor,
      elevation: size == CreateProjectOrDomainButtonSize.large ? 2 : 1,
      borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
        onTap: () => _showCreateDialog(context),
        child: Container(
          width: isFullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            vertical: _getPadding(chartTheme).vertical/4,
            horizontal: _getPadding(chartTheme).horizontal/8,
          ),
          child: IntrinsicHeight(
            child: Row(
            children: [
              // Left content with classic padding
              Padding(
                padding: EdgeInsets.only(
                  left: chartTheme.dimensions.paddingMedium,
                  right: chartTheme.dimensions.paddingSmall,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: iconSize, color: effectiveTextColor ?? onPrimaryColor),
                      SizedBox(width: chartTheme.dimensions.paddingSmall),
                    ],
                    Text(
                      localizedLabel,
                      style: chartTheme.typography.primaryButton.copyWith(
                        color: effectiveTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Spacer takes remaining width
              Expanded(child: SizedBox.shrink()),
              VerticalDivider(
                width: 8,
                thickness: 1,
                color: (effectiveTextColor ?? onPrimaryColor).withOpacity(0.24),
              ),
              SizedBox(
                width: iconSize, // tight area: icon width only
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: iconSize,
                    color: effectiveTextColor ?? onPrimaryColor,
                  ),
                ),
              ),
            ],
            ),
          ),
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

  // Removed _getSeparatorHeight; using full height container in affordance variant

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
        builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.createNew),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.domain_rounded),
              title: Text(AppLocalizations.of(context)!.domain),
              subtitle: Text(AppLocalizations.of(context)!.domainExplainer),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateDomainDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_rounded),
              title: Text(AppLocalizations.of(context)!.project),
              subtitle: Text(AppLocalizations.of(context)!.projectExplainer),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateProjectDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.route_rounded),
              title: Text(AppLocalizations.of(context)!.workflow),
              subtitle: Text(AppLocalizations.of(context)!.workflowExplainer),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateWorkflowDialog(context);
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
    );
  }

  void _showCreateWorkflowDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const WorkflowCreationDialog(),
    );
  }
}

/// Size variants for the create project or domain button
enum CreateProjectOrDomainButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
} 