// Create button widget for navbar with context menu for creating new items
// Provides options to create new task, domain, or project

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';
import '../utils/popup/domain_creation_dialog.dart';

class CreateButton extends ConsumerWidget {
  const CreateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PopupMenuButton<String>(
        onSelected: (value) => _handleCreateAction(context, ref, value),
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            value: 'task',
            child: Row(
              children: [
                Icon(
                  Icons.check_box_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text('Create new task'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'domain',
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text('Create new domain'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'project',
            child: Row(
              children: [
                Icon(
                  Icons.folder_special_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text('Create new project'),
              ],
            ),
          ),
        ],
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Create',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCreateAction(BuildContext context, WidgetRef ref, String action) {
    AppLogger.info('CreateButton: Selected action - $action');
    
    switch (action) {
      case 'task':
        _createNewTask(context, ref);
        break;
      case 'domain':
        _showCreateDomainDialog(context, ref);
        break;
      case 'project':
        _createNewProject(context, ref);
        break;
    }
  }

  void _createNewTask(BuildContext context, WidgetRef ref) {
    // TODO: Implement task creation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Create new task functionality coming soon'),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showCreateDomainDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const DomainCreationDialog(),
    );
  }

  void _createNewProject(BuildContext context, WidgetRef ref) {
    // TODO: Navigate to project creation screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Create new project functionality coming soon'),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }
}

 