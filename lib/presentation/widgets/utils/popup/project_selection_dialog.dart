// Project selection dialog for first-time users
// Allows users to select an existing project, create a new one, or use a default project
// Used in empty states to help users get started with task creation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../core/result.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/task_calendar.dart';
import '../../../../data/models/caldav_account.dart';
import '../../../../l10n/app_localizations.dart';
import '../enhanced_text_field.dart';
import '../buttons/create_project_button.dart';

class ProjectSelectionDialog extends ConsumerStatefulWidget {
  const ProjectSelectionDialog({super.key});

  @override
  ConsumerState<ProjectSelectionDialog> createState() => _ProjectSelectionDialogState();
}

class _ProjectSelectionDialogState extends ConsumerState<ProjectSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Escape to close dialog
          if (event.logicalKey == LogicalKeyboardKey.escape && !_isLoading) {
            Navigator.of(context).pop();
          }
        }
      },
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectProjectForTask),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search field
                EnhancedTextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.searchProjects,
                    hintText: AppLocalizations.of(context)!.searchProjectsHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Quick action for default project
                _buildDefaultProjectOption(),
                
                const SizedBox(height: 16),
                
                // Divider
                const Divider(),
                
                const SizedBox(height: 8),
                
                // Existing projects list
                _buildProjectsList(),
                
                const SizedBox(height: 16),
                
                // Create new project option
                _buildCreateNewProjectOption(),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultProjectOption() {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _isLoading ? null : _createTaskInDefaultProject,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.defaultProject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.createTaskInDefaultProject,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsList() {
    return FutureBuilder<List<TaskCalendar>>(
      future: _getAvailableProjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final projects = snapshot.data ?? [];
        final filteredProjects = projects.where((project) {
          if (_searchQuery.isEmpty) return true;
          return project.displayName.toLowerCase().contains(_searchQuery) ||
                 (project.flowitDomain?.toLowerCase().contains(_searchQuery) ?? false);
        }).toList();

        if (filteredProjects.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _searchQuery.isEmpty 
                ? AppLocalizations.of(context)!.noProjectsFound
                : AppLocalizations.of(context)!.noProjectsMatchSearch,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredProjects.length,
            itemBuilder: (context, index) {
              final project = filteredProjects[index];
              return ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                title: Text(
                  project.displayName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: project.flowitDomain != null
                    ? Text(
                        project.flowitDomain!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      )
                    : null,
                onTap: _isLoading ? null : () => _createTaskInProject(project),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCreateNewProjectOption() {
    return CreateProjectButton(
      onProjectCreated: (projectName) {
        // Refresh the projects list and select the newly created project
        setState(() {});
        
        // Find the newly created project and return its path
        _getAvailableProjects().then((projects) {
          final newProject = projects.firstWhere(
            (project) => project.displayName == projectName,
            orElse: () => throw StateError('Newly created project not found'),
          );
          
          if (mounted) {
            Navigator.of(context).pop(newProject.path);
          }
        });
      },
    );
  }

  Future<List<TaskCalendar>> _getAvailableProjects() async {
    try {
      final calendarRepository = ref.read(calendarRepositoryProvider);
      final result = await calendarRepository.getAll();
      
      return result.when(
        success: (calendars) {
          // Filter to only show projects (not workflows)
          return calendars.where((calendar) {
            final isWorkflow = (calendar.flowitAsFlow == true) ||
                ((calendar.flowitType.toUpperCase()) == 'WORKFLOW');
            return !isWorkflow;
          }).toList();
        },
        failure: (failure) {
          AppLogger.warning('ProjectSelection: Failed to get projects: ${failure.message}');
          return <TaskCalendar>[];
        },
      );
    } catch (e) {
      AppLogger.error('ProjectSelection: Exception getting projects: $e');
      return <TaskCalendar>[];
    }
  }

  Future<void> _createTaskInDefaultProject() async {
    setState(() => _isLoading = true);

    try {
      // First, try to find an existing "default" project
      final projects = await _getAvailableProjects();
      TaskCalendar? defaultProject = projects.firstWhere(
        (project) => project.displayName.toLowerCase() == 'default',
        orElse: () => throw StateError('No default project found'),
      );

      // If no default project exists, create one
      defaultProject = await _createDefaultProject();

      if (defaultProject != null && mounted) {
        Navigator.of(context).pop(defaultProject.path);
      }
    } catch (e) {
      // No default project found, create one
      try {
        final defaultProject = await _createDefaultProject();
        if (defaultProject != null && mounted) {
          Navigator.of(context).pop(defaultProject.path);
        }
      } catch (createError) {
        AppLogger.error('ProjectSelection: Failed to create default project: $createError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create default project. Please try again.'),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<TaskCalendar?> _createDefaultProject() async {
    try {
      AppLogger.info('ProjectSelection: Creating default project');
      
      // Get active account
      final accountRepository = ref.read(accountRepositoryProvider);
      final accountResult = await accountRepository.getActiveAccount();
      CaldavAccount? account;
      accountResult.when(
        success: (acc) => account = acc,
        failure: (f) => throw Exception('No account: ${f.message}'),
      );

      if (account == null) {
        throw Exception('No active CalDAV account found');
      }

      // Create the default project
      final defaultProject = TaskCalendarFactory.createNew(
        path: '/temp/${DateTime.now().millisecondsSinceEpoch}', // Will be updated by repository
        displayName: 'Default',
        description: 'Default project for tasks without a specific project',
        domain: null,
        author: account!.email?.isNotEmpty == true ? account!.email : account!.username,
        owner: account!.email?.isNotEmpty == true ? account!.email : account!.username,
      );

      // Save the project
      final calendarRepository = ref.read(calendarRepositoryProvider);
      final saveResult = await calendarRepository.save(defaultProject);
      
      return saveResult.when(
        success: (_) {
          AppLogger.info('ProjectSelection: Default project created successfully');
          return defaultProject;
        },
        failure: (failure) {
          AppLogger.error('ProjectSelection: Failed to save default project: ${failure.message}');
          throw Exception('Failed to save default project: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('ProjectSelection: Exception creating default project: $e');
      rethrow;
    }
  }

  Future<void> _createTaskInProject(TaskCalendar project) async {
    if (mounted) {
      Navigator.of(context).pop(project.path);
    }
  }

}
