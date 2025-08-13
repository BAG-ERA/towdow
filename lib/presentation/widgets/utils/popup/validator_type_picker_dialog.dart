// Validator Type Picker dialog
// Lets the user pick which completion requirement (validator) type to add

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      title: const Text('Add completion requirement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _entry(
              context,
              icon: Icons.checklist,
              title: 'Checklist',
              subtitle: 'Multiple checkable items',
              value: 'checklist',
            ),
            _entry(
              context,
              icon: Icons.radio_button_checked,
              title: 'Single Select',
              subtitle: 'Choose one option',
              value: 'single_select',
            ),
            _entry(
              context,
              icon: Icons.text_fields,
              title: 'Free Field',
              subtitle: 'Text input',
              value: 'free_field',
            ),
            if (fileFeaturesEnabled)
              _entry(
                context,
                icon: Icons.attach_file,
                title: 'File',
                subtitle: 'File attachments',
                value: 'file',
              ),
            if (fileFeaturesEnabled)
              _entry(
                context,
                icon: Icons.perm_media,
                title: 'Media',
                subtitle: 'Photos and videos',
                value: 'media',
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
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


