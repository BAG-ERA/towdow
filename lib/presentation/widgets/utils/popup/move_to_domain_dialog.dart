// Reusable move to domain dialog widget
// Used across the app for moving projects to domains

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../core/theme/chart_theme_usage.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/task_calendar.dart';
import 'domain_creation_dialog.dart';

class MoveToDomainDialog extends ConsumerStatefulWidget {
  final TaskCalendar project;

  const MoveToDomainDialog({
    super.key,
    required this.project,
  });

  @override
  ConsumerState<MoveToDomainDialog> createState() => _MoveToDomainDialogState();
}

class _MoveToDomainDialogState extends ConsumerState<MoveToDomainDialog> {
  String? selectedDomain;
  bool isLoading = false;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with current domain
    selectedDomain = widget.project.flowitDomain;
  }

  @override
  Widget build(BuildContext context) {
    // Get all available domains from DomainService
    return FutureBuilder<List<String>>(
      key: ValueKey(_refreshKey),
      future: _getAllAvailableDomains(),
      builder: (context, snapshot) {
        final availableDomains = snapshot.data ?? [];
        
        return _buildDialog(context, availableDomains);
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
          AppLogger.warning('MoveToDomain: Failed to get available domains: ${failure.message}');
          return <String>[];
        },
      );
    } catch (e) {
      AppLogger.error('MoveToDomain: Exception getting available domains: $e');
      return <String>[];
    }
  }

  Widget _buildDialog(BuildContext context, List<String> availableDomains) {

    return AlertDialog(
      title: Text('Move "${widget.project.displayName}" to Domain'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current domain: ${widget.project.domainDisplayName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            // Domain selection
            Text(
              'Select a domain:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            
            // No domain option
            RadioListTile<String?>(
              title: const Text('No domain'),
              value: null,
              groupValue: selectedDomain,
              onChanged: (value) => setState(() => selectedDomain = value),
              contentPadding: EdgeInsets.zero,
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isLoading ? null : _moveToDomain,
          child: isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Move'),
        ),
      ],
    );
  }

  void _showCreateDomainDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const DomainCreationDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        selectedDomain = result;
        _refreshKey++; // Trigger FutureBuilder rebuild
      });
    }
  }

  void _moveToDomain() async {
    setState(() => isLoading = true);

    try {
      final projectListViewModel = ref.read(projectListViewModelProvider.notifier);
      
      if (selectedDomain == null) {
        // Remove domain
        projectListViewModel.assignDomainToProject(widget.project.path, null);
        AppLogger.info('MoveToDomain: Removed domain from project ${widget.project.path}');
      } else {
        // Assign domain
        projectListViewModel.assignDomainToProject(widget.project.path, selectedDomain!);
        AppLogger.info('MoveToDomain: Assigned domain "$selectedDomain" to project ${widget.project.path}');
      }
      
      Navigator.of(context).pop();
    } catch (e) {
      AppLogger.error('MoveToDomain: Failed to move project to domain: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
} 