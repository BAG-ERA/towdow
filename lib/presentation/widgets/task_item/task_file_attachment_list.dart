// Task file attachment list widget
// Displays file attachments for tasks with upload, download, and delete functionality
// Uses TaskFileAttachmentViewModel following MVVM architecture

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/task.dart';
import '../../viewmodels/task_file_attachment_viewmodel.dart';
import '../../../data/providers/providers.dart';
import '../../../core/logger.dart';
import 'dart:convert';

class TaskFileAttachmentList extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;

  const TaskFileAttachmentList({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  @override
  ConsumerState<TaskFileAttachmentList> createState() => _TaskFileAttachmentListState();
}

class _TaskFileAttachmentListState extends ConsumerState<TaskFileAttachmentList> {
  bool _hasShownMessage = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Expand by default if there's only one attachment
    final attachments = _parseAttachments(widget.task.attachments);
    _isExpanded = attachments.length <= 1;
  }

  @override
  Widget build(BuildContext context) {
    final attachmentState = ref.watch(taskFileAttachmentViewModelProvider(widget.task.uid));
    final attachments = _parseAttachments(widget.task.attachments);
    
    // Show error/success messages (prevent loop with flag)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownMessage) {
        if (attachmentState.error != null) {
          _showErrorSnackbar(attachmentState.error!);
          ref.read(taskFileAttachmentViewModelProvider(widget.task.uid).notifier).clearMessages();
          _hasShownMessage = true;
        } else if (attachmentState.successMessage != null) {
          _showSuccessSnackbar(attachmentState.successMessage!);
          ref.read(taskFileAttachmentViewModelProvider(widget.task.uid).notifier).clearMessages();
          _hasShownMessage = true;
        }
      }
    });
    
    // Reset flag when messages are cleared
    if (attachmentState.error == null && attachmentState.successMessage == null) {
      _hasShownMessage = false;
    }
    
    // Don't show anything if no attachments and no upload in progress
    if (attachments.isEmpty && !attachmentState.isUploading) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        
        // Section header with expand/collapse
        GestureDetector(
          onTap: attachments.isNotEmpty ? () => setState(() => _isExpanded = !_isExpanded) : null,
          child: Row(
            children: [
              Icon(
                Icons.attach_file,
                size: 14,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (attachments.isNotEmpty) ...[
                Text(
                  ' (${attachments.length})',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: attachments.isNotEmpty ? () => setState(() => _isExpanded = !_isExpanded) : null,
                  child: Container(
                    height: 24,
                    color: Colors.transparent,
                  ),
                ),
              ),
              
              // Expand/collapse indicator (only show if there are attachments)
              if (attachments.isNotEmpty) ...[
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
        
        // File list (only show if expanded or if there's only one item)
        if (_isExpanded || attachments.length <= 1) ...[
          const SizedBox(height: 4),
          ...attachments.asMap().entries.map((entry) {
            final index = entry.key;
            final attachment = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index < attachments.length - 1 ? 8 : 0),
              child: _buildFileItem(attachment, attachmentState),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildFileItem(Map<String, dynamic> attachment, TaskFileAttachmentState attachmentState) {
    final fileName = attachment['filename'] as String? ?? 'Unknown file';
    final fileSize = attachment['size'] as int? ?? 0;
    final createdAt = attachment['createdAt'] as String?;
    final fileId = attachment['uri'] as String;
    final fileStatus = attachment['status'] as String? ?? 'uploaded';
    // Note: s3Key and aesKey available if needed for debugging
    
    final isDownloadingThis = attachmentState.isDownloading && 
                             attachmentState.downloadingFileId == fileId;
    
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
                    Text(
                      ' • ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      _getStatusText(fileStatus),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getStatusColor(fileStatus, context),
                        fontWeight: fileStatus == 'local' ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    if (createdAt != null && fileStatus == 'uploaded') ...[
                      Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        _formatUploadDate(createdAt),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Download button
              IconButton(
                onPressed: isDownloadingThis ? null : () => _downloadFile(attachment),
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
              
              // Delete button (only if we can edit tasks)
              if (widget.onTaskUpdated != null) ...[
                IconButton(
                  onPressed: () => _removeFile(fileId),
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
        ],
      ),
    );
  }

  Future<void> _uploadFile() async {
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
      final success = await ref.read(taskFileAttachmentViewModelProvider(widget.task.uid).notifier)
          .uploadFile(
            taskUid: widget.task.uid,
            fileName: fileName,
            fileData: fileBytes,
            contentType: _getContentType(fileName),
          );

      // If upload succeeded, notify parent to refresh task data
      if (success && widget.onTaskUpdated != null) {
        // Refresh the task data from repository to get updated attachments
        _refreshTaskData();
      }

    } catch (e) {
      _showErrorSnackbar('Upload failed: $e');
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> attachment) async {
    final fileId = attachment['uri'] as String;
    final fileName = attachment['filename'] as String? ?? 'download';
    final s3Key = attachment['s3Key'] as String?;
    final encryptionKey = attachment['aesKey'] as String?;

    if (encryptionKey == null) {
      _showErrorSnackbar('Missing encryption key for file');
      return;
    }

    // Call ViewModel to handle download and get file bytes
    final downloadResult = await ref.read(taskFileAttachmentViewModelProvider(widget.task.uid).notifier)
        .downloadFileBytes(
          fileId: fileId,
          fileName: fileName,
          taskUid: widget.task.uid,
          encryptionKey: encryptionKey,
          s3Key: s3Key,
        );

    if (downloadResult == null) {
      _showErrorSnackbar('Download failed');
      return;
    }

    // Show file picker dialog to choose save location
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

  Future<void> _removeFile(String fileId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove File'),
        content: const Text('Are you sure you want to remove this file? This action cannot be undone.'),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Call ViewModel to handle file removal
    final success = await ref.read(taskFileAttachmentViewModelProvider(widget.task.uid).notifier)
        .removeFile(
          taskUid: widget.task.uid,
          fileId: fileId,
        );

    // If removal succeeded, notify parent to refresh task data
    if (success && widget.onTaskUpdated != null) {
      _refreshTaskData();
    }
  }

  void _refreshTaskData() {
    // Trigger a refresh of the task data
    // This is a simple approach - in a more sophisticated implementation,
    // we might use a more reactive approach
    if (widget.onTaskUpdated != null) {
      // The parent will refresh when onTaskUpdated is called
      // For now, we just trigger a rebuild
      setState(() {});
    }
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
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    AppLogger.debug('TaskFileAttachmentList._getContentType: File: $fileName, Extension: $extension');
    
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
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

  String _getStatusText(String status) {
    switch (status) {
      case 'local':
        return 'Local (will upload)';
      case 'uploading':
        return 'Uploading...';
      case 'uploaded':
        return 'Uploaded';
      case 'failed':
        return 'Upload failed';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status) {
      case 'local':
        return Theme.of(context).colorScheme.primary;
      case 'uploading':
        return Theme.of(context).colorScheme.secondary;
      case 'uploaded':
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
      case 'failed':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  List<Map<String, dynamic>> _parseAttachments(String attachmentsJson) {
    try {
      if (attachmentsJson.isEmpty || attachmentsJson == '[]') {
        return [];
      }
      
      final decoded = jsonDecode(attachmentsJson);
      if (decoded is List) {
        return decoded.map<Map<String, dynamic>>((attachment) {
          return attachment is Map<String, dynamic> ? attachment : <String, dynamic>{};
        }).toList();
      }
      
      return [];
    } catch (e) {
      AppLogger.error('TaskFileAttachmentList: Failed to parse attachments JSON', e, StackTrace.current);
      return [];
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