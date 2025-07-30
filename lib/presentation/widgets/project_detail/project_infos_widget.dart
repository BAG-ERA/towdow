// Project details widget for desktop layout
// Shows project information in a structured format with editable title and description

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task_calendar.dart';
import '../../../data/providers/providers.dart';
import '../utils/editable_title.dart';
import '../utils/enhanced_text_field.dart';
import '../utils/popup/project_sharing_dialog.dart';
import '../../../data/models/task.dart';

class ProjectInfosWidget extends ConsumerWidget {
  final TaskCalendar project;
  final AsyncValue<List<Task>> tasksAsync;
  final Function(TaskCalendar) onProjectUpdated;

  const ProjectInfosWidget({
    super.key,
    required this.project,
    required this.tasksAsync,
    required this.onProjectUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if we're on mobile (same breakpoint as AdaptiveAppLayout)
    final isDesktop = MediaQuery.of(context).size.width >= 800.0;
    
    // Check if project is shared with me
    final sharedByAsync = ref.watch(projectSharedByProvider(project.uid));
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First block: Editable title, author email, Created at | Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Editable title (bigger and thinner) - only on desktop
              if (isDesktop) ...[
                EditableTitle(
                  title: project.displayName,
                  onTitleUpdated: (newTitle) {
                    final updatedProject = project.copyWith(
                      displayName: newTitle,
                      lastModified: DateTime.now(),
                    );
                    onProjectUpdated(updatedProject);
                  },
                  isInAppBar: false,
                  textStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                
                const SizedBox(height: 8),
              ],
              
              // Author email or Shared with me by
              sharedByAsync.when(
                data: (sharedBy) {
                  if (sharedBy.isNotEmpty) {
                    // Project is shared with me
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shared with me by: $sharedBy',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  } else {
                    // Project is not shared with me, show author
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty
                              ? project.flowitAuthor!
                              : '-',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty
                          ? project.flowitAuthor!
                          : '-',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                error: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty
                          ? project.flowitAuthor!
                          : '-',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              
              // Created at and Status row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailRow(
                      context,
                      'Created at', 
                      project.flowitCreatedAt != null 
                          ? _formatProjectDate(project.flowitCreatedAt!)
                          : 'Unknown'
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailRow(
                      context,
                      'Status', 
                      project.flowitStatus ?? 'ONGOING'
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Progress section
              tasksAsync.when(
                data: (tasks) {
                  final completedTasks = tasks.where((task) => task.status == 'COMPLETED').length;
                  final totalTasks = tasks.length;
                  final progressPercentage = totalTasks > 0 ? (completedTasks * 100 / totalTasks).round() : 0;
                  
                  return Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          'Progress',
                          '$progressPercentage%'
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDetailRow(
                          context,
                          'Tasks',
                          '$completedTasks/$totalTasks'
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(context, 'Progress', '...'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailRow(context, 'Tasks', '...'),
                    ),
                  ],
                ),
                error: (_, __) => Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(context, 'Progress', '0%'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailRow(context, 'Tasks', '0/0'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Second block: Details section
          Text(
            'Details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          
          // Separator right below section title
          Divider(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            height: 1,
          ),
          
          const SizedBox(height: 12),
          
          // Project Manager
          _buildDetailRow(context, 'Manager', 
            project.flowitManager != null && project.flowitManager!.isNotEmpty
                ? project.flowitManager!
                : '-'
          ),
          const SizedBox(height: 8),
          
          // Author
          _buildDetailRow(context, 'Author', 
            project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty
                ? project.flowitAuthor!
                : '-'
          ),
          const SizedBox(height: 8),
          
          // Members
          sharedByAsync.when(
            data: (sharedBy) {
              final membersList = <String>[];
              
              // Add shared members
              if (project.sharedWithEmails.isNotEmpty) {
                membersList.addAll(project.sharedWithEmails);
              }
              
              // Add current user (project owner or shared with me)
              if (sharedBy.isNotEmpty) {
                // Project is shared with me, add the sharer to the list
                if (!membersList.contains(sharedBy)) {
                  membersList.add(sharedBy);
                }
              } else {
                // Project is owned by me, add myself to the list
                final currentUser = project.flowitOwner ?? project.flowitAuthor ?? '';
                if (currentUser.isNotEmpty && !membersList.contains(currentUser)) {
                  membersList.add(currentUser);
                }
              }
              
              if (membersList.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(context, 'Members', membersList.join(', ')),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ProjectSharingDialog(project: project),
                        );
                      },
                      child: Text(
                        'Manage sharing',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            loading: () {
              // While loading, show owner/author as fallback
              final currentUser = project.flowitOwner ?? project.flowitAuthor ?? '';
              if (currentUser.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(context, 'Members', currentUser),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ProjectSharingDialog(project: project),
                        );
                      },
                      child: Text(
                        'Manage sharing',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            error: (_, __) {
              // On error, show owner/author as fallback
              final currentUser = project.flowitOwner ?? project.flowitAuthor ?? '';
              if (currentUser.isNotEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(context, 'Members', currentUser),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ProjectSharingDialog(project: project),
                        );
                      },
                      child: Text(
                        'Manage sharing',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          const SizedBox(height: 32),
          
          // Third block: Description section
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          
          // Separator right below section title
          Divider(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            height: 1,
          ),
          
          const SizedBox(height: 8),
          
          // Description content in enhanced text field
          EnhancedTextField(
            controller: TextEditingController(text: project.description),
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'No description provided',
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(0, 12, 12, 12),
              isDense: true,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onChanged: (value) {
              // Update description as user types
              final updatedProject = project.copyWith(
                description: value,
                lastModified: DateTime.now(),
              );
              onProjectUpdated(updatedProject);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatProjectDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}