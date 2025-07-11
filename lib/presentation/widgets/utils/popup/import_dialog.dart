// Import dialog for calendar data
// Lets user pick a zip file, shows progress, and displays result

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';

class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  bool _isImporting = false;
  String? _importPath;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.upload_rounded),
          SizedBox(width: 8),
          Text('Import Calendars'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Import calendars and tasks from a previously exported zip file.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_isImporting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Importing data...'),
            ] else if (_importPath != null) ...[
              const Icon(Icons.file_present, color: Colors.blue, size: 48),
              const SizedBox(height: 16),
              Text(
                'File selected:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _importPath!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ] else if (_errorMessage != null) ...[
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Import failed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.folder_open_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Click "Select File" to choose a zip file'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_isImporting)
          ElevatedButton(
            onPressed: _selectFile,
            child: const Text('Select File'),
          ),
        if (!_isImporting && _importPath != null)
          ElevatedButton(
            onPressed: _performImport,
            child: const Text('Import'),
          ),
      ],
    );
  }

  Future<void> _performImport() async {
    if (_importPath == null) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      final exportService = ref.read(exportImportServiceProvider);
      final result = await exportService.importCalendars(_importPath!);

      if (mounted) {
        result.when(
          success: (importResult) {
            setState(() {
              _isImporting = false;
            });

            // Show success dialog with details
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Import Completed'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✅ ${importResult.summary}'),
                    if (importResult.hasErrors) ...[
                      const SizedBox(height: 16),
                      const Text('⚠️ Some errors occurred:'),
                      const SizedBox(height: 8),
                      ...importResult.errors.take(3).map((error) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $error', style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      if (importResult.errors.length > 3)
                        Text('... and ${importResult.errors.length - 3} more errors'),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
          failure: (failure) {
            setState(() {
              _isImporting = false;
              _errorMessage = failure.message;
            });
          },
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('ImportDialog: Import failed', e, stackTrace);
      if (mounted) {
        setState(() {
          _isImporting = false;
          _errorMessage = 'Import failed: $e';
        });
      }
    }
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Import File',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      
      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          setState(() {
            _importPath = filePath;
            _errorMessage = null;
          });
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('ImportDialog: File selection failed', e, stackTrace);
      setState(() {
        _errorMessage = 'File selection failed: $e';
      });
    }
  }
} 