// Create Task Button component
// Reusable button for creating new tasks with consistent styling across the app
// Uses FlowIt typography system with automatic capitalization

import 'package:flutter/material.dart';
import '../../../../core/theme/chart_theme.dart';
import '../popup/task_creation_dialog.dart';

class CreateTaskButton extends StatelessWidget {
  /// Optional project context to assign the task to (recommended)
  final String? projectCalendarUid;
  /// When true, open workflow-variant of the dialog
  final bool workflowVariant;
  
  /// Custom button color (defaults to theme primary color)
  final Color? backgroundColor;
  
  /// Custom text color (defaults to white for primary buttons)
  final Color? textColor;
  
  /// Button text (will be automatically capitalized)
  final String text;
  
  /// Optional icon to display alongside text
  final IconData? icon;
  
  /// Button size variant
  final CreateTaskButtonSize size;
  
  /// Whether the button should expand to fill available width
  final bool isFullWidth;
  
  /// Custom callback when task is created (optional)
  final Function(String taskSummary)? onTaskCreated;

  const CreateTaskButton({
    super.key,
    this.projectCalendarUid,
    this.backgroundColor,
    this.textColor,
    this.text = 'Add Task',
    this.icon = Icons.add,
    this.size = CreateTaskButtonSize.medium,
    this.isFullWidth = false,
    this.onTaskCreated,
    this.workflowVariant = false,
  });

  /// Factory constructor for a compact create task button (commonly used in toolbars)
  factory CreateTaskButton.compact({
    Key? key,
    String? projectCalendarUid,
    Color? backgroundColor,
    Color? textColor,
    Function(String)? onTaskCreated,
    bool workflowVariant = false,
  }) {
    return CreateTaskButton(
      key: key,
      projectCalendarUid: projectCalendarUid,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: 'Add Task',
      icon: Icons.add,
      size: CreateTaskButtonSize.small,
      onTaskCreated: onTaskCreated,
      workflowVariant: workflowVariant,
    );
  }

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
      text: 'Add New Task',
      icon: Icons.add_rounded,
      size: CreateTaskButtonSize.large,
      isFullWidth: isFullWidth,
      onTaskCreated: onTaskCreated,
      workflowVariant: workflowVariant,
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
        onPressed: () => _showCreateTaskDialog(context),
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
          elevation: size == CreateTaskButtonSize.large ? 2 : 1,
        ),
      ),
    );
  }

  EdgeInsets _getPadding(ChartTheme chartTheme) {
    switch (size) {
      case CreateTaskButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingMedium,
          vertical: chartTheme.dimensions.paddingSmall,
        );
      case CreateTaskButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        );
      case CreateTaskButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge * 1.5,
          vertical: chartTheme.dimensions.paddingMedium * 1.2,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case CreateTaskButtonSize.small:
        return 16;
      case CreateTaskButtonSize.medium:
        return 20;
      case CreateTaskButtonSize.large:
        return 24;
    }
  }

  Future<void> _showCreateTaskDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => TaskCreationDialog(
        projectPath: projectCalendarUid,
        workflowVariant: workflowVariant,
      ),
    );
  }
}

/// Size variants for the create task button
enum CreateTaskButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
} 