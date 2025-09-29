// Validator Type Picker dialog
// Lets the user pick which completion requirement (validator) type to add

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:towdow_app/l10n/app_localizations.dart';
import '../../../../data/providers/providers.dart';

/// Presents an AlertDialog with the available validator types.
/// Returns the picked type key (e.g. 'checklist', 'single_select', 'free_field', 'file', 'media'),
/// or null if cancelled.
class ValidatorTypePickerDialog extends ConsumerWidget {
  const ValidatorTypePickerDialog({super.key});

  static Future<String?> show(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const ValidatorTypePickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileFeaturesEnabled = ref.watch(fileFeaturesEnabledProvider);

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.addCompletionRequirement),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _entry(
              context,
              icon: Icons.checklist,
              title: AppLocalizations.of(context)!.checklist,
              subtitle: AppLocalizations.of(context)!.checklistSubtitle,
              value: 'checklist',
            ),
            _entry(
              context,
              icon: Icons.radio_button_checked,
              title: AppLocalizations.of(context)!.singleSelect,
              subtitle: AppLocalizations.of(context)!.singleSelectSubtitle,
              value: 'single_select',
            ),
            _entry(
              context,
              icon: Icons.text_fields,
              title: AppLocalizations.of(context)!.freeField,
              subtitle: AppLocalizations.of(context)!.freeFieldSubtitle,
              value: 'free_field',
            ),
            if (fileFeaturesEnabled)
              _entry(
                context,
                icon: Icons.attach_file,
                title: AppLocalizations.of(context)!.file,
                subtitle: AppLocalizations.of(context)!.fileSubtitle,
                value: 'file',
              ),
            if (fileFeaturesEnabled)
              _entry(
                context,
                icon: Icons.perm_media,
                title: AppLocalizations.of(context)!.media,
                subtitle: AppLocalizations.of(context)!.mediaSubtitle,
                value: 'media',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
      ],
    );
  }

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.of(context).pop(value),
      contentPadding: EdgeInsets.zero,
    );
  }
}


