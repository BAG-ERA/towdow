// Project warnings banner
// Displays important warnings related to the project (e.g., attendees without access)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/task_calendar.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/providers/providers.dart';
import '../utils/popup/project_sharing_dialog.dart';
import '../../../core/result.dart';

class ProjectWarningsBanner extends ConsumerStatefulWidget {
  final TaskCalendar project;
  final AsyncValue<List<Task>> tasksAsync;

  const ProjectWarningsBanner({
    super.key,
    required this.project,
    required this.tasksAsync,
  });

  @override
  ConsumerState<ProjectWarningsBanner> createState() => _ProjectWarningsBannerState();
}

class _ProjectWarningsBannerState extends ConsumerState<ProjectWarningsBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return widget.tasksAsync.when(
      data: (tasks) {
        final accountRepository = ref.watch(accountRepositoryProvider);

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

            final isProjectAuthor = widget.project.flowitAuthor == currentUserEmail ||
                widget.project.flowitOwner == currentUserEmail;
            if (!isProjectAuthor) {
              return const SizedBox.shrink();
            }

            // Collect all unique attendees from tasks
            final allAttendees = <String>{};
            for (final task in tasks) {
              for (final attendee in task.attendees) {
                allAttendees.add(attendee.email);
              }
            }

            // Project members
            final projectMembers = <String>{};
            if (widget.project.sharedWithEmails.isNotEmpty) {
              projectMembers.addAll(widget.project.sharedWithEmails);
            }
            if (widget.project.flowitOwner != null && widget.project.flowitOwner!.isNotEmpty) {
              projectMembers.add(widget.project.flowitOwner!);
            }
            if (widget.project.flowitAuthor != null && widget.project.flowitAuthor!.isNotEmpty) {
              projectMembers.add(widget.project.flowitAuthor!);
            }

            final attendeesWithoutAccess = allAttendees
                .where((attendee) => !projectMembers.contains(attendee))
                .toList();

            if (attendeesWithoutAccess.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                      Expanded(
                        child: Text(
                          'Attendees without project access',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        splashRadius: 18,
                        tooltip: 'Dismiss',
                        onPressed: () => setState(() => _dismissed = true),
                        icon: const Icon(Icons.close_rounded),
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
                                project: widget.project,
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

  Future<String?> _getCurrentUserEmail(AccountRepository accountRepository) async {
    final accountResult = await accountRepository.getActiveAccount();
    return accountResult.when(
      success: (account) => account?.email ?? account?.username,
      failure: (_) => null,
    );
  }
}


