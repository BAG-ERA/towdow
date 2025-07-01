// Reusable domain creation dialog widget
// Used across the app for creating new domains

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/providers/providers.dart';

class DomainCreationDialog extends ConsumerStatefulWidget {
  const DomainCreationDialog({super.key});

  @override
  ConsumerState<DomainCreationDialog> createState() => _DomainCreationDialogState();
}

class _DomainCreationDialogState extends ConsumerState<DomainCreationDialog> {
  final TextEditingController domainController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Domain'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Domains help organize projects into logical groups.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: domainController,
              decoration: const InputDecoration(
                labelText: 'Domain name *',
                hintText: 'e.g., Work, Personal, Client Projects',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _canCreate() ? _createDomain() : null,
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
          onPressed: isLoading || !_canCreate() ? null : _createDomain,
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
    return domainController.text.trim().isNotEmpty;
  }

  void _createDomain() async {
    final domainName = domainController.text.trim();
    
    if (domainName.isEmpty) {
      return;
    }

    setState(() => isLoading = true);

    try {
      AppLogger.info('DomainCreation: Creating domain "$domainName"');
      
      final domainService = ref.read(domainServiceProvider);
      final result = await domainService.createDomain(domainName);
      
      result.when(
        success: (_) {
          // Refresh the project list to show the new domain
          ref.read(projectListViewModelProvider.notifier).refresh();
          
          Navigator.of(context).pop(domainName);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Domain "$domainName" created successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
        failure: (failure) {
          AppLogger.error('DomainCreation: Failed to create domain: ${failure.message}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create domain: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
      );
    } catch (e) {
      AppLogger.error('DomainCreation: Exception creating domain: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create domain: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
} 