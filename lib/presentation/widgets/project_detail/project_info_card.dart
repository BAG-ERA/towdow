// Project info card widget
// Displays project description, stats, and last sync information in a card format

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../core/theme/chart_theme.dart';
import '../utils/enhanced_text_field.dart';

class ProjectInfoCard extends ConsumerWidget {
  final TaskCalendar? project;
  final AsyncValue<List<Task>> tasksAsync;
  final String projectUid;
  final Function(TaskCalendar) onProjectUpdated;

  const ProjectInfoCard({
    super.key,
    required this.project,
    required this.tasksAsync,
    required this.projectUid,
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
                'Project not found: $projectUid',
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