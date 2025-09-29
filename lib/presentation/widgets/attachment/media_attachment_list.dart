// Task media attachment list widget for displaying media attachments with image preview
// Reuses components from media validator but adapts for task media attachments
// Follows MVVM architecture - UI logic delegated to TaskMediaAttachmentViewModel

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/task.dart';
import '../../../data/models/attachment.dart';
import '../../../data/providers/providers_project.dart';
import '../../../data/providers/providers_viewmodels.dart';

import '../../viewmodels/attachment_viewmodel.dart';
import '../utils/image_thumbnail.dart';
import '../utils/full_screen_image_viewer.dart';
import '../../../core/logger.dart';
import '../../../l10n/app_localizations.dart';

class TaskMediaAttachmentList extends ConsumerStatefulWidget {
  final Task task;
  final Function(Task)? onTaskUpdated;

  const TaskMediaAttachmentList({
    super.key,
    required this.task,
    this.onTaskUpdated,
  });

  @override
  ConsumerState<TaskMediaAttachmentList> createState() => _TaskMediaAttachmentListState();
}

class _TaskMediaAttachmentListState extends ConsumerState<TaskMediaAttachmentList> {



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
    final mediaAttachmentState = ref.watch(unifiedAttachmentViewModelProvider);
    
    // Parse media attachments from the current task using both unified and legacy approaches
    final allAttachments = ref.read(unifiedAttachmentViewModelProvider.notifier).parseAttachments(currentTask.attachments);
    final unifiedMediaAttachments = allAttachments.where((attachment) => attachment.type == AttachmentType.media).toList();
    
    // Also check legacy mediaAttachments field for backward compatibility
    final legacyMediaAttachments = ref.read(unifiedAttachmentViewModelProvider.notifier).parseAttachments(currentTask.mediaAttachments);
    
    // Combine both sources, avoiding duplicates
    final mediaAttachments = <Attachment>[];
    final seenUris = <String>{};
    
    for (final attachment in [...unifiedMediaAttachments, ...legacyMediaAttachments]) {
      if (!seenUris.contains(attachment.uri)) {
        mediaAttachments.add(attachment);
        seenUris.add(attachment.uri);
      }
    }

    // Don't show anything if no media attachments
    if (mediaAttachments.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        
        // Media attachments header
        Row(
          children: [
            Icon(
              Icons.perm_media,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              mediaAttachments.length == 1 ? AppLocalizations.of(context)!.media : AppLocalizations.of(context)!.mediaFiles,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Text(
              ' (${mediaAttachments.length})',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        
        // Media attachments grid
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: mediaAttachments.length,
          itemBuilder: (context, index) {
            final attachment = mediaAttachments[index];
            return _buildMediaAttachmentItem(attachment, mediaAttachmentState);
          },
        ),
        
        // Error message
        if (mediaAttachmentState.error != null) ...[
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
                    mediaAttachmentState.error!,
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

  Widget _buildMediaAttachmentItem(Attachment mediaAttachment, UnifiedAttachmentState mediaAttachmentState) {
    final fileId = mediaAttachment.uri;
    
    final isDownloadingThis = mediaAttachmentState.isDownloading && 
                             mediaAttachmentState.downloadingFileId == fileId;
    
    return Container(
      width: 118,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media thumbnail
          _buildMediaThumbnail(mediaAttachment, fileId),
          
          // File info and actions section
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File info
                Row(
                  children: [
                    Expanded(
                                              child: Text(
                          mediaAttachment.filename,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ),
                  ],
                ),
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Download button
                    GestureDetector(
                      onTap: isDownloadingThis ? null : () => _downloadMediaFile(mediaAttachment),
                      child: Icon(
                        isDownloadingThis ? Icons.hourglass_empty : Icons.download,
                        size: 12,
                        color: isDownloadingThis 
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    
                    // Delete button (only if we can edit tasks)
                    if (widget.onTaskUpdated != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removeMediaFile(fileId),
                        child: Icon(
                          Icons.delete_outline,
                          size: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(Attachment mediaAttachment, String fileId) {
    final fileName = mediaAttachment.filename;
    final mediaType = mediaAttachment.mediaType?.name ?? 'unknown';
    
    if (mediaType == 'image') {
      // Use reusable ImageThumbnail component
      return ImageThumbnail(
        fileId: fileId,
        fileName: fileName,
        file: {
          'uri': mediaAttachment.uri,
          'filename': mediaAttachment.filename,
          'size': mediaAttachment.size,
          'status': mediaAttachment.status,
          's3Key': mediaAttachment.s3Key,
          'aesKey': mediaAttachment.aesKey,
          'mediaType': mediaAttachment.mediaType?.name,
        },
        taskUid: widget.task.uid,
        onTap: () => _showFullScreenImage(mediaAttachment),
        onLoadImageData: () => ref.read(unifiedAttachmentViewModelProvider.notifier)
            .downloadAttachment(
              fileId: fileId,
              aesKey: mediaAttachment.aesKey,
              s3Key: mediaAttachment.s3Key,
            ),
      );
    }
    
    // For non-image files (videos), show styled icon container
    return GestureDetector(
      onTap: () => _downloadMediaFile(mediaAttachment),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(7),
            topRight: Radius.circular(7),
          ),
        ),
        child: Icon(
          _getMediaIcon(fileName),
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _downloadMediaFile(Attachment mediaAttachment) async {
    final fileId = mediaAttachment.uri;
    final fileName = mediaAttachment.filename;
    final s3Key = mediaAttachment.s3Key;

    AppLogger.debug('TaskMediaAttachmentList: Starting download for media file $fileId ($fileName)');

    Uint8List? downloadResult;
    try {
      // Call unified ViewModel to handle download and get file bytes
      downloadResult = await ref.read(unifiedAttachmentViewModelProvider.notifier)
          .downloadAttachment(
            fileId: fileId,
            aesKey: mediaAttachment.aesKey,
            s3Key: s3Key,
          );

      if (downloadResult == null) {
        AppLogger.error('TaskMediaAttachmentList: Download returned null for media file $fileId');
        return;
      }

      AppLogger.debug('TaskMediaAttachmentList: Download successful, got ${downloadResult.length} bytes');
    } catch (e, stackTrace) {
      AppLogger.error('TaskMediaAttachmentList: Download failed for media file $fileId', e, stackTrace);
      return;
    }

    // Show file picker dialog to choose save location
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Media File',
      fileName: fileName,
      type: FileType.any,
    );

    if (savePath != null) {
      try {
        // Actually write the file to the chosen location
        final saveFile = File(savePath);
        await saveFile.writeAsBytes(downloadResult);
      } catch (e) {
        AppLogger.error('TaskMediaAttachmentList: Failed to save file', e);
      }
    }
  }

  Future<void> _showFullScreenImage(Attachment mediaAttachment) async {
    final fileId = mediaAttachment.uri;
    final fileName = mediaAttachment.filename;
    final s3Key = mediaAttachment.s3Key;

    // Use unified ViewModel to get image data
    final imageData = await ref.read(unifiedAttachmentViewModelProvider.notifier)
        .downloadAttachment(
          fileId: fileId,
          aesKey: mediaAttachment.aesKey,
          s3Key: s3Key,
        );

    if (imageData == null) {
      return;
    }

    if (!mounted) return;

    // Show full screen image viewer using the reusable widget
    showFullScreenImageViewer(
      context: context,
      imageData: imageData,
      fileName: fileName,
      onDownload: () {
        Navigator.of(context).pop();
        _downloadMediaFile(mediaAttachment);
      },
    );
  }

  Future<void> _removeMediaFile(String fileId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Media File'),
        content: const Text('Are you sure you want to remove this media file? This action cannot be undone.'),
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

    // Call unified ViewModel to handle media file removal
    final success = await ref.read(unifiedAttachmentViewModelProvider.notifier)
        .removeTaskAttachment(
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

  IconData _getMediaIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'svg':
      case 'webp':
      case 'tiff':
      case 'tif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
      case 'mkv':
      case '3gp':
      case 'm4v':
        return Icons.video_file;
      default:
        return Icons.perm_media;
    }
  }


} 