// Reusable domain creation dialog widget
// Used across the app for creating new domains

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/providers/providers.dart';
import '../enhanced_text_field.dart';

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
            _createDomain();
          }
        }
      },
      child: AlertDialog(
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
              
              EnhancedTextField(
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
      ),
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
          
        },
        failure: (failure) {
          AppLogger.error('DomainCreation: Failed to create domain: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('DomainCreation: Exception creating domain: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
} 