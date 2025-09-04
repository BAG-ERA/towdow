// Journal media attachment list widget for displaying media attachments with image preview
// Reuses components from media validator but adapts for journal media attachments
// Follows MVVM architecture - UI logic delegated to UnifiedAttachmentViewModel

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/models/journal.dart';
import '../../../data/models/attachment.dart';
import '../../../data/providers/providers.dart';

import '../utils/image_thumbnail.dart';
import '../utils/full_screen_image_viewer.dart';
import '../../../core/logger.dart';
import '../../../core/result.dart';

class JournalMediaAttachmentList extends ConsumerStatefulWidget {
  final Journal journal;
  final Function(Journal)? onJournalUpdated;

  const JournalMediaAttachmentList({
    super.key,
    required this.journal,
    this.onJournalUpdated,
  });

  @override
  ConsumerState<JournalMediaAttachmentList> createState() => _JournalMediaAttachmentListState();
}

class _JournalMediaAttachmentListState extends ConsumerState<JournalMediaAttachmentList> {
  @override
  Widget build(BuildContext context) {
    // Watch the reactive journal data from the repository
    final journalAsync = ref.watch(journalProvider(widget.journal.uid));
    
    // Get the current journal from the reactive data
    final currentJournal = journalAsync.when(
      data: (journal) => journal ?? widget.journal,
      loading: () => widget.journal,
      error: (error, stack) => widget.journal,
    );

    // Watch the unified attachment view model state
    final mediaAttachmentState = ref.watch(unifiedAttachmentViewModelProvider);
    
    // Parse media attachments from the current journal using both unified and legacy approaches
    final allAttachments = ref.read(unifiedAttachmentViewModelProvider.notifier).parseAttachments(currentJournal.attachments);
    final unifiedMediaAttachments = allAttachments.where((attachment) => attachment.type == AttachmentType.media).toList();
    
    // Also check legacy mediaAttachments field for backward compatibility
    final legacyMediaAttachments = ref.read(unifiedAttachmentViewModelProvider.notifier).parseAttachments(currentJournal.mediaAttachments);
    
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
              mediaAttachments.length == 1 ? 'Media' : 'Media Files',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            if (mediaAttachmentState.isUploading)
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
              onPressed: _uploadMedia,
              icon: const Icon(Icons.add, size: 16),
              tooltip: 'Add media',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Media attachments grid
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
            return _buildMediaItem(attachment);
          },
        ),
      ],
    );
  }

  Widget _buildMediaItem(Attachment attachment) {
    final isImage = _isImageFile(attachment.filename);
    
    return GestureDetector(
      onTap: () => _showFullScreenImage(attachment),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: isImage
              ? ImageThumbnail(
                  fileId: attachment.uri,
                  fileName: attachment.filename,
                  file: _attachmentToMap(attachment),
                  taskUid: widget.journal.uid, // Using journal UID as taskUid for compatibility
                  onTap: () => _showFullScreenImage(attachment),
                  onLoadImageData: () => ref.read(unifiedAttachmentViewModelProvider.notifier)
                      .downloadAttachment(
                        fileId: attachment.uri,
                        aesKey: attachment.aesKey,
                        s3Key: attachment.s3Key,
                      ),
                )
              : _buildNonImageMedia(attachment),
        ),
      ),
    );
  }

  Widget _buildNonImageMedia(Attachment attachment) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getMediaIcon(attachment.filename),
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 4),
          Text(
            attachment.filename.split('.').last.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _uploadMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileData = File(file.path!);
        final bytes = await fileData.readAsBytes();

        AppLogger.info('JournalMediaAttachmentList: Starting media upload: ${file.name}');

        final success = await ref.read(unifiedAttachmentViewModelProvider.notifier).uploadJournalAttachment(
          journalUid: widget.journal.uid,
          fileName: file.name,
          fileData: bytes,
          contentType: _guessContentType(file.name),
          type: AttachmentType.media,
        );

        if (success && widget.onJournalUpdated != null) {
          // Refresh the journal data
          final updatedJournal = await ref.read(journalRepositoryProvider).getById(widget.journal.uid);
          updatedJournal.when(
            success: (journal) {
              if (journal != null) {
                widget.onJournalUpdated!(journal);
              }
            },
            failure: (failure) {
              AppLogger.error('JournalMediaAttachmentList: Failed to refresh journal after upload', failure.exception);
            },
          );
        }
      }
    } catch (e) {
      AppLogger.error('JournalMediaAttachmentList: Media upload failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e')),
        );
      }
    }
  }

  Future<void> _showFullScreenImage(Attachment attachment) async {
    try {
      final imageData = await ref.read(unifiedAttachmentViewModelProvider.notifier)
          .downloadAttachment(
            fileId: attachment.uri,
            aesKey: attachment.aesKey,
            s3Key: attachment.s3Key,
          );

      if (imageData == null) {
        throw Exception('Failed to load image');
      }

      if (mounted) {
        showFullScreenImageViewer(
          context: context,
          imageData: imageData,
          fileName: attachment.filename,
          onDownload: () => _downloadMedia(attachment),
        );
      }
    } catch (e) {
      AppLogger.error('JournalMediaAttachmentList: Failed to show full screen image', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  Future<void> _downloadMedia(Attachment attachment) async {
    try {
      AppLogger.info('JournalMediaAttachmentList: Starting media download: ${attachment.filename}');

      final bytes = await ref.read(unifiedAttachmentViewModelProvider.notifier).downloadAttachment(
        fileId: attachment.uri,
        aesKey: attachment.aesKey,
        s3Key: attachment.s3Key,
      );

      if (bytes == null) {
        throw Exception('Download returned null');
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Media File',
        fileName: attachment.filename,
        type: FileType.any,
      );

      if (savePath != null) {
        final saveFile = File(savePath);
        await saveFile.writeAsBytes(bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Media file saved successfully')),
          );
        }
      }
    } catch (e) {
      AppLogger.error('JournalMediaAttachmentList: Media download failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download media: $e')),
        );
      }
    }
  }

  bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif'].contains(extension);
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
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
      case 'wma':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _guessContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'tiff':
      case 'tif':
        return 'image/tiff';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case '3gp':
        return 'video/3gpp';
      case 'm4v':
        return 'video/x-m4v';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'wma':
        return 'audio/x-ms-wma';
      default:
        return 'application/octet-stream';
    }
  }

  Map<String, dynamic> _attachmentToMap(Attachment attachment) {
    return {
      'uri': attachment.uri,
      'filename': attachment.filename,
      'size': attachment.size,
      'contentType': attachment.contentType,
      'aesKey': attachment.aesKey,
      's3Key': attachment.s3Key,
      'type': attachment.type.toString(),
    };
  }
}
