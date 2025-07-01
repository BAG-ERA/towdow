// Bottom toolbar widget for navbar
// Contains Create, Archive, and Settings actions in a horizontal layout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/providers.dart';

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
      error: (_, __) => const SizedBox.shrink(),
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
    final summaryController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Task'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(
                    labelText: 'Task summary *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded),
                  title: Text(selectedDue == null 
                    ? 'No due date' 
                    : 'Due: ${selectedDue!.day}/${selectedDue!.month}/${selectedDue!.year}'
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDue ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDue = picked;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: summaryController.text.trim().isEmpty 
                  ? null 
                  : () {
                      // TODO: Implement task creation logic
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Task creation will be implemented'),
                        ),
                      );
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Project'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Project name *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: nameController.text.trim().isEmpty 
                ? null 
                : () {
                    // TODO: Implement project creation logic
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Project creation will be implemented'),
                      ),
                    );
                  },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _closeDrawerIfMobile(BuildContext context) {
    if (Scaffold.of(context).hasDrawer) {
      Navigator.of(context).pop();
    }
  }
} 