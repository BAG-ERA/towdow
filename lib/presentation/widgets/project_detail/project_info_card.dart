// Project info card widget
// Displays project description, stats, and last sync information in a card format

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../data/providers/providers.dart';

import '../utils/enhanced_text_field.dart';
import '../utils/popup/project_sharing_dialog.dart';

class ProjectInfoCard extends ConsumerWidget {
  final TaskCalendar? project;
  final AsyncValue<List<Task>> tasksAsync;
  final String projectPath;
  final Function(TaskCalendar) onProjectUpdated;

  const ProjectInfoCard({
    super.key,
    required this.project,
    required this.tasksAsync,
    required this.projectPath,
    required this.onProjectUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (project == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Project not found: $projectPath',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          
          // Editable Project Description
          _EditableProjectDescription(
            project: project!,
            onProjectUpdated: onProjectUpdated,
          ),
          
          const SizedBox(height: 12),

          // Sharing status section
          _ProjectSharingStatus(project: project!),
          
          const SizedBox(height: 12),
          // Dynamic stats based on actual tasks
          tasksAsync.when(
            data: (tasks) {
              final stats = project!.getStats(tasks);
              return Row(
                children: [
                  _buildProjectStat(context, 'Progress', '${stats.progressPercentage}%'),
                  const SizedBox(width: 16),
                  _buildProjectStat(context, 'Tasks', '${stats.completedTasks}/${stats.totalTasks}'),
                  const SizedBox(width: 16),
                  if (project!.lastSyncAt != null)
                    _buildProjectStat(context, 'Last Update', _formatLastSync(project!.lastSyncAt!)),
                ],
              );
            },
            loading: () => Row(
              children: [
                _buildProjectStat(context, 'Progress', '...'),
                const SizedBox(width: 16),
                _buildProjectStat(context, 'Tasks', '...'),
                const SizedBox(width: 16),
                if (project!.lastSyncAt != null)
                  _buildProjectStat(context, 'Last Update', _formatLastSync(project!.lastSyncAt!)),
              ],
            ),
            error: (_, _) => Row(
              children: [
                _buildProjectStat(context, 'Progress', '0%'),
                const SizedBox(width: 16),
                _buildProjectStat(context, 'Status', project!.status),
                const SizedBox(width: 16),
                if (project!.lastSyncAt != null)
                  _buildProjectStat(context, 'Last Update', _formatLastSync(project!.lastSyncAt!)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ],
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

// Editable Project Description Widget
class _EditableProjectDescription extends StatefulWidget {
  final TaskCalendar project;
  final Function(TaskCalendar) onProjectUpdated;

  const _EditableProjectDescription({
    required this.project,
    required this.onProjectUpdated,
  });

  @override
  State<_EditableProjectDescription> createState() => _EditableProjectDescriptionState();
}

class _EditableProjectDescriptionState extends State<_EditableProjectDescription> {
  bool _isEditing = false;
  bool _isHovered = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.project.description);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDescription = widget.project.description.isNotEmpty;

    if (_isEditing) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EnhancedTextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Enter project description...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              onSubmitted: (_) => _saveDescription(),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveDescription,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _startEditing,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            hasDescription 
                ? widget.project.description 
                : 'No description provided • Click to add',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasDescription 
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
              fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.project.description;
    });
  }

  void _saveDescription() {
    final updatedProject = widget.project.copyWith(
      description: _controller.text.trim(),
      lastModified: DateTime.now(),
    );
    widget.onProjectUpdated(updatedProject);
    
    setState(() {
      _isEditing = false;
    });
  }
}

// Project sharing status widget
class _ProjectSharingStatus extends ConsumerWidget {
  final TaskCalendar project;

  const _ProjectSharingStatus({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if account supports sharing
    final accountAsync = ref.watch(activeAccountProvider);
    final supportsSharing = accountAsync.when(
      data: (account) => account?.providerType == 'towdow_cloud' || account?.providerType == 'towdow_selfhosted',
      loading: () => false,
      error: (_, __) => false,
    );

    if (!supportsSharing) {
      return const SizedBox.shrink(); // Don't show anything if sharing is not supported
    }

         // Use FutureBuilder to handle async sharing check
     return FutureBuilder<String>(
       future: project.isSharedWithMeBy(ref),
       builder: (context, snapshot) {
         final sharedWithMeBy = snapshot.data ?? '';
         final isSharedWithMe = sharedWithMeBy.isNotEmpty;
         final isSharedWithOthers = project.isSharedWithOthers;

         if (!isSharedWithMe && !isSharedWithOthers) {
          // Project is not shared - show quick share button
          return Row(
            children: [
              Icon(
                Icons.people_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Private project',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showSharingDialog(context),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          );
        }

        // Project is shared - show sharing status
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSharedWithMe ? Icons.people : Icons.share,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSharedWithMe 
                      ? 'Shared with you by $sharedWithMeBy' 
                      : 'Shared with ${project.sharedWithEmails.length} ${project.sharedWithEmails.length == 1 ? 'person' : 'people'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!isSharedWithMe) ...[
                TextButton(
                  onPressed: () => _showSharingDialog(context),
                  child: Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => _showExitShareDialog(context),
                  child: Text(
                    'Leave',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isSharedWithOthers && project.sharedWithEmails.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: project.sharedWithEmails.take(3).map((email) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatEmail(email),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (project.sharedWithEmails.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${project.sharedWithEmails.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
      },
    );
  }

  void _showSharingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ProjectSharingDialog(project: project),
    );
  }

  void _showExitShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Shared Project'),
        content: Text('Are you sure you want to stop accessing "${project.displayName}"? You will no longer be able to view or edit this project.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement exit share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exit share functionality not yet implemented')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }


  String _formatEmail(String email) {
    // Show just the name part if it's an email
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return email;
  }
} 