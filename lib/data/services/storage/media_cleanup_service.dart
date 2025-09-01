// Media cleanup service for automatic retention policy management
// Runs cleanup tasks periodically to remove expired media files
// Implements 30-day retention policy with configurable intervals

import 'dart:async';
import 'offline_file_service.dart';
import '../../../core/logger.dart';

/// Service for managing automatic cleanup of expired media files
class MediaCleanupService {
  final OfflineFileService _offlineFileService;
  Timer? _cleanupTimer;
  static const Duration _cleanupInterval = Duration(hours: 24); // Run cleanup daily
  static const Duration _retentionPeriod = Duration(days: 30); // 30-day retention

  MediaCleanupService(this._offlineFileService);

  /// Start the automatic cleanup service
  void startCleanupService() {
    if (_cleanupTimer != null) {
      AppLogger.debug('MediaCleanupService: Cleanup service already running');
      return;
    }

    AppLogger.info('MediaCleanupService: Starting automatic cleanup service');
    
    // Run initial cleanup
    _runCleanup();
    
    // Schedule periodic cleanup
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _runCleanup();
    });
  }

  /// Stop the automatic cleanup service
  void stopCleanupService() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    AppLogger.info('MediaCleanupService: Stopped automatic cleanup service');
  }

  /// Run cleanup of expired files
  Future<void> _runCleanup() async {
    try {
      AppLogger.debug('MediaCleanupService: Running cleanup of expired files');
      
      final result = await _offlineFileService.cleanupExpiredFiles();
      await result.when(
        success: (_) {
          AppLogger.info('MediaCleanupService: Cleanup completed successfully');
        },
        failure: (failure) {
          AppLogger.warning('MediaCleanupService: Cleanup failed: ${failure.message}');
        },
      );
    } catch (e) {
      AppLogger.error('MediaCleanupService: Error during cleanup', e);
    }
  }

  /// Manually trigger cleanup (for testing or immediate cleanup)
  Future<void> triggerCleanup() async {
    AppLogger.info('MediaCleanupService: Manual cleanup triggered');
    await _runCleanup();
  }

  /// Get cleanup statistics
  Future<Map<String, dynamic>> getCleanupStats() async {
    try {
      final statsResult = await _offlineFileService.getStorageStats();
      return await statsResult.when(
        success: (stats) {
          return {
            'totalFiles': stats['totalFiles'] ?? 0,
            'totalSize': stats['totalSize'] ?? 0,
            'localFiles': stats['localFiles'] ?? 0,
            'uploadedFiles': stats['uploadedFiles'] ?? 0,
            'failedFiles': stats['failedFiles'] ?? 0,
            'retentionPeriod': _retentionPeriod.inDays,
            'cleanupInterval': _cleanupInterval.inHours,
            'serviceRunning': _cleanupTimer != null,
          };
        },
        failure: (failure) {
          AppLogger.warning('MediaCleanupService: Failed to get stats: ${failure.message}');
          return {
            'error': failure.message,
            'retentionPeriod': _retentionPeriod.inDays,
            'cleanupInterval': _cleanupInterval.inHours,
            'serviceRunning': _cleanupTimer != null,
          };
        },
      );
    } catch (e) {
      AppLogger.error('MediaCleanupService: Error getting cleanup stats', e);
      return {
        'error': e.toString(),
        'retentionPeriod': _retentionPeriod.inDays,
        'cleanupInterval': _cleanupInterval.inHours,
        'serviceRunning': _cleanupTimer != null,
      };
    }
  }

  /// Dispose resources
  void dispose() {
    stopCleanupService();
  }
}
