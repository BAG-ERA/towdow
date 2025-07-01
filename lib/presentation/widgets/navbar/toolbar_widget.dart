// Bottom toolbar widget for navbar
// Contains Create, Archive, and Settings actions in a horizontal layout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/providers.dart';
import '../utils/popup/domain_creation_dialog.dart';
import '../utils/popup/project_creation_dialog.dart';
import '../utils/popup/task_creation_dialog.dart';

class ToolbarWidget extends ConsumerWidget {
  const ToolbarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccount = ref.watch(hasActiveAccountProvider);
    final currentLocation = GoRouterState.of(context).uri.path;
    
    return hasAccount.when(
      data: (hasActiveAccount) => hasActiveAccount 
          ? _buildToolbarContent(context, currentLocation)
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildToolbarContent(BuildContext context, String currentLocation) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Create button (left side)
          Expanded(
            child: _buildCreateButton(context),
          ),
          
          const SizedBox(width: 8),
          
          // Archive button (right side)
          _buildIconButton(
            context: context,
            icon: Icons.archive_rounded,
            tooltip: 'Archived Projects',
            isSelected: currentLocation == '/archived',
            onPressed: () {
              context.go('/archived');
              _closeDrawerIfMobile(context);
            },
          ),
          
          const SizedBox(width: 8),
          
          // Settings button (right side)
          _buildIconButton(
            context: context,
            icon: Icons.settings_rounded,
            tooltip: 'Settings',
            isSelected: currentLocation == '/settings',
            onPressed: () {
              context.go('/settings');
              _closeDrawerIfMobile(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material(
      color: colorScheme.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showCreateDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: colorScheme.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Create',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected 
            ? colorScheme.secondaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: isSelected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ),
    );
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
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Task'),
              subtitle: const Text('Create a new task'),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateTaskDialog(context);
              },
            ),
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

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TaskCreationDialog(),
    );
  }

  void _showCreateDomainDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DomainCreationDialog(),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ProjectCreationDialog(),
    );
  }

  void _closeDrawerIfMobile(BuildContext context) {
    if (Scaffold.of(context).hasDrawer) {
      Navigator.of(context).pop();
    }
  }
} 