// Reusable image thumbnail widget for displaying media file previews
// Handles loading image data and displaying thumbnails with loading/error states
// Can be used by validators, attachments, or any other widget that needs image previews

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/logger.dart';

/// Reusable image thumbnail widget
class ImageThumbnail extends ConsumerStatefulWidget {
  final String fileId;
  final String fileName;
  final Map<String, dynamic> file;
  final String taskUid;
  final VoidCallback onTap;
  final bool isLarge;
  final Future<Uint8List?> Function() onLoadImageData;

  const ImageThumbnail({
    super.key,
    required this.fileId,
    required this.fileName,
    required this.file,
    required this.taskUid,
    required this.onTap,
    required this.onLoadImageData,
    this.isLarge = false,
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
    _loadImageData();
  }

  Future<void> _loadImageData() async {
    try {
      final imageData = await widget.onLoadImageData();

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
        width: widget.isLarge ? double.infinity : 48,
        height: widget.isLarge ? 120 : 48,
        decoration: BoxDecoration(
          borderRadius: widget.isLarge 
              ? const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                )
              : BorderRadius.circular(6),
          border: widget.isLarge 
              ? null 
              : Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
        ),
        child: ClipRRect(
          borderRadius: widget.isLarge 
              ? const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                )
              : BorderRadius.circular(5),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
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
        child: Icon(
          Icons.image,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return Image.memory(
      _imageData!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image,
            size: 24,
            color: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );
  }
} 