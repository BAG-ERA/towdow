// Reusable domain rename dialog widget
// Used for renaming existing domains in the navbar

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import '../../../../data/providers/providers.dart';

class DomainRenameDialog extends ConsumerStatefulWidget {
  final String currentDomainName;
  
  const DomainRenameDialog({
    super.key,
    required this.currentDomainName,
  });

  @override
  ConsumerState<DomainRenameDialog> createState() => _DomainRenameDialogState();
}

class _DomainRenameDialogState extends ConsumerState<DomainRenameDialog> {
  late final TextEditingController domainController;
  late final FocusNode focusNode;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    domainController = TextEditingController(text: widget.currentDomainName);
    focusNode = FocusNode();
    
    // Select all text when dialog opens and gains focus
    focusNode.addListener(() {
      if (focusNode.hasFocus && mounted) {
        // Use a slight delay to ensure the text field is fully initialized
        Future.microtask(() {
          if (mounted && domainController.text.isNotEmpty) {
            domainController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: domainController.text.length,
            );
          }
        });
      }
    });
    
    // Also try to select all text after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && domainController.text.isNotEmpty) {
        domainController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: domainController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    domainController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Domain'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rename the domain "${widget.currentDomainName}". All projects in this domain will be updated.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            
            KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (KeyEvent event) {
                // Handle Ctrl+A for select all
                if (event is KeyDownEvent && 
                    event.logicalKey == LogicalKeyboardKey.keyA && 
                    (HardwareKeyboard.instance.isControlPressed)) {
                  if (domainController.text.isNotEmpty) {
                    domainController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: domainController.text.length,
                    );
                  }
                }
                // Handle Escape to close dialog
                else if (event is KeyDownEvent && 
                         event.logicalKey == LogicalKeyboardKey.escape && 
                         !isLoading) {
                  Navigator.of(context).pop();
                }
              },
              child: Focus(
                child: TextField(
                  controller: domainController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Domain name *',
                    hintText: 'e.g., Work, Personal, Client Projects',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  enableInteractiveSelection: true,
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.text,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _canRename() ? _renameDomain() : null,
                  onTap: () {
                    // Ensure all keyboard shortcuts work by maintaining proper focus
                    if (!focusNode.hasFocus) {
                      focusNode.requestFocus();
                    }
                  },
                ),
              ),
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
          onPressed: isLoading || !_canRename() ? null : _renameDomain,
          child: isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Rename'),
        ),
      ],
    );
  }

  bool _canRename() {
    final newName = domainController.text.trim();
    return newName.isNotEmpty && newName != widget.currentDomainName;
  }

  void _renameDomain() async {
    final newDomainName = domainController.text.trim();
    
    if (newDomainName.isEmpty || newDomainName == widget.currentDomainName) {
      return;
    }

    setState(() => isLoading = true);

    try {
      AppLogger.info('DomainRename: Renaming domain "${widget.currentDomainName}" to "$newDomainName"');
      
      final domainService = ref.read(domainServiceProvider);
      final result = await domainService.renameDomain(widget.currentDomainName, newDomainName);
      
      result.when(
        success: (_) {
          // Refresh the project list to show the renamed domain
          ref.read(projectListViewModelProvider.notifier).refresh();
          
          Navigator.of(context).pop(newDomainName);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Domain renamed to "$newDomainName" successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
        failure: (failure) {
          AppLogger.error('DomainRename: Failed to rename domain: ${failure.message}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to rename domain: ${failure.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        },
      );
    } catch (e) {
      AppLogger.error('DomainRename: Exception renaming domain: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to rename domain: $e'),
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