// Export dialog for calendar data
// Shows export progress and allows file selection

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../data/services/export_import_service.dart';
import '../../../../data/providers/providers.dart';
import '../../../../core/logger.dart';

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  bool _isExporting = false;
  String? _exportPath;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          // Handle Escape to close dialog
          if (event.logicalKey == LogicalKeyboardKey.escape && !_isExporting) {
            Navigator.of(context).pop();
          }
        }
      },
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_rounded),
            SizedBox(width: 8),
            Text('Export Calendars'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 500 ? 450 : MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Export all your calendars and tasks to a zip file. This will include all VTODO items from your projects.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              if (_isExporting) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Exporting calendars...'),
              ] else if (_exportPath != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Export completed!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'File saved to:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _exportPath!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Export failed',
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
                const Text('Click "Export" to choose where to save the file'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (!_isExporting && _exportPath == null)
            ElevatedButton(
              onPressed: _startExport,
              child: const Text('Export'),
            ),
          if (_exportPath != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSuccessMessage();
              },
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }

  Future<void> _startExport() async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      // First, create the export file
      final exportService = ref.read(exportImportServiceProvider);
      final result = await exportService.exportCalendars();

      await result.when(
        success: (tempPath) async {
          // Now let user choose where to save it
          final savePath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Export File',
            fileName: 'towdow-export-${DateTime.now().millisecondsSinceEpoch}.zip',
            allowedExtensions: ['zip'],
          );

          if (savePath != null) {
            // Copy the temp file to the chosen location
            final tempFile = File(tempPath);
            final saveFile = File(savePath);
            await tempFile.copy(saveFile.path);
            
            // Clean up temp file
            await tempFile.delete();

            setState(() {
              _exportPath = savePath;
              _isExporting = false;
            });
          } else {
            // User cancelled file selection
            setState(() {
              _isExporting = false;
            });
          }
        },
        failure: (failure) async {
          AppLogger.error('ExportDialog: Export failed', failure.exception, failure.stackTrace);
          setState(() {
            _errorMessage = failure.message;
            _isExporting = false;
          });
        },
      );
    } catch (e, stackTrace) {
      AppLogger.error('ExportDialog: Unexpected error during export', e, stackTrace);
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _isExporting = false;
      });
    }
  }

  void _showSuccessMessage() {
    if (context.mounted) {
      // Export completed successfully - no notification needed
    }
  }
} 