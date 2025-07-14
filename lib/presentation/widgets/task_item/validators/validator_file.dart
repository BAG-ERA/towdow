// File validator component for task items
// Displays file attachments with upload/download capabilities
// Follows MVVM architecture - all business logic is in FileValidatorViewModel

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../viewmodels/file_validator_viewmodel.dart';
import '../../../../core/logger.dart';

class ValidatorFile extends ConsumerStatefulWidget {
  final Map<String, dynamic> validator;
  final String taskUid;
  final bool isOrganizer;
  final Function(String validatorId, Map<String, dynamic> updateData) onValidatorUpdated;

  const ValidatorFile({
    super.key,
    required this.validator,
    required this.taskUid,
    required this.isOrganizer,
    required this.onValidatorUpdated,
  });

  @override
  ConsumerState<ValidatorFile> createState() => _ValidatorFileState();
}

class _ValidatorFileState extends ConsumerState<ValidatorFile> {
  bool _hasShownMessage = false;

  @override
  Widget build(BuildContext context) {
    final fileValidatorState = ref.watch(fileValidatorViewModelProvider(widget.taskUid));
    final files = widget.validator['files'] as List<dynamic>? ?? [];
    final validatorId = widget.validator['id'] as String;
    final helper = widget.validator['helper'] as String?;
    
    // Show error/success messages (prevent loop with flag)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownMessage) {
        if (fileValidatorState.error != null) {
          _showErrorSnackbar(fileValidatorState.error!);
          ref.read(fileValidatorViewModelProvider(widget.taskUid).notifier).clearMessages();
          _hasShownMessage = true;
        } else if (fileValidatorState.successMessage != null) {
          _showSuccessSnackbar(fileValidatorState.successMessage!);
          ref.read(fileValidatorViewModelProvider(widget.taskUid).notifier).clearMessages();
          _hasShownMessage = true;
        }
      }
    });
    
    // Reset flag when messages are cleared
    if (fileValidatorState.error == null && fileValidatorState.successMessage == null) {
      _hasShownMessage = false;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (helper != null && helper.isNotEmpty) ...[
          Text(
            helper,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // File list
        if (files.isNotEmpty) ...[
          ...files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value as Map<String, dynamic>;
            return Padding(
              padding: EdgeInsets.only(bottom: index < files.length - 1 ? 8 : 0),
              child: _buildFileItem(file, validatorId, fileValidatorState),
            );
          }),
          const SizedBox(height: 8),
        ],
        
        // Upload button - only show when no files
        if (files.isEmpty) ...[
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: fileValidatorState.isUploading ? null : () => _uploadFile(validatorId),
                icon: fileValidatorState.isUploading 
                    ? const SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file, size: 16),
                label: Text(fileValidatorState.isUploading ? 'Uploading...' : 'Upload File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file, String validatorId, FileValidatorState fileValidatorState) {
    final fileName = file['name'] as String? ?? 'Unknown file';
    final fileSize = file['size'] as int? ?? 0;
    final uploadedAt = file['uploadedAt'] as String?;
    final fileId = file['id'] as String;
    
    final isDownloadingThis = fileValidatorState.isDownloading && 
                             fileValidatorState.downloadingFileId == fileId;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(fileName),
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (uploadedAt != null) ...[
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        _formatUploadDate(uploadedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Action buttons
          // Download button
          IconButton(
            onPressed: isDownloadingThis ? null : () => _downloadFile(file),
            icon: isDownloadingThis
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 16),
            tooltip: 'Download',
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
            ),
          ),
          
          // Delete button (only for organizer)
          if (widget.isOrganizer) ...[
            IconButton(
              onPressed: () => _removeFile(validatorId, fileId),
              icon: const Icon(Icons.delete_outline, size: 16),
              tooltip: 'Remove',
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadFile(String validatorId) async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      Uint8List? fileBytes = file.bytes;

      // Handle desktop file reading
      if (fileBytes == null && file.path != null) {
        try {
          final fileObj = File(file.path!);
          fileBytes = await fileObj.readAsBytes();
        } catch (e) {
          _showErrorSnackbar('Could not read file: $e');
          return;
        }
      }

      if (fileBytes == null) {
        _showErrorSnackbar('Could not read file data');
        return;
      }

      // Call ViewModel to handle upload
      final success = await ref.read(fileValidatorViewModelProvider(widget.taskUid).notifier)
          .uploadFile(
            taskUid: widget.taskUid,
            validatorId: validatorId,
            fileName: fileName,
            fileData: fileBytes,
            contentType: _getContentType(fileName),
          );

      // If upload succeeded, notify parent to refresh validator data
      if (success) {
        // Notify parent that task was updated so it can refresh the validator data
        widget.onValidatorUpdated(validatorId, {'type': 'refresh'});
      }

    } catch (e) {
      _showErrorSnackbar('Upload failed: $e');
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    final fileId = file['id'] as String;
    final fileName = file['name'] as String? ?? 'download';
    final s3Key = file['s3Key'] as String?;

    if (s3Key == null) {
      _showErrorSnackbar('File download information not available');
      return;
    }

    // Call ViewModel to handle download and get file bytes
    final downloadResult = await ref.read(fileValidatorViewModelProvider(widget.taskUid).notifier)
        .downloadFileBytes(
          fileId: fileId,
          fileName: fileName,
          s3Key: s3Key,
        );

    if (downloadResult == null) {
      _showErrorSnackbar('Download failed');
      return;
    }

    // Show file picker dialog to choose save location with bytes for Android/iOS
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save File',
      fileName: fileName,
      type: FileType.any,
      bytes: downloadResult, // Provide bytes for Android/iOS compatibility
    );

    if (savePath != null) {
      _showSuccessSnackbar('File saved successfully');
    }
  }

  Future<void> _removeFile(String validatorId, String fileId) async {
    // Call ViewModel to handle file removal
    final success = await ref.read(fileValidatorViewModelProvider(widget.taskUid).notifier)
        .removeFile(
          taskUid: widget.taskUid,
          validatorId: validatorId,
          fileId: fileId,
        );

    // If removal succeeded, notify parent to refresh validator data
    if (success) {
      // Notify parent that task was updated so it can refresh the validator data
      widget.onValidatorUpdated(validatorId, {'type': 'refresh'});
    }
  }

  Future<void> _downloadAllFiles(List<dynamic> files) async {
    // For bulk download, ask user to choose a directory
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose Download Directory',
    );

    if (directory == null) {
      // User cancelled the directory selection
      return;
    }

    // Download files one by one to the chosen directory
    for (final file in files) {
      final fileId = file['id'] as String;
      final fileName = file['name'] as String? ?? 'download';
      final s3Key = file['s3Key'] as String?;

      if (s3Key != null) {
        final savePath = '$directory/$fileName';
        await ref.read(fileValidatorViewModelProvider(widget.taskUid).notifier)
            .downloadFile(
              fileId: fileId,
              fileName: fileName,
              s3Key: s3Key,
              savePath: savePath,
            );
      }
    }
  }

  Future<void> _removeAllFiles(String validatorId, List<dynamic> files) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Files'),
        content: Text('Are you sure you want to delete all ${files.length} file(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Remove files one by one
    for (final file in files) {
      final fileId = file['id'] as String;
      await ref.read(fileValidatorViewModelProvider(widget.taskUid).notifier)
          .removeFile(
            taskUid: widget.taskUid,
            validatorId: validatorId,
            fileId: fileId,
          );
    }
    
    // Notify parent that task was updated so it can refresh the validator data
    widget.onValidatorUpdated(validatorId, {'type': 'refresh'});
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'svg':
      case 'webp':
      case 'ico':
      case 'tiff':
      case 'tif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'webm':
      case 'm4v':
      case '3gp':
      case 'flv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'ogg':
      case 'm4a':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'txt':
      case 'md':
        return Icons.text_snippet;
      case 'ics':
        return Icons.calendar_today;
      case 'csv':
        return Icons.table_chart;
      case 'json':
      case 'xml':
        return Icons.code;
      case 'html':
      case 'htm':
      case 'css':
      case 'js':
        return Icons.web;
      case 'rtf':
      case 'odt':
      case 'ods':
      case 'odp':
        return Icons.description;
      case 'exe':
      case 'msi':
      case 'deb':
      case 'rpm':
      case 'dmg':
      case 'pkg':
      case 'apk':
      case 'ipa':
        return Icons.apps;
      default:
        // For unknown extensions, use a more specific default icon
        return Icons.insert_drive_file_outlined;
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    // Log the file extension for debugging
    AppLogger.debug('ValidatorFile._getContentType: File: $fileName, Extension: $extension');
    
    // For certain problematic extensions that cause S3 signature issues,
    // use application/octet-stream instead of specific content types
    final problematicExtensions = {'ics', 'zip', 'rar', '7z', 'exe', 'msi', 'deb', 'rpm', 'dmg', 'pkg', 'apk', 'ipa'};
    
    if (problematicExtensions.contains(extension)) {
      AppLogger.debug('ValidatorFile._getContentType: Using octet-stream for potentially problematic extension: $extension');
      return 'application/octet-stream';
    }
    
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'md':
        return 'text/markdown';
      case 'rtf':
        return 'application/rtf';
      case 'odt':
        return 'application/vnd.oasis.opendocument.text';
      case 'ods':
        return 'application/vnd.oasis.opendocument.spreadsheet';
      case 'odp':
        return 'application/vnd.oasis.opendocument.presentation';
      case 'svg':
        return 'image/svg+xml';
      case 'webp':
        return 'image/webp';
      case 'ico':
        return 'image/x-icon';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      case 'webm':
        return 'video/webm';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      case 'm4v':
        return 'video/mp4';
      case '3gp':
        return 'video/3gpp';
      case 'flv':
        return 'video/x-flv';
      case 'swf':
        return 'application/x-shockwave-flash';
      default:
        AppLogger.debug('ValidatorFile._getContentType: Unknown extension: $extension, using application/octet-stream');
        return 'application/octet-stream';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatUploadDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
} 