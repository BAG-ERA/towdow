// Reusable header screen widget for consistent AppBar styling across the app
// Handles both mobile and desktop layouts with optional back button and voice feedback

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import 'utils/voice_feedback_button.dart';
import 'utils/editable_title.dart';

class HeaderScreenWidget extends ConsumerWidget implements PreferredSizeWidget {
  const HeaderScreenWidget({
    super.key,
    required this.title,
    this.backLink,
    this.showVoiceFeedback = false,
    this.editableTitle,
    this.onTitleUpdated,
    this.bottom,
  });

  final String title;
  final String? backLink;
  final bool showVoiceFeedback;
  final String? editableTitle;
  final Function(String)? onTitleUpdated;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    // Standard AppBar height plus bottom widget height if present
    final baseHeight = kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(baseHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;
    
    // On mobile, the AppBar is handled by AdaptiveAppLayout
    if (!isDesktop) {
      return const SizedBox.shrink();
    }

    return AppBar(
      title: _buildTitle(context, ref),
      automaticallyImplyLeading: backLink != null,
      leading: backLink != null ? _buildBackButton(context) : null,
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      actions: _buildActions(context, ref),
      bottom: bottom,
    );
  }

  Widget _buildTitle(BuildContext context, WidgetRef ref) {
    if (editableTitle != null && onTitleUpdated != null) {
      return EditableTitle(
        title: editableTitle!,
        onTitleUpdated: onTitleUpdated!,
        isInAppBar: true,
      );
    }
    return Text(title);
  }

  Widget? _buildBackButton(BuildContext context) {
    if (backLink == null) return null;
    
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => context.go(backLink!),
      tooltip: _getBackButtonTooltip(context),
    );
  }

  List<Widget>? _buildActions(BuildContext context, WidgetRef ref) {
    if (showVoiceFeedback) {
      return [const VoiceFeedbackButton()];
    }
    return null;
  }

  String _getBackButtonTooltip(BuildContext context) {
    if (backLink == null) return '';
    
    // Determine tooltip based on back link
    if (backLink!.startsWith('/projects')) {
      return AppLocalizations.of(context)!.backToProjects;
    } else if (backLink!.startsWith('/workflows')) {
      return AppLocalizations.of(context)!.backToWorkflows;
    } else if (backLink == '/nav') {
      return AppLocalizations.of(context)!.backToNavigation;
    }
    
    return AppLocalizations.of(context)!.back;
  }
}
