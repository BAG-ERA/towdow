// Reusable project creation dialog widget
// Used across the app for creating new projects

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../core/theme/chart_theme_usage.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/services/caldav_service.dart';
import 'domain_creation_dialog.dart';
import '../enhanced_text_field.dart';

class ProjectCreationDialog extends ConsumerStatefulWidget {
  final String? initialDomain;
  
  const ProjectCreationDialog({super.key, this.initialDomain});

  @override
  ConsumerState<ProjectCreationDialog> createState() => _ProjectCreationDialogState();
}

class _ProjectCreationDialogState extends ConsumerState<ProjectCreationDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  String? selectedDomain;
  bool isDomainSectionExpanded = false;
  bool isLoading = false;
  int _domainRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with provided domain if available
    if (widget.initialDomain != null) {
      selectedDomain = widget.initialDomain;
      isDomainSectionExpanded = true; // Expand domain section when pre-selected
    }
  }

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
            
            EnhancedTextField(
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
            
            EnhancedTextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe the project goals and objectives',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            
            const SizedBox(height: 16),
            
            // Domain selection section
            ExpansionTile(
              title: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Domain (optional)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              subtitle: selectedDomain != null 
                  ? Text(
                      'Selected: $selectedDomain',
                      style: context.domainNameStyle?.copyWith(
                        fontSize: 12,
                      ),
                    )
                  : const Text('No domain selected'),
              initiallyExpanded: isDomainSectionExpanded,
              onExpansionChanged: (expanded) => setState(() => isDomainSectionExpanded = expanded),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: _buildDomainSelection(),
                ),
              ],
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

  Widget _buildDomainSelection() {
    return FutureBuilder<List<String>>(
      key: ValueKey(_domainRefreshKey),
      future: _getAllAvailableDomains(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final availableDomains = snapshot.data ?? [];
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a domain for this project:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            
            // No domain option
            RadioListTile<String?>(
              title: const Text('No domain'),
              value: null,
              groupValue: selectedDomain,
              onChanged: (value) => setState(() => selectedDomain = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            
            // Existing domains
            ...availableDomains.map((domain) => RadioListTile<String?>(
              title: Text(
                domain,
                style: context.domainNameStyle,
              ),
              value: domain,
              groupValue: selectedDomain,
              onChanged: (value) => setState(() => selectedDomain = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
            
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _showCreateDomainDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create new domain'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<List<String>> _getAllAvailableDomains() async {
    try {
      final domainService = ref.read(domainServiceProvider);
      final result = await domainService.getAvailableDomains();
      return result.when(
        success: (domains) => domains,
        failure: (failure) {
          AppLogger.warning('ProjectCreation: Failed to get available domains: ${failure.message}');
          return <String>[];
        },
      );
    } catch (e) {
      AppLogger.error('ProjectCreation: Exception getting available domains: $e');
      return <String>[];
    }
  }

  void _showCreateDomainDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const DomainCreationDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        selectedDomain = result;
        _domainRefreshKey++; // Trigger FutureBuilder rebuild
      });
    }
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
      AppLogger.info('ProjectCreation: Creating project "$projectName" with domain "${selectedDomain ?? 'none'}"');
      
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
          
          // Generate unique UID for the project
          final now = DateTime.now();
          final projectUid = 'project-${now.millisecondsSinceEpoch}-${projectName.hashCode}';
          
          AppLogger.info('ProjectCreation: Creating calendar with UID: $projectUid');
              
          // Create calendar on CalDAV server
          final createResult = await caldavService.createCalendar(
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
                  
                  // Assign domain if one was selected
                  if (selectedDomain != null) {
                    AppLogger.info('ProjectCreation: Assigning domain "$selectedDomain" to project');
                    final domainService = ref.read(domainServiceProvider);
                    final domainResult = await domainService.assignDomainToCalendar(newCalendar.uid, selectedDomain);
                    
                    await domainResult.when(
                      success: (_) {
                        AppLogger.info('ProjectCreation: Domain assigned successfully');
                      },
                      failure: (failure) {
                        AppLogger.warning('ProjectCreation: Failed to assign domain, but project was created: ${failure.message}');
                        // Don't fail the creation, just log the warning
                      },
                    );
                  }
                  
                  // Refresh the project list to show the new project
                  ref.invalidate(projectListProvider);
                  ref.invalidate(calendarListProvider);
                  ref.invalidate(activeCalendarListProvider);
                  
                  if (mounted) {
                    Navigator.of(context).pop(projectName);
                    
                    final message = selectedDomain != null 
                        ? 'Project "$projectName" created in domain "$selectedDomain"'
                        : 'Project "$projectName" created successfully';
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
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