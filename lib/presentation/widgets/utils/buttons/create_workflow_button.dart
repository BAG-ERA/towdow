// Create Workflow Button component
// Mirrors CreateProjectButton styling and semantics for workflows
// Uses PrimaryButton for consistent styling and behavior

import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'primary_button.dart';
import '../popup/workflow_creation_dialog.dart';

class CreateWorkflowButton extends StatelessWidget {
  final Color? backgroundColor;
  final Color? textColor;
  final String? text;
  final IconData? icon;
  final PrimaryButtonSize size;
  final bool isFullWidth;
  final VoidCallback? onWorkflowCreated;

  const CreateWorkflowButton({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.text,
    this.icon = Icons.add,
    this.size = PrimaryButtonSize.medium,
    this.isFullWidth = false,
    this.onWorkflowCreated,
  });


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
      size: PrimaryButtonSize.large,
      isFullWidth: isFullWidth,
      onWorkflowCreated: onWorkflowCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = text ?? AppLocalizations.of(context)!.createWorkflow;
    
    return PrimaryButton(
      text: buttonText,
      icon: icon,
      size: size,
      isFullWidth: isFullWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      onPressed: () => _showCreateWorkflowDialog(context),
    );
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



