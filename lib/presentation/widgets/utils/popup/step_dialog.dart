// Step creation dialog
// Collects step name and options, and creates the step via StepViewModel (MVVM)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger.dart';
import '../../../../data/providers/providers.dart';
import '../../../../l10n/app_localizations.dart';

class StepDialog extends ConsumerStatefulWidget {
  final String projectPath;
  final int initialOrder;
  final String? previousStepId;

  const StepDialog({super.key, required this.projectPath, required this.initialOrder, this.previousStepId});

  static Future<bool?> show(BuildContext context, {required String projectPath, required int initialOrder, String? previousStepId}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => StepDialog(projectPath: projectPath, initialOrder: initialOrder, previousStepId: previousStepId),
    );
  }

  @override
  ConsumerState<StepDialog> createState() => _StepDialogState();
}

class _StepDialogState extends ConsumerState<StepDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _endWorkflow = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Step ${widget.initialOrder + 1}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isSubmitting;

  Future<void> _submit() async {
    if (!_canCreate) return;
    setState(() => _isSubmitting = true);
    try {
      final vm = ref.read(projectStepViewModelProvider(widget.projectPath).notifier);
      await vm.createStep(
        id: '', // Repository auto-generates id
        name: _nameController.text.trim(),
        order: widget.initialOrder,
        endWorkflow: _endWorkflow,
        dependsOn: widget.previousStepId != null ? [widget.previousStepId!] : const [],
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      AppLogger.error('StepDialog: Failed to create step', e, st);
      if (mounted) {
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape && !_isSubmitting) {
            Navigator.of(context).pop(false);
          }
          if (event.logicalKey == LogicalKeyboardKey.enter && _canCreate) {
            _submit();
          }
        }
      },
      child: AlertDialog(
        title: Text(AppLocalizations.of(context)!.addStepDialogTitle),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.stepNameLabel,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _canCreate ? _submit() : null,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _endWorkflow,
                onChanged: (v) => setState(() => _endWorkflow = v ?? false),
                title: Text(AppLocalizations.of(context)!.markAsFinalStep),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: _canCreate ? _submit : null,
            child: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(AppLocalizations.of(context)!.create),
          ),
        ],
      ),
    );
  }
}


