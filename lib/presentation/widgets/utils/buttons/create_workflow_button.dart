// Create Workflow Button component
// Mirrors CreateProjectButton styling and semantics for workflows

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../../core/theme/chart_theme.dart';
import '../popup/workflow_creation_dialog.dart';

class CreateWorkflowButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? textColor;
  final String? text;
  final IconData? icon;
  final CreateWorkflowButtonSize size;
  final bool isFullWidth;
  final VoidCallback? onWorkflowCreated;

  const CreateWorkflowButton({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.text,
    this.icon = Icons.add,
    this.size = CreateWorkflowButtonSize.medium,
    this.isFullWidth = false,
    this.onWorkflowCreated,
  });

  factory CreateWorkflowButton.compact({
    Key? key,
    Color? backgroundColor,
    Color? textColor,
    VoidCallback? onWorkflowCreated,
  }) {
    return CreateWorkflowButton(
      key: key,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: null,
      icon: Icons.add,
      size: CreateWorkflowButtonSize.small,
      onWorkflowCreated: onWorkflowCreated,
    );
  }

  factory CreateWorkflowButton.prominent({
    Key? key,
    Color? backgroundColor,
    Color? textColor,
    bool isFullWidth = false,
    VoidCallback? onWorkflowCreated,
  }) {
    return CreateWorkflowButton(
      key: key,
      backgroundColor: backgroundColor,
      textColor: textColor,
      text: null,
      icon: Icons.add_rounded,
      size: CreateWorkflowButtonSize.large,
      isFullWidth: isFullWidth,
      onWorkflowCreated: onWorkflowCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartTheme = context.chartTheme;
    final effectiveBackgroundColor = backgroundColor ?? chartTheme.colors.primary;
    final effectiveTextColor = textColor ?? chartTheme.typography.primaryButton.color;

    final scale = (chartTheme.typography.primaryButton.fontSize ?? 14) / 14.0;
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton.icon(
        onPressed: () => _showCreateWorkflowDialog(context),
        icon: icon != null ? Icon(icon, size: _getIconSize() * scale) : const SizedBox.shrink(),
        label: Text(
          (text ?? AppLocalizations.of(context)!.createWorkflow).toUpperCase(),
          style: chartTheme.typography.primaryButton.copyWith(
            color: effectiveTextColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          padding: _getPadding(chartTheme),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(chartTheme.dimensions.cornerRadius),
          ),
          elevation: size == CreateWorkflowButtonSize.large ? 2 : 1,
        ),
      ),
    );
  }

  EdgeInsets _getPadding(ChartTheme chartTheme) {
    switch (size) {
      case CreateWorkflowButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingMedium,
          vertical: chartTheme.dimensions.paddingSmall,
        );
      case CreateWorkflowButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge,
          vertical: chartTheme.dimensions.paddingMedium,
        );
      case CreateWorkflowButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: chartTheme.dimensions.paddingLarge * 1.5,
          vertical: chartTheme.dimensions.paddingMedium * 1.2,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case CreateWorkflowButtonSize.small:
        return 16;
      case CreateWorkflowButtonSize.medium:
        return 20;
      case CreateWorkflowButtonSize.large:
        return 24;
    }
  }

  Future<void> _showCreateWorkflowDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const WorkflowCreationDialog(),
    );
    if (result != null) {
      onWorkflowCreated?.call();
    }
  }
}

enum CreateWorkflowButtonSize {
  small,
  medium,
  large,
}


