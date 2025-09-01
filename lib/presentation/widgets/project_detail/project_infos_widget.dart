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
import '../../../data/repositories/account_repository.dart';
import '../../../core/result.dart';

class ProjectInfosWidget extends ConsumerWidget {
  final TaskCalendar project;
  final AsyncValue<List<Task>> tasksAsync;
  final Function(TaskCalendar) onProjectUpdated;
  final VoidCallback? onCollapse;

  const ProjectInfosWidget({
    super.key,
    required this.project,
    required this.tasksAsync,
    required this.onProjectUpdated,
    this.onCollapse,
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
              // Editable title with collapse button (bigger and thinner) - only on desktop
              if (isDesktop) ...[
                Row(
                  children: [
                    Expanded(
                      child: EditableTitle(
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
                    ),
                    if (onCollapse != null)
                      IconButton(
                        onPressed: onCollapse,
                        icon: const Icon(Icons.keyboard_double_arrow_left),
                        tooltip: 'Collapse project details',
                      ),
                  ],
                ),
                
                const SizedBox(height: 8),
              ],
              
              // Warning for attendees without project access (desktop only)
              if (isDesktop) _buildAttendeeAccessWarning(context, ref),
              
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
                      project.flowitStartedAt != null ? _formatProjectDate(project.flowitStartedAt!) : 'Unknown'
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
          
                    // Project Owner
          _buildDetailRow(context, 'Owner', 
            project.flowitOwner != null && project.flowitOwner!.isNotEmpty ? project.flowitOwner! : '-'
          ),
          const SizedBox(height: 8),
          
          // Author
          _buildDetailRow(context, 'Author', 
            project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty
                ? project.flowitAuthor!
                : '-'
          ),
          const SizedBox(height: 8),
          
          // Members - Always displayed
          sharedByAsync.when(
            data: (sharedBy) {
              final membersList = <String>[];
              final isSharedWithMe = sharedBy.isNotEmpty;
              
              // Add shared members
              if (project.sharedWithEmails.isNotEmpty) {
                membersList.addAll(project.sharedWithEmails);
              }
              
              // Add current user (project owner or shared with me)
              if (isSharedWithMe) {
                // Project is shared with me, add the sharer to the list
                if (!membersList.contains(sharedBy)) {
                  membersList.add(sharedBy);
                }
                // Also add current user to the list when project is shared with me
                final currentUser = project.flowitOwner ?? project.flowitAuthor ?? '';
                if (currentUser.isNotEmpty && !membersList.contains(currentUser)) {
                  membersList.add(currentUser);
                }
              } else {
                // Project is owned by me, add myself to the list
                final currentUser = project.flowitOwner ?? project.flowitAuthor ?? '';
                if (currentUser.isNotEmpty && !membersList.contains(currentUser)) {
                  membersList.add(currentUser);
                }
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(context, 'Members', 
                    membersList.isNotEmpty ? membersList.join(', ') : 'No members'
                  ),
                  // Only show "Manage sharing" if project is not shared with me (i.e., I own it)
                  if (!isSharedWithMe) ...[
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
                ],
              );
            },
            loading: () {
              // While loading, show owner/author as fallback or "No members"
              // Assume project is owned by me during loading (show manage sharing)
              final currentUser = project.flowitOwner ?? project.flowitAuthor ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(context, 'Members', 
                    currentUser.isNotEmpty ? currentUser : 'No members'
                  ),
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
            },
            error: (_, __) {
              // On error, show owner/author as fallback or "No members"
              // Assume project is owned by me during error (show manage sharing)
              final currentUser = project.flowitOwner ?? project.flowitAuthor ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(context, 'Members', 
                    currentUser.isNotEmpty ? currentUser : 'No members'
                  ),
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

  /// Build warning widget for attendees without project access
  Widget _buildAttendeeAccessWarning(BuildContext context, WidgetRef ref) {
    return tasksAsync.when(
      data: (tasks) {
        // Get current user email from account repository
        final accountRepository = ref.watch(accountRepositoryProvider);
        
        // Use FutureBuilder to handle async account lookup
        return FutureBuilder<String?>(
          future: _getCurrentUserEmail(accountRepository),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }
            
            final currentUserEmail = snapshot.data;
            if (currentUserEmail == null) {
              return const SizedBox.shrink();
            }
            
            // Check if current user is project author
            final isProjectAuthor = project.flowitAuthor == currentUserEmail || 
                project.flowitOwner == currentUserEmail;
            
            if (!isProjectAuthor) {
              return const SizedBox.shrink();
            }
            
            // Get all unique attendees from tasks
            final allAttendees = <String>{};
            for (final task in tasks) {
              for (final attendee in task.attendees) {
                allAttendees.add(attendee.email);
              }
            }
            
            // Get project members
            final projectMembers = <String>{};
            if (project.sharedWithEmails.isNotEmpty) {
              projectMembers.addAll(project.sharedWithEmails);
            }
            if (project.flowitOwner != null && project.flowitOwner!.isNotEmpty) {
              projectMembers.add(project.flowitOwner!);
            }
            if (project.flowitAuthor != null && project.flowitAuthor!.isNotEmpty) {
              projectMembers.add(project.flowitAuthor!);
            }
            
            // Find attendees without project access
            final attendeesWithoutAccess = allAttendees.where(
              (attendee) => !projectMembers.contains(attendee)
            ).toList();
            
            if (attendeesWithoutAccess.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Attendees without project access',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                                     Text(
                     '${attendeesWithoutAccess.length} attendee${attendeesWithoutAccess.length == 1 ? '' : 's'} have tasks but are not project members: ${attendeesWithoutAccess.join(', ')}',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                       color: Theme.of(context).colorScheme.onSurfaceVariant,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       Expanded(
                         child: OutlinedButton.icon(
                           onPressed: () {
                             showDialog(
                               context: context,
                               builder: (context) => ProjectSharingDialog(
                                 project: project,
                                 suggestedMembers: attendeesWithoutAccess,
                               ),
                             );
                           },
                           icon: const Icon(Icons.person_add, size: 16),
                           label: Text(
                             'Add ${attendeesWithoutAccess.length == 1 ? 'them' : 'them'} as member${attendeesWithoutAccess.length == 1 ? '' : 's'}',
                             style: Theme.of(context).textTheme.bodySmall,
                           ),
                           style: OutlinedButton.styleFrom(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                             minimumSize: const Size(0, 32),
                           ),
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
             );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Get current user email from account repository
  Future<String?> _getCurrentUserEmail(AccountRepository accountRepository) async {
    final accountResult = await accountRepository.getActiveAccount();
    return accountResult.when(
      success: (account) => account?.email ?? account?.username,
      failure: (_) => null,
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