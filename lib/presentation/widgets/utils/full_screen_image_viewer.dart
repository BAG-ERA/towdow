// Full screen image viewer widget for displaying images in a modal dialog
// Reusable component that can be used by any widget that needs to show images full screen
// Follows MVVM architecture - handles only UI concerns

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:towdow_app/l10n/app_localizations.dart';

/// Full screen image viewer dialog
class FullScreenImageViewer extends StatelessWidget {
  final Uint8List imageData;
  final String fileName;
  final VoidCallback? onDownload;
  final VoidCallback? onClose;

  const FullScreenImageViewer({
    super.key,
    required this.imageData,
    required this.fileName,
    this.onDownload,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black87,
      child: Stack(
        children: [
          // Main image area - center the image and allow zoom
          GestureDetector(
            onTap: onClose ?? () => Navigator.of(context).pop(),
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
                              AppLocalizations.of(context)!.failedToLoad,
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
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
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
                  
                  // Download button (only show if callback provided)
                  if (onDownload != null) ...[
                    IconButton(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download, color: Colors.white),
                      tooltip: AppLocalizations.of(context)!.download,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black26,
                      ),
                    ),
                  ],
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

/// Helper function to show full screen image viewer
Future<void> showFullScreenImageViewer({
  required BuildContext context,
  required Uint8List imageData,
  required String fileName,
  VoidCallback? onDownload,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => FullScreenImageViewer(
      imageData: imageData,
      fileName: fileName,
      onDownload: onDownload,
    ),
  );
} 