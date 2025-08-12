// Requirement mapping dialog shown when starting a workflow
// Lists all project requirements and lets the user assign at least one email to each

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/logger.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../../data/models/requirement.dart';
import '../../../../data/providers/providers.dart';

class RequirementMappingDialog extends ConsumerStatefulWidget {
  final String projectPath;

  const RequirementMappingDialog({super.key, required this.projectPath});

  @override
  ConsumerState<RequirementMappingDialog> createState() => _RequirementMappingDialogState();
}

class _RequirementMappingDialogState extends ConsumerState<RequirementMappingDialog> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<String>> _emailsByRequirement = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requirementsAsync = ref.watch(projectRequirementsProvider(widget.projectPath));

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && !_isSubmitting) {
          Navigator.of(context).pop();
        }
      },
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.groups_rounded),
            SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.assignAttendeesToRequirements),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 700 ? 600 : MediaQuery.of(context).size.width * 0.9,
          child: requirementsAsync.when(
            data: (requirements) {
              if (requirements.isEmpty) {
                return Text(AppLocalizations.of(context)!.noRequirementsDefined);
              }

              // Initialize controllers and local state once
              for (final r in requirements) {
                _controllers.putIfAbsent(r.id, () => TextEditingController());
                _emailsByRequirement.putIfAbsent(r.id, () => List<String>.from(r.attendeeEmails));
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.requirementsIntro,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ...requirements.map((r) => _buildRequirementRow(context, r)).toList(),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('${AppLocalizations.of(context)!.failedToLoad}: $e'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _onSubmit,
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_circle_fill_rounded),
            label: Text(_isSubmitting ? AppLocalizations.of(context)!.startingWorkflow : AppLocalizations.of(context)!.startWorkflow),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(BuildContext context, Requirement requirement) {
    final controller = _controllers[requirement.id]!;
    final emails = _emailsByRequirement[requirement.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(requirement.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...emails.map((email) => InputChip(
                    label: Text(email),
                    onDeleted: () {
                      setState(() => emails.remove(email));
                    },
                  )),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.addEmail,
                    prefixIcon: const Icon(Icons.email_rounded),
                  ),
                  onSubmitted: (_) => _onAddEmail(requirement.id),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _onAddEmail(requirement.id),
                icon: const Icon(Icons.add_rounded),
                label: Text(AppLocalizations.of(context)!.add),
              )
            ],
          ),
          if (emails.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppLocalizations.of(context)!.atLeastOneEmailRequired,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  void _onAddEmail(String requirementId) {
    final controller = _controllers[requirementId]!;
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.failedToLoad}: $text')),
      );
      return;
    }
    final emails = _emailsByRequirement[requirementId]!;
    if (emails.any((e) => e.toLowerCase() == text.toLowerCase())) {
      controller.clear();
      return;
    }
    setState(() {
      emails.add(text);
      controller.clear();
    });
  }

  Future<void> _onSubmit() async {
    // Validate: every requirement has at least one email
    for (final entry in _emailsByRequirement.entries) {
      if (entry.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noneFound('email'))),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final reqRepo = ref.read(requirementRepositoryProvider);
      // Persist each requirement mapping
      for (final entry in _emailsByRequirement.entries) {
        final reqRes = await reqRepo.getRequirementById(entry.key);
        await reqRes.when(
          success: (req) async {
            if (req != null) {
              final updated = req.copyWith(attendeeEmails: entry.value);
              await reqRepo.updateRequirement(updated);
            }
          },
          failure: (f) async {
            AppLogger.warning('RequirementMappingDialog: Failed to load requirement ${entry.key}: ${f.message}');
          },
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      AppLogger.error('RequirementMappingDialog: Failed to persist mappings', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.failedToLoad}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}


