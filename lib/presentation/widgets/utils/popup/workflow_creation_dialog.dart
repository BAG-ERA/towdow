// Workflow creation dialog - mirrors ProjectCreationDialog but creates a workflow calendar

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/task_calendar.dart';
import 'package:go_router/go_router.dart';

class WorkflowCreationDialog extends ConsumerStatefulWidget {
  const WorkflowCreationDialog({super.key});

  @override
  ConsumerState<WorkflowCreationDialog> createState() => _WorkflowCreationDialogState();
}

class _WorkflowCreationDialogState extends ConsumerState<WorkflowCreationDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Workflow'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Workflow name *'),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isLoading || nameController.text.trim().isEmpty ? null : _createWorkflow,
          child: isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createWorkflow() async {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    if (name.isEmpty) return;

    setState(() => isLoading = true);

    try {
      // Account
      final accountRepository = ref.read(accountRepositoryProvider);
      final accountResult = await accountRepository.getActiveAccount();
      final account = await accountResult.when(
        success: (acc) async => acc,
        failure: (_) async => null,
      );
      if (account == null) {
        throw Exception('No active CalDAV account found');
      }

      final currentUser =
          (account.email != null && account.email!.isNotEmpty) ? account.email : account.username;

      final isOfflineOnly = account.serverUrl.startsWith('https://localhost') || account.serverUrl.startsWith('http://localhost');

      String createdPath;
      if (isOfflineOnly) {
        // Local create + queue for workflow
        final calendarRepository = ref.read(calendarRepositoryProvider);
        final localPath = '/local_workflows/${DateTime.now().microsecondsSinceEpoch}/';
        final workflowCal = TaskCalendarFactory.createNew(
          path: localPath,
          displayName: name,
          description: description.isEmpty ? 'Workflow created by FlowIt' : description,
          author: currentUser,
          owner: currentUser,
        ).copyWith(
          flowitAsFlow: true,
          flowitType: 'WORKFLOW',
        );
        await calendarRepository.save(workflowCal);
        // Queue creation
        final syncService = ref.read(syncServiceProvider);
        await syncService.queueCalendarCreation(workflowCal.path);
        createdPath = workflowCal.path;
      } else {
        // Try immediate server creation; on failure fallback to local + queue
        final caldavService = ref.read(caldavServiceProvider(account));
        final createResult = await caldavService.createCalendar(
          displayName: name,
          description: description.isEmpty ? 'Workflow created by FlowIt' : description,
          author: currentUser,
          owner: currentUser,
          asWorkflow: true,
        );

        final calendar = await createResult.when(
          success: (calendar) async {
            final calendarRepository = ref.read(calendarRepositoryProvider);
            await calendarRepository.save(calendar);
            return calendar;
          },
          failure: (f) async {
            // Fallback to local create + queue
            AppLogger.warning('WorkflowCreationDialog: Remote creation failed, fallback to local queue: ${f.message}');
            final calendarRepository = ref.read(calendarRepositoryProvider);
            final localPath = '/local_workflows/${DateTime.now().microsecondsSinceEpoch}/';
            final workflowCal = TaskCalendarFactory.createNew(
              path: localPath,
              displayName: name,
              description: description.isEmpty ? 'Workflow created by FlowIt' : description,
              author: currentUser,
              owner: currentUser,
            ).copyWith(
              flowitAsFlow: true,
              flowitType: 'WORKFLOW',
            );
            await calendarRepository.save(workflowCal);
            final syncService = ref.read(syncServiceProvider);
            await syncService.queueCalendarCreation(workflowCal.path);
            return workflowCal;
          },
        );
        createdPath = calendar.path;
      }

      // Navigate
      final encodedPath = Uri.encodeComponent(createdPath);
      Future.delayed(const Duration(milliseconds: 300), () {
        globalNavigatorKey.currentContext?.go('/workflow/$encodedPath');
      });
      if (mounted) Navigator.of(context).pop(name);
    } catch (e) {
      AppLogger.error('WorkflowCreationDialog: Failed to create workflow', e);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}


