// Reusable project creation dialog widget
// Used across the app for creating new projects

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Add this import for navigation
import '../../../../core/logger.dart';
import '../../../../core/theme/chart_theme_usage.dart';
import '../../../../data/providers/providers.dart';
import '../../../../app.dart'; // Add this import for globalNavigatorKey
import 'domain_creation_dialog.dart';
import '../enhanced_text_field.dart';
import '../../../viewmodels/project_creation_viewmodel.dart';

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
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Escape to close dialog
          if (event.logicalKey == LogicalKeyboardKey.escape && !isLoading) {
            Navigator.of(context).pop();
          }
          // Handle Ctrl+Enter or Cmd+Enter to submit
          else if (event.logicalKey == LogicalKeyboardKey.enter && 
                   (HardwareKeyboard.instance.isControlPressed || 
                    HardwareKeyboard.instance.isMetaPressed) &&
                   _canCreate() && !isLoading) {
            _createProject();
          }
        }
      },
      child: AlertDialog(
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
                        style: context.domainNameStyle.copyWith(
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
      ),
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
    if (projectName.isEmpty) return;

    setState(() => isLoading = true);

    final vm = ref.read(projectCreationViewModelProvider.notifier);
    await vm.createProject(
      name: projectName,
      description: projectDescription.isEmpty ? 'Project created by FlowIt' : projectDescription,
      domain: selectedDomain,
    );

    final state = ref.read(projectCreationViewModelProvider);
    AppLogger.info('ProjectCreation: Create project completed. Error: ${state.error}, ProjectPath: ${state.createdProjectPath}');
    
    if (state.error == null && mounted) {
      if (mounted) {
        Navigator.of(context).pop(projectName);

        // Navigate to the created project's detail page if we have the project path
        if (state.createdProjectPath != null) {
          // Navigate using global navigator key with a short delay
          final projectPath = state.createdProjectPath!;
          Future.delayed(const Duration(milliseconds: 400), () {
            final encodedPath = Uri.encodeComponent(projectPath);
            globalNavigatorKey.currentContext?.go('/project/$encodedPath');
          });
        }
      }
    }

    if (mounted) setState(() => isLoading = false);
  }
} 