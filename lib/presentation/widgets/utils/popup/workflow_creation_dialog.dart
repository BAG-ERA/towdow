// Workflow creation dialog - mirrors ProjectCreationDialog but creates a workflow calendar

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/providers/providers.dart';
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
      // Create calendar directly as workflow on server
      final accountRepository = ref.read(accountRepositoryProvider);
      final accountResult = await accountRepository.getActiveAccount();
      final account = await accountResult.when(
        success: (acc) async => acc,
        failure: (_) async => null,
      );
      if (account == null) {
        throw Exception('No active CalDAV account found');
      }

      final caldavService = ref.read(caldavServiceProvider(account));
      final createResult = await caldavService.createCalendar(
        displayName: name,
        description: description.isEmpty ? 'Workflow created by FlowIt' : description,
        asWorkflow: true,
      );

      await createResult.when(
        success: (calendar) async {
          // Save to repository
          final calendarRepository = ref.read(calendarRepositoryProvider);
          await calendarRepository.save(calendar);
          // Navigate
          final encodedPath = Uri.encodeComponent(calendar.path);
          Future.delayed(const Duration(milliseconds: 300), () {
            globalNavigatorKey.currentContext?.go('/workflow/$encodedPath');
          });
          if (mounted) Navigator.of(context).pop(name);
        },
        failure: (f) async => throw Exception(f.message),
      );
    } catch (e) {
      AppLogger.error('WorkflowCreationDialog: Failed to create workflow', e);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}


