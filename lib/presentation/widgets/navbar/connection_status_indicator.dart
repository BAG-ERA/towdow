// Connection status indicator widget
// Shows offline status and file upload progress in the navbar

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/providers.dart';
import '../../../data/services/sync/connection_monitor_service.dart';
import '../../../data/services/storage/file_upload_queue_service.dart';
import '../../../core/result.dart';

class ConnectionStatusIndicator extends ConsumerWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch connection status
    final connectionMonitorService = ref.watch(connectionMonitorServiceProvider);
    final fileUploadQueueService = ref.watch(fileUploadQueueServiceProvider);
    
    return StreamBuilder<ConnectionStatus>(
      stream: connectionMonitorService.statusStream,
      initialData: connectionMonitorService.currentStatus,
      builder: (context, connectionSnapshot) {
        final connectionStatus = connectionSnapshot.data ?? ConnectionStatus.unknown;
        
        return StreamBuilder<FileUploadStatus>(
          stream: fileUploadQueueService.statusStream,
          builder: (context, uploadSnapshot) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: fileUploadQueueService.getQueueStatus().then((result) => result.when(
                success: (data) => data,
                failure: (_) => null,
              )),
              builder: (context, queueSnapshot) {
                final queueStatus = queueSnapshot.data;
                final hasQueuedFiles = queueStatus != null && queueStatus['totalItems'] > 0;
                
                // Show upload progress if files are being uploaded
                if (hasQueuedFiles && connectionStatus == ConnectionStatus.connected) {
                  return _buildUploadingIndicator(context, queueStatus!);
                }
                
                // Show offline indicator if disconnected
                if (connectionStatus == ConnectionStatus.disconnected) {
                  return _buildOfflineIndicator(context, hasQueuedFiles);
                }
                
                // Show connection unknown indicator
                if (connectionStatus == ConnectionStatus.unknown) {
                  return _buildUnknownIndicator(context);
                }
                
                // Connected with no uploads - show nothing or small connected indicator
                return const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUploadingIndicator(BuildContext context, Map<String, dynamic> queueStatus) {
    final totalItems = queueStatus['totalItems'] as int;
    final processingItems = queueStatus['processingItems'] as int;
    final failedItems = queueStatus['failedItems'] as int;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Uploading $processingItems/$totalItems',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (failedItems > 0) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.error_outline,
              size: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator(BuildContext context, bool hasQueuedFiles) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 12,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 6),
          Text(
            hasQueuedFiles ? 'Offline (files queued)' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.help_outline,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'Checking...',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 