// Create Task Button component
// Reusable button for creating new tasks with consistent styling across the app
// Uses PrimaryButton for consistent styling and behavior

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'primary_button.dart';
import '../popup/task_creation_dialog.dart';
import '../popup/project_selection_dialog.dart';

class CreateTaskButton extends StatelessWidget {
  /// Optional project context to assign the task to (recommended)
  final String? projectCalendarUid;
  /// When true, open workflow-variant of the dialog
  final bool workflowVariant;
  
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
  
  /// Custom callback when task is created (optional)
  final Function(String taskSummary)? onTaskCreated;

  const CreateTaskButton({
    super.key,
    this.projectCalendarUid,
    this.backgroundColor,
    this.textColor,
    this.text,
    this.icon = Icons.add,
    this.size = PrimaryButtonSize.medium,
    this.isFullWidth = false,
    this.onTaskCreated,
    this.workflowVariant = false,
  });


  /// Factory constructor for a prominent create task button (commonly used in main areas)
  factory CreateTaskButton.prominent({
    Key? key,
    String? projectCalendarUid,
    Color? backgroundColor,
    Color? textColor,
    bool isFullWidth = false,
    Function(String)? onTaskCreated,
    bool workflowVariant = false,
  }) {
    return CreateTaskButton(
      key: key,
      projectCalendarUid: projectCalendarUid,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: null,
      icon: Icons.add_rounded,
      size: PrimaryButtonSize.large,
      isFullWidth: isFullWidth,
      onTaskCreated: onTaskCreated,
      workflowVariant: workflowVariant,
    );
  }

  /// Factory constructor for a first-time user create task button (shows project selection)
  factory CreateTaskButton.firstTime({
    Key? key,
    Color? backgroundColor,
    Color? textColor,
    Function(String)? onTaskCreated,
  }) {
    return CreateTaskButton(
      key: key,
      projectCalendarUid: null, // Will trigger project selection
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: null,
      icon: Icons.add_rounded,
      size: PrimaryButtonSize.large,
      isFullWidth: false,
      onTaskCreated: onTaskCreated,
      workflowVariant: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = text ?? (size == PrimaryButtonSize.large
        ? AppLocalizations.of(context)!.addNewTask
        : AppLocalizations.of(context)!.addTask);
    
    return PrimaryButton(
      text: buttonText,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      onPressed: () => _showCreateTaskDialog(context),
    );
  }


  Future<void> _showCreateTaskDialog(BuildContext context) async {
    // If no project is specified, show project selection dialog first
    if (projectCalendarUid == null) {
      final selectedProjectPath = await showDialog<String>(
        context: context,
        builder: (context) => const ProjectSelectionDialog(),
      );

      if (selectedProjectPath != null && context.mounted) {
        // Show task creation dialog with the selected project
        await showDialog<void>(
          context: context,
          builder: (context) => TaskCreationDialog(
            projectPath: selectedProjectPath,
            workflowVariant: workflowVariant,
          ),
        );
      }
    } else {
      // Show task creation dialog directly with the specified project
      await showDialog<void>(
        context: context,
        builder: (context) => TaskCreationDialog(
          projectPath: projectCalendarUid,
          workflowVariant: workflowVariant,
        ),
      );
    }
  }
}
