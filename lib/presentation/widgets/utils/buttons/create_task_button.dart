// Create Task Button component
// Reusable button for creating new tasks with consistent styling across the app
// Uses FlowIt typography system with automatic capitalization

import 'package:flutter/material.dart';
import '../../../../core/theme/chart_theme.dart';
import '../popup/task_creation_dialog.dart';

class CreateTaskButton extends StatelessWidget {
  /// Optional project context to assign the task to (recommended)
  final String? projectCalendarUid;
  
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
    this.text = 'Create Task',
    this.icon = Icons.add,
    this.size = CreateTaskButtonSize.medium,
    this.isFullWidth = false,
    this.onTaskCreated,
  });

  /// Factory constructor for a compact create task button (commonly used in toolbars)
  factory CreateTaskButton.compact({
    Key? key,
    String? projectCalendarUid,
    Color? backgroundColor,
    Color? textColor,
    Function(String)? onTaskCreated,
  }) {
    return CreateTaskButton(
      key: key,
      projectCalendarUid: projectCalendarUid,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: 'Create',
      icon: Icons.add,
      size: CreateTaskButtonSize.small,
      onTaskCreated: onTaskCreated,
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
        onPressed: () => _showCreateTaskDialog(context),
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

  double _getFontSize() {
    switch (size) {
      case CreateTaskButtonSize.small:
        return 12;
      case CreateTaskButtonSize.medium:
        return 14;
      case CreateTaskButtonSize.large:
        return 16;
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => TaskCreationDialog(
        sourceCalendarUid: projectCalendarUid,
      ),
    );
    
    // If task was created successfully and we have a callback, call it
    if (result != null && onTaskCreated != null) {
      onTaskCreated!(result);
    }
  }
}

/// Size variants for the create task button
enum CreateTaskButtonSize {
  small,   // Compact size for toolbars and tight spaces
  medium,  // Standard size for most use cases
  large,   // Prominent size for main actions
} 