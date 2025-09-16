// Create Project Button component
// Reusable button for creating new projects with consistent styling across the app
// Uses PrimaryButton for consistent styling and behavior

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'primary_button.dart';
import '../popup/project_creation_dialog.dart';

class CreateProjectButton extends StatelessWidget {
  /// Custom button color (defaults to theme primary color)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button text (will be automatically capitalized). If null, uses localized default
  final String? text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final PrimaryButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// Custom callback when project is created (optional)
  final Function(String projectName)? onProjectCreated;

  const CreateProjectButton({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.text,
    this.icon = Icons.add,
    this.size = PrimaryButtonSize.medium,
    this.isFullWidth = false,
    this.onProjectCreated,
  });


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
      text: null,
      icon: Icons.add_rounded,
      size: PrimaryButtonSize.large,
      isFullWidth: isFullWidth,
      onProjectCreated: onProjectCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = text ?? (size == PrimaryButtonSize.large
        ? AppLocalizations.of(context)!.createNewProject
        : AppLocalizations.of(context)!.createProject);
    
    return PrimaryButton(
      text: buttonText,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      onPressed: () => _showCreateProjectDialog(context),
    );
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

