// Reusable project creation dialog widget
// Used across the app for creating new projects

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/services/caldav_service.dart';

class ProjectCreationDialog extends ConsumerStatefulWidget {
  const ProjectCreationDialog({super.key});

  @override
  ConsumerState<ProjectCreationDialog> createState() => _ProjectCreationDialogState();
}

class _ProjectCreationDialogState extends ConsumerState<ProjectCreationDialog> {
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
      title: const Text('Create New Project'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projects help organize and track tasks towards specific goals.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Project name *',
                hintText: 'e.g., Website Redesign, Marketing Campaign',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _canCreate() ? _createProject() : null,
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe the project goals and objectives',
                border: OutlineInputBorder(),
              ),
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
          onPressed: isLoading || !_canCreate() ? null : _createProject,
          child: isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  bool _canCreate() {
    return nameController.text.trim().isNotEmpty;
  }

  void _createProject() async {
    final projectName = nameController.text.trim();
    final projectDescription = descriptionController.text.trim();
    
    if (projectName.isEmpty) {
      return;
    }

    setState(() => isLoading = true);

    try {
      AppLogger.info('ProjectCreation: Creating project "$projectName"');
      
      // Get current account for CalDAV operations
      final accountRepository = ref.read(accountRepositoryProvider);
      final accountResult = await accountRepository.getActiveAccount();
      
      await accountResult.when(
        success: (account) async {
          if (account == null) {
            throw Exception('No active CalDAV account found');
          }
          
          AppLogger.info('ProjectCreation: Using account: ${account.username}@${account.serverUrl}');
          
          // Create CalDAV service instance
          final caldavService = CalDAVService(account: account);
          
          // Generate unique UID first to ensure path uniqueness
          final now = DateTime.now();
          final projectUid = 'project-${now.millisecondsSinceEpoch}-${projectName.hashCode}';
          
          // Generate a safe path name from the display name and include UID for uniqueness
          final safeName = projectName.toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
              .replaceAll(RegExp(r'\s+'), '-')
              .replaceAll(RegExp(r'-+'), '-')
              .replaceAll(RegExp(r'^-|-$'), '');
          
          // Use UID suffix to ensure path uniqueness
          final uidSuffix = projectUid.split('-').last; // Get the hash part
          final pathName = safeName.isEmpty ? 'flowit-project' : safeName;
          final uniquePathName = '${pathName}-${uidSuffix}';
          
          // Get server capabilities to determine calendar home
          final capabilitiesResult = await caldavService.testConnection();
          
          await capabilitiesResult.when(
            success: (capabilities) async {
              final calendarPath = '${capabilities.calendarHome}${uniquePathName}/';
              AppLogger.info('ProjectCreation: Creating calendar at path: $calendarPath with UID: $projectUid');
              
              // Create calendar on CalDAV server
              final createResult = await caldavService.createCalendar(
                calendarPath: calendarPath,
                displayName: projectName,
                description: projectDescription.isEmpty ? 'Project created by FlowIt' : projectDescription,
                uid: projectUid,
              );
              
              await createResult.when(
                success: (newCalendar) async {
                  AppLogger.info('ProjectCreation: Calendar created on server successfully');
                  
                  // Save the calendar locally
                  final calendarRepository = ref.read(calendarRepositoryProvider);
                  final saveResult = await calendarRepository.save(newCalendar);
                  
                  await saveResult.when(
                    success: (_) async {
                      AppLogger.info('ProjectCreation: Calendar saved locally successfully');
                      
                      // Refresh the project list to show the new project
                      ref.invalidate(projectListProvider);
                      ref.invalidate(calendarListProvider);
                      ref.invalidate(activeCalendarListProvider);
                      
                      if (mounted) {
                        Navigator.of(context).pop(projectName);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Project "$projectName" created successfully'),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }
                    },
                    failure: (failure) async {
                      AppLogger.error('ProjectCreation: Failed to save calendar locally: ${failure.message}');
                      throw Exception('Failed to save project locally: ${failure.message}');
                    },
                  );
                },
                failure: (failure) async {
                  AppLogger.error('ProjectCreation: Failed to create calendar on server: ${failure.message}');
                  throw Exception('Failed to create project on server: ${failure.message}');
                },
              );
            },
            failure: (failure) async {
              AppLogger.error('ProjectCreation: Failed to get server capabilities: ${failure.message}');
              throw Exception('Failed to connect to server: ${failure.message}');
            },
          );
        },
        failure: (failure) async {
          AppLogger.error('ProjectCreation: Failed to get active account: ${failure.message}');
          throw Exception('No CalDAV account configured. Please set up your account first.');
        },
      );
    } catch (e) {
      AppLogger.error('ProjectCreation: Exception creating project: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create project: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
} 