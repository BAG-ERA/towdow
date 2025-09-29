// Task file attachment list component
// Displays file attachments for a task and handles file operations

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/logger.dart';
import '../../../data/models/task.dart';
import '../../../data/models/attachment.dart';
import '../../../data/providers/providers_project.dart';
import '../../../data/providers/providers_viewmodels.dart';
import '../../../l10n/app_localizations.dart';

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
  @override
  Widget build(BuildContext context) {
    // Watch the reactive task data from the repository
    final taskListAsync = ref.watch(taskListProvider);
    
    // Find the current task in the reactive data
    final currentTask = taskListAsync.when(
      data: (tasks) {
        // Find the task with matching UID in the reactive data
        final updatedTask = tasks.firstWhere(
          (task) => task.uid == widget.task.uid,
          orElse: () => widget.task, // Fallback to prop if not found
        );
        return updatedTask;
      },
      loading: () => widget.task, // Use prop while loading
      error: (error, stack) => widget.task, // Use prop on error
    );

    // Watch the unified attachment view model state
    final attachmentState = ref.watch(unifiedAttachmentViewModelProvider);

    // Parse attachments from the current task using the unified viewmodel
    final attachments = ref.read(unifiedAttachmentViewModelProvider.notifier).parseAttachments(currentTask.attachments);

    // Always show the header and add button, even if there are no attachments

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.attach_file,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.files,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            if (attachmentState.isUploading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            IconButton(
              onPressed: _uploadFile,
              icon: const Icon(Icons.add, size: 16),
              tooltip: AppLocalizations.of(context)!.addFile,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ],
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...attachments.map((attachment) => _buildAttachmentTile(attachment)),
        ],
        if (attachmentState.error != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachmentState.error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ref.read(unifiedAttachmentViewModelProvider.notifier).clearMessages();
                  },
                  icon: const Icon(Icons.close, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentTile(Attachment attachment) {
    final fileId = attachment.uri;
    final fileName = attachment.filename;
    final fileSize = attachment.size;
    final status = attachment.status;
    final s3Key = attachment.s3Key;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(fileName),
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      _formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    if (status == 'local') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.local,
                          style: TextStyle(
                            fontSize: 8,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ] else if (s3Key != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.cloud,
                          style: TextStyle(
                            fontSize: 8,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'download':
                  _downloadFile(attachment);
                  break;
                case 'remove':
                  _removeFile(fileId);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (s3Key != null)
                PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 16),
                      SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.download),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16),
                    SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.remove),
                  ],
                ),
              ),
            ],
            child: const Icon(Icons.more_vert, size: 16),
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
          // Error will be handled by the ViewModel state
          return;
        }
      }

      if (fileBytes == null) {
        // Error will be handled by the ViewModel state
        return;
      }

      // Call unified ViewModel to handle upload
      await ref.read(unifiedAttachmentViewModelProvider.notifier)
          .uploadTaskAttachment(
            taskUid: widget.task.uid,
            fileName: fileName,
            fileData: fileBytes,
            contentType: _getContentType(fileName),
            type: AttachmentType.file,
          );

      // If upload succeeded, the task will be automatically updated via the reactive stream

    } catch (e) {
      // Error will be handled by the ViewModel state
    }
  }

  Future<void> _downloadFile(Attachment attachment) async {
    final fileId = attachment.uri;
    final fileName = attachment.filename;
    final s3Key = attachment.s3Key;
    final encryptionKey = attachment.aesKey;

    AppLogger.debug('TaskFileAttachmentList: Starting download for file $fileId ($fileName)');


    Uint8List? downloadResult;
    try {
      // Call unified ViewModel to handle download and get file bytes
      downloadResult = await ref.read(unifiedAttachmentViewModelProvider.notifier)
          .downloadAttachment(
            fileId: fileId,
            aesKey: encryptionKey,
            s3Key: s3Key,
          );

      if (downloadResult == null) {
        AppLogger.error('TaskFileAttachmentList: Download returned null for file $fileId');
        return;
      }

      AppLogger.debug('TaskFileAttachmentList: Download successful, got ${downloadResult.length} bytes');
    } catch (e, stackTrace) {
      AppLogger.error('TaskFileAttachmentList: Download failed for file $fileId', e, stackTrace);
      return;
    }

    // Show file picker dialog to choose save location
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: AppLocalizations.of(context)!.saveFile,
      fileName: fileName,
      type: FileType.any,
    );

    if (savePath != null) {
      try {
        // Actually write the file to the chosen location
        final saveFile = File(savePath);
        await saveFile.writeAsBytes(downloadResult);
      } catch (e) {
        AppLogger.error('TaskFileAttachmentList: Failed to save file', e);
      }
    }
  }

  Future<void> _removeFile(String fileId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeFile),
        content: Text(AppLocalizations.of(context)!.removeFileConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(AppLocalizations.of(context)!.remove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Call unified ViewModel to handle file removal
    await ref.read(unifiedAttachmentViewModelProvider.notifier)
        .removeTaskAttachment(
          taskUid: widget.task.uid,
          fileId: fileId,
        );
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
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'webp':
        return 'image/webp';
      case 'ico':
        return 'image/x-icon';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      case '3gp':
        return 'video/3gpp';
      case 'flv':
        return 'video/x-flv';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case '7z':
        return 'application/x-7z-compressed';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
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
}
