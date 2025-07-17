// Media validator component for task items
// Displays media attachments with upload/download capabilities
// Follows MVVM architecture - all business logic is in MediaValidatorViewModel

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../viewmodels/media_validator_viewmodel.dart';
import '../../../../core/logger.dart';
import '../../../../data/services/validator_service.dart';
import '../../../../data/providers/providers.dart';
import '../../../../data/models/offline_file.dart';

class ValidatorMedia extends ConsumerStatefulWidget {
  final Map<String, dynamic> validator;
  final String taskUid;
  final bool isOrganizer;
  final Function(String validatorId, Map<String, dynamic> updateData) onValidatorUpdated;

  const ValidatorMedia({
    super.key,
    required this.validator,
    required this.taskUid,
    required this.isOrganizer,
    required this.onValidatorUpdated,
  });

  @override
  ConsumerState<ValidatorMedia> createState() => _ValidatorMediaState();
}

class _ValidatorMediaState extends ConsumerState<ValidatorMedia> {
  bool _hasShownMessage = false;

  @override
  Widget build(BuildContext context) {
    final mediaValidatorState = ref.watch(mediaValidatorViewModelProvider(widget.taskUid));
    final files = widget.validator['files'] as List<dynamic>? ?? [];
    final validatorId = widget.validator['id'] as String;
    final helper = widget.validator['helper'] as String?;
    
    // Show error/success messages (prevent loop with flag)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownMessage) {
        if (mediaValidatorState.error != null) {
          _showErrorSnackbar(mediaValidatorState.error!);
          ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier).clearMessages();
          _hasShownMessage = true;
        } else if (mediaValidatorState.successMessage != null) {
          _showSuccessSnackbar(mediaValidatorState.successMessage!);
          ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier).clearMessages();
          _hasShownMessage = true;
        }
      }
    });
    
    // Reset flag when messages are cleared
    if (mediaValidatorState.error == null && mediaValidatorState.successMessage == null) {
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
        
        // Media file list
        if (files.isNotEmpty) ...[
          ...files.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value as Map<String, dynamic>;
            return Padding(
              padding: EdgeInsets.only(bottom: index < files.length - 1 ? 8 : 0),
              child: _buildMediaFileItem(file, validatorId, mediaValidatorState),
            );
          }),
          const SizedBox(height: 8),
        ],
        
        // Upload button - only show when no files
        if (files.isEmpty) ...[
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: mediaValidatorState.isUploading ? null : () => _showMediaUploadOptions(validatorId),
                icon: mediaValidatorState.isUploading 
                    ? const SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate, size: 16),
                label: Text(mediaValidatorState.isUploading ? 'Uploading...' : 'Add Media'),
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

  Widget _buildMediaFileItem(Map<String, dynamic> file, String validatorId, MediaValidatorState mediaValidatorState) {
    final fileName = file['name'] as String? ?? 'Unknown file';
    final fileSize = file['size'] as int? ?? 0;
    final uploadedAt = file['uploadedAt'] as String?;
    final fileId = file['id'] as String;
    final fileStatus = file['status'] as String? ?? 'uploaded'; // 'local', 'uploading', 'uploaded', 'failed'
    
    final isDownloadingThis = mediaValidatorState.isDownloading && 
                             mediaValidatorState.downloadingFileId == fileId;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large media thumbnail spanning full width
          _buildMediaThumbnail(file, fileId, validatorId),
          
          // File info and actions section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show file info instead of filename for better UX
                      Row(
                        children: [
                          Text(
                            _formatFileSize(fileSize),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            _getFileTypeText(fileName),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Show file status
                          Text(
                            _getStatusText(fileStatus),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(fileStatus, context),
                              fontWeight: fileStatus == 'local' ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                          if (uploadedAt != null && fileStatus == 'uploaded') ...[
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
                  onPressed: isDownloadingThis ? null : () => _downloadMediaFile(file, validatorId),
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
                    onPressed: () => _removeMediaFile(validatorId, fileId),
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
          ),
        ],
      ),
    );
  }

  /// Show media upload options (camera or file picker)
  Future<void> _showMediaUploadOptions(String validatorId) async {
    // Check if camera should be available (not on Windows or Linux)
    final isMobilePlatform = !Platform.isWindows && !Platform.isLinux;
    
    // If only one option is available, bypass the modal and go directly to file picker
    if (!isMobilePlatform) {
      _uploadMediaFile(validatorId);
      return;
    }
    
    // Show modal with both options on mobile platforms
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePicture(validatorId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _uploadMediaFile(validatorId);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Take a picture with the camera
  Future<void> _takePicture(String validatorId) async {
    try {
      // Check if camera is available on this platform
      if (Platform.isWindows || Platform.isLinux) {
        _showErrorSnackbar('Camera is not available on desktop platforms');
        return;
      }

      // Check camera permission
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _showErrorSnackbar('Camera permission is required to take photos');
        return;
      }

      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorSnackbar('No camera available on this device');
        return;
      }

      if (!mounted) return;

      // Navigate to camera screen
      final result = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(
          builder: (context) => _CameraScreen(camera: cameras.first),
        ),
      );

      if (result != null) {
        // Read the captured image
        final imageBytes = await result.readAsBytes();
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Upload the captured image
        await _uploadMediaFileWithData(
          validatorId: validatorId,
          fileName: fileName,
          fileData: imageBytes,
          contentType: 'image/jpeg',
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to take picture: $e');
    }
  }

  /// Upload media file with provided data (used for camera captures)
  Future<void> _uploadMediaFileWithData({
    required String validatorId,
    required String fileName,
    required Uint8List fileData,
    required String contentType,
  }) async {
    // Call ViewModel to handle upload
    final success = await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
        .uploadMediaFile(
          taskUid: widget.taskUid,
          validatorId: validatorId,
          fileName: fileName,
          fileData: fileData,
          contentType: contentType,
        );

    // If upload succeeded, notify parent to refresh validator data
    if (success) {
      // Notify parent that task was updated so it can refresh the validator data
      widget.onValidatorUpdated(validatorId, {'type': 'refresh'});
    }
  }

  Future<void> _uploadMediaFile(String validatorId) async {
    try {
      // Pick media file (restrict to picture types only for now)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Image formats
          'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif',
          // Video formats - commented out for now
          // 'mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv', '3gp', 'm4v',
        ],
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
          _showErrorSnackbar('Could not read media file: $e');
          return;
        }
      }

      if (fileBytes == null) {
        _showErrorSnackbar('Could not read media file data');
        return;
      }

      // Call ViewModel to handle upload
      final success = await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
          .uploadMediaFile(
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

  Future<void> _downloadMediaFile(Map<String, dynamic> file, String validatorId) async {
    final fileId = file['id'] as String;
    final fileName = file['name'] as String? ?? 'download';
    final s3Key = file['s3Key'] as String?; // May be null for offline files

    // Call ViewModel to handle download and get file bytes (offline-first)
    final downloadResult = await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
        .downloadMediaFileBytes(
          fileId: fileId,
          fileName: fileName,
          validatorId: validatorId,
          s3Key: s3Key, // Optional for offline files
        );

    if (downloadResult == null) {
      _showErrorSnackbar('Download failed');
      return;
    }

    // Show file picker dialog to choose save location with bytes for Android/iOS
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Media File',
      fileName: fileName,
      type: FileType.any,
      bytes: downloadResult, // Provide bytes for Android/iOS compatibility
    );

    if (savePath != null) {
      _showSuccessSnackbar('Media file saved successfully');
    }
  }

  Future<void> _removeMediaFile(String validatorId, String fileId) async {
    // Call ViewModel to handle file removal
    final success = await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
        .removeMediaFile(
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

  Future<void> _downloadAllMediaFiles(List<dynamic> files, String validatorId) async {
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
        await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
            .downloadMediaFile(
              fileId: fileId,
              fileName: fileName,
              validatorId: validatorId,
              s3Key: s3Key,
              savePath: savePath,
            );
      }
    }
  }

  Future<void> _removeAllMediaFiles(String validatorId, List<dynamic> files) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Media Files'),
        content: Text('Are you sure you want to delete all ${files.length} media file(s)? This action cannot be undone.'),
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
      await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
          .removeMediaFile(
            taskUid: widget.taskUid,
            validatorId: validatorId,
            fileId: fileId,
          );
    }
    
    // Notify parent that task was updated so it can refresh the validator data
    widget.onValidatorUpdated(validatorId, {'type': 'refresh'});
  }

  IconData _getMediaIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      // Image formats
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
      // Video formats - commented out for now
      // case 'mp4':
      // case 'avi':
      // case 'mov':
      // case 'wmv':
      // case 'flv':
      // case 'webm':
      // case 'mkv':
      // case '3gp':
      // case 'm4v':
      //   return Icons.video_file;
      default:
        // For unknown extensions in media context, use generic media icon
        return Icons.perm_media;
    }
  }

  String _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    // Log the file extension for debugging
    AppLogger.debug('ValidatorMedia._getContentType: File: $fileName, Extension: $extension');
    
    switch (extension) {
      // Image formats
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
      // Video formats - commented out for now
      // case 'mp4':
      //   return 'video/mp4';
      // case 'avi':
      //   return 'video/x-msvideo';
      // case 'mov':
      //   return 'video/quicktime';
      // case 'wmv':
      //   return 'video/x-ms-wmv';
      // case 'flv':
      //   return 'video/x-flv';
      // case 'webm':
      //   return 'video/webm';
      // case 'mkv':
      //   return 'video/x-matroska';
      // case '3gp':
      //   return 'video/3gpp';
      // case 'm4v':
      //   return 'video/mp4';
      default:
        AppLogger.debug('ValidatorMedia._getContentType: Unknown extension: $extension, using application/octet-stream');
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

  /// Build media thumbnail widget with actual image display
  Widget _buildMediaThumbnail(Map<String, dynamic> file, String fileId, String validatorId) {
    final fileName = file['name'] as String? ?? 'Unknown file';
    final extension = fileName.split('.').last.toLowerCase();
    
    if (_isImageType(extension)) {
      // Display actual image thumbnail using a separate method that doesn't interfere with global state
      return _ImageThumbnail(
        fileId: fileId,
        fileName: fileName,
        file: file,
        validatorId: validatorId,
        taskUid: widget.taskUid,
        onTap: () => _showFullScreenImage(file, validatorId),
        isLarge: true,
      );
    }
    
    // For non-image files, show styled icon container spanning full width
    return GestureDetector(
      onTap: () => _downloadMediaFile(file, validatorId),
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(7),
            topRight: Radius.circular(7),
          ),
        ),
        child: Icon(
          _getMediaIcon(fileName),
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// Show full screen image viewer dialog
  Future<void> _showFullScreenImage(Map<String, dynamic> file, String validatorId) async {
    final fileId = file['id'] as String;
    final fileName = file['name'] as String? ?? 'Unknown file';
    final s3Key = file['s3Key'] as String?;

    // First try to get image from local cache
    final offlineFileService = ref.read(offlineFileServiceProvider);
    final localResult = await offlineFileService.readLocalFile(fileId);
    
    Uint8List? imageData;
    await localResult.when(
      success: (data) async {
        imageData = data;
      },
      failure: (_) async {
        // If not in local cache, download from S3
        imageData = await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
            .downloadMediaFileBytes(
              fileId: fileId,
              fileName: fileName,
              validatorId: validatorId,
              s3Key: s3Key,
            );
      },
    );

    if (imageData == null) {
      _showErrorSnackbar('Failed to load image');
      return;
    }

    if (!mounted) return;

    // Show full screen image dialog
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _FullScreenImageDialog(
        imageData: imageData!,
        fileName: fileName,
        onDownload: () {
          Navigator.of(context).pop();
          _downloadMediaFile(file, validatorId);
        },
      ),
    );
  }

  /// Check if file extension is an image type
  bool _isImageType(String extension) {
    const imageExtensions = {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'tif'
    };
    return imageExtensions.contains(extension);
  }



  /// Get human-readable file type text
  String _getFileTypeText(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'JPEG Image';
      case 'png':
        return 'PNG Image';
      case 'gif':
        return 'GIF Image';
      case 'bmp':
        return 'BMP Image';
      case 'webp':
        return 'WebP Image';
      case 'svg':
        return 'SVG Image';
      case 'tiff':
      case 'tif':
        return 'TIFF Image';
      default:
        return extension.toUpperCase();
    }
  }
}

/// Full screen image viewer dialog
class _FullScreenImageDialog extends StatelessWidget {
  final Uint8List imageData;
  final String fileName;
  final VoidCallback onDownload;

  const _FullScreenImageDialog({
    required this.imageData,
    required this.fileName,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black87,
      child: Stack(
        children: [
          // Main image area - center the image and allow zoom
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from bubbling up to parent GestureDetector
                  child: Image.memory(
                    imageData,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Top bar with close and actions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // File name
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Download button
                  IconButton(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, color: Colors.white),
                    tooltip: 'Download',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom instruction text
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                'Pinch to zoom • Tap to close',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera screen for taking photos
class _CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const _CameraScreen({required this.camera});

  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Take Photo',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_controller),
                ),
                
                // Capture button
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _takePicture,
                      backgroundColor: Colors.white,
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      
      if (mounted) {
        Navigator.of(context).pop(image);
      }
    } catch (e) {
      AppLogger.error('CameraScreen: Failed to take picture', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Separate widget for image thumbnails to avoid state conflicts
class _ImageThumbnail extends ConsumerStatefulWidget {
  final String fileId;
  final String fileName;
  final Map<String, dynamic> file;
  final String validatorId;
  final String taskUid;
  final VoidCallback onTap;
  final bool isLarge;

  const _ImageThumbnail({
    required this.fileId,
    required this.fileName,
    required this.file,
    required this.validatorId,
    required this.taskUid,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  ConsumerState<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends ConsumerState<_ImageThumbnail> {
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
      // Try to get the image data from local storage first
      final offlineFileService = ref.read(offlineFileServiceProvider);
      final result = await offlineFileService.readLocalFile(widget.fileId);
      
      await result.when(
        success: (data) async {
          if (mounted && data != null && data.isNotEmpty) {
            setState(() {
              _imageData = data;
              _isLoading = false;
              _hasError = false;
            });
          } else {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
        },
        failure: (failure) async {
          AppLogger.debug('_ImageThumbnail: Failed to load local file ${widget.fileId}: ${failure.message}');
          // Try to download and cache the image from S3
          await _downloadAndCacheImage();
        },
      );
    } catch (e) {
      AppLogger.debug('_ImageThumbnail: Error loading image data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Download image from S3 and cache it locally for future use
  Future<void> _downloadAndCacheImage() async {
    try {
      final s3Key = widget.file['s3Key'] as String?;
      if (s3Key == null) {
        AppLogger.debug('_ImageThumbnail: No S3 key available for ${widget.fileId}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        return;
      }

      // Download image bytes without triggering additional local file creation
      final downloadResult = await ref.read(mediaValidatorViewModelProvider(widget.taskUid).notifier)
          .downloadMediaFileBytes(
            fileId: widget.fileId,
            fileName: widget.fileName,
            validatorId: widget.validatorId,
            s3Key: s3Key,
          );

      if (downloadResult != null && mounted) {
        // Now manually cache this with the correct fileId to avoid duplicates
        final offlineFileService = ref.read(offlineFileServiceProvider);
        final localStorage = ref.read(localStorageServiceProvider);
        final fileName = widget.file['name'] as String? ?? widget.fileName;
        final contentType = widget.file['contentType'] as String? ?? 'image/jpeg';
        
        // Create offline file metadata with the original fileId
        final appDocDir = await getApplicationDocumentsDirectory();
        final offlineFilesDir = Directory('${appDocDir.path}/offline_files');
        if (!await offlineFilesDir.exists()) {
          await offlineFilesDir.create(recursive: true);
        }
        
        final sanitizedFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final localPath = '${offlineFilesDir.path}/${widget.fileId}_$sanitizedFileName';
        
        // Write file to local storage
        final localFile = File(localPath);
        await localFile.writeAsBytes(downloadResult);
        
        // Get encryption key from validator
        final taskRepository = ref.read(taskRepositoryProvider);
        final taskResult = await taskRepository.getById(widget.taskUid);
        final task = await taskResult.when(
          success: (task) async => task,
          failure: (failure) async => throw Exception('Failed to get task: ${failure.message}'),
        );
        
        if (task == null) {
          throw Exception('Task not found: ${widget.taskUid}');
        }
        
        // Extract encryption key from validator
        final validators = ValidatorService.parseValidators(task.flowitValidator);
        String? encryptionKey;
        
        for (final validatorList in validators) {
          for (final validator in validatorList) {
            if (validator['id'] == widget.validatorId && validator['type'] == 'media') {
              encryptionKey = validator['encryptionKey'] as String?;
              break;
            }
          }
          if (encryptionKey != null) break;
        }
        
        if (encryptionKey == null) {
          throw Exception('Encryption key not found for validator ${widget.validatorId}');
        }
        
        // Create offline file metadata
        final offlineFile = OfflineFile(
          id: widget.fileId,
          taskUid: widget.taskUid,
          aesKey: encryptionKey,
          fileName: fileName,
          localPath: localPath,
          fileSize: downloadResult.length,
          contentType: contentType,
          createdAt: DateTime.now(),
          status: OfflineFileStatus.uploaded, // Mark as uploaded since it came from S3
          s3Key: s3Key,
          validatorId: widget.validatorId, // Optional field for validator association
        );
        
        // Store metadata in Hive with the original fileId
        await localStorage.put(
          'offline_files',
          widget.fileId,
          offlineFile,
        );

        setState(() {
          _imageData = downloadResult;
          _isLoading = false;
          _hasError = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      AppLogger.debug('_ImageThumbnail: Failed to download and cache image: $e');
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