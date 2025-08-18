// Reusable image thumbnail widget for displaying media file previews
// Handles loading image data and displaying thumbnails with loading/error states
// Can be used by validators, attachments, or any other widget that needs image previews

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';
import '../../viewmodels/media_validator_viewmodel.dart';
import '../../viewmodels/attachment_viewmodel.dart';
import '../../../data/providers/providers_viewmodels.dart';

/// Reusable image thumbnail widget
class ImageThumbnail extends ConsumerStatefulWidget {
  final String fileId;
  final String fileName;
  final Map<String, dynamic> file;
  final String taskUid;
  final VoidCallback onTap;
  final Future<Uint8List?> Function() onLoadImageData;

  const ImageThumbnail({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.file,
    required this.taskUid,
    required this.onTap,
    required this.onLoadImageData,
  });

  @override
  ConsumerState<ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends ConsumerState<ImageThumbnail> {
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadImageData();
      }
    });
  }

  Future<void> _loadImageData() async {
    try {
      // Try to load thumbnail first for faster display
      Uint8List? imageData;
      
      // Check if we have a media validator viewmodel available (for thumbnails)
      if (widget.taskUid.isNotEmpty) {
        try {
          // Try to get thumbnail data first
          final thumbnailData = await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
              .getThumbnailData(
                fileId: widget.fileId,
                fileName: widget.fileName,
              );
          
          if (thumbnailData != null) {
            imageData = thumbnailData;
            AppLogger.debug('ImageThumbnail: Using thumbnail for ${widget.fileName}');
          }
        } catch (e) {
          AppLogger.debug('ImageThumbnail: Failed to get thumbnail, falling back to full image: $e');
        }
      }
      
      // If no thumbnail available, load full image
      if (imageData == null) {
        imageData = await widget.onLoadImageData();
      }

      if (mounted) {
        if (imageData != null) {
          setState(() {
            _imageData = imageData;
            _isLoading = false;
            _hasError = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    } catch (e) {
      AppLogger.debug('ImageThumbnail: Error loading image data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        key: ValueKey('image_thumbnail_${widget.fileId}'),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Watch the unified attachment viewmodel state for download status
    final attachmentState = ref.watch(unifiedAttachmentViewModelProvider);
    final isDownloading = attachmentState.isDownloading && attachmentState.downloadingFileId == widget.fileId;
    
    if (_isLoading || isDownloading) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError || _imageData == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return Image.memory(
      _imageData!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(
              Icons.broken_image,
              size: 24,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        );
      },
    );
  }
} 