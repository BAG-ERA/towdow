# Offline Queue Sync Fix

## Problem Description

The app has a specific queue to store operations before sending them to the server, but the queue was never propagated to the server when connection was lost and then restored. This was due to architectural issues in the sync system.

## Root Cause Analysis

### Issue 1: Separate Sync Services
The app has two separate sync services running independently:

1. **SyncService** - Handles the sync queue and bidirectional sync
2. **BackgroundSyncService** - Only handles one-way sync from server to local (download only)

The `BackgroundSyncService` was designed for **one-way sync** (server → local) and never processed the sync queue. The queue processing was only done by the main `SyncService`, but there was no mechanism to trigger it when connection was restored.

### Issue 2: Sync Status Conflicts
The main `SyncService` has a sync status check that prevents concurrent sync operations. When the `BackgroundSyncService` tried to call `syncNow()` on the main `SyncService`, it would often be rejected with "Sync already in progress" because the main sync service was already running.

### Issue 3: No Connection Restoration Detection
There was no network connectivity monitoring or connection restoration detection that would trigger queue processing.

### Issue 4: App Lifecycle Manager Limitations
When the app resumed, `AppLifecycleManager._onAppResumed()` called `_syncService!.syncNow()`, but this only happened if the sync service was available and the account was configured.

## Solution Implementation

### 1. Enhanced BackgroundSyncService
- Added reference to main `SyncService` for queue processing
- Added `_triggerQueueProcessing()` method that calls the main sync service after successful background sync
- Modified `_performBackgroundSync()` to trigger queue processing after syncing from server

### 2. New Queue-Only Processing Method
- Created `processQueueOnly()` method in `SyncService` that bypasses sync status checks
- This method only processes queued operations without doing full bidirectional sync
- Prevents sync status conflicts between background sync and main sync

### 3. Network Connectivity Service
- Created `NetworkConnectivityService` to monitor internet connection status
- Detects when connection is restored after being offline
- Automatically triggers queue processing when connection is restored
- Uses periodic connectivity checks (every 30 seconds)

### 4. Updated App Lifecycle Manager
- Added `NetworkConnectivityService` to the service initialization
- Properly connects the sync services during initialization
- Ensures queue processing is triggered when connection is restored

### 5. Updated Providers
- Modified `BackgroundSyncService` provider to accept `SyncService` reference
- Added `NetworkConnectivityService` provider
- Updated app lifecycle initialization to include network connectivity service

## Key Changes

### BackgroundSyncService Changes
```dart
class BackgroundSyncService {
  SyncService? _syncService; // Reference to main sync service for queue processing

  BackgroundSyncService({
    // ... existing parameters
    SyncService? syncService, // Optional reference to main sync service
  });

  void setSyncService(SyncService syncService) {
    _syncService = syncService;
  }

  Future<void> _triggerQueueProcessing() async {
    if (_syncService != null) {
      // Use processQueueOnly instead of syncNow to avoid sync status conflicts
      final result = await _syncService!.processQueueOnly();
      await result.when(
        success: (syncResult) async {
          AppLogger.debug('BackgroundSyncService: Queue processing completed successfully - ${syncResult.syncedItems} items processed');
        },
        failure: (failure) async {
          AppLogger.error('BackgroundSyncService: Queue processing failed: ${failure.message}');
        },
      );
    }
  }
}
```

### New SyncService Method
```dart
class SyncService {
  /// Process sync queue only (for background sync service)
  /// This method bypasses the sync status check and only processes queued operations
  Future<Result<SyncResult>> processQueueOnly() async {
    // Bypasses sync status check and only processes queued operations
    return await _performQueueProcessing(account);
  }

  /// Perform queue processing only (without sync status check)
  Future<Result<SyncResult>> _performQueueProcessing(CaldavAccount account) async {
    // Only processes queued operations, no bidirectional sync
    for (final calendar in selectedCalendars) {
      final hasQueuedOperations = await _hasQueuedOperationsForCalendar(calendar.uid);
      if (hasQueuedOperations) {
        await _processSyncQueueForCalendar(caldavService, calendar.uid, errors);
      }
    }
  }
}
```

### NetworkConnectivityService
```dart
class NetworkConnectivityService {
  Future<void> _triggerSyncOnConnectionRestored() async {
    if (_syncService != null) {
      // Use processQueueOnly for more reliable queue processing
      final result = await _syncService!.processQueueOnly();
      await result.when(
        success: (syncResult) async {
          AppLogger.info('NetworkConnectivityService: Queue processing completed after connection restoration - ${syncResult.syncedItems} items processed');
        },
        failure: (failure) async {
          AppLogger.error('NetworkConnectivityService: Queue processing failed after connection restoration: ${failure.message}');
        },
      );
    }
  }
}
```

### App Lifecycle Manager
```dart
// Set the main sync service reference for queue processing
if (_syncService != null) {
  _backgroundSyncService!.setSyncService(_syncService!);
}

// Set the main sync service reference for connection restoration
if (_syncService != null) {
  _networkConnectivityService!.setSyncService(_syncService!);
}
```

## Testing

Created comprehensive tests in `test/services/offline_queue_sync_test.dart` to verify:
1. Queued operations are processed after background sync
2. Queue processing is triggered when connection is restored
3. Queue processing works without sync status conflicts
4. Network connectivity monitoring works correctly

## Benefits

1. **Automatic Queue Processing**: Queue operations are now automatically processed when connection is restored
2. **No Sync Status Conflicts**: The new `processQueueOnly()` method bypasses sync status checks
3. **Network Awareness**: The app now monitors network connectivity and responds to connection changes
4. **Robust Offline Support**: Offline operations are properly synchronized when connection returns
5. **Better User Experience**: Users don't need to manually trigger sync after connection restoration
6. **Reliable Background Processing**: Background sync can process queues without interfering with main sync

## Configuration

The fix is automatically enabled when the app starts. No additional configuration is required. The network connectivity service runs in the background and monitors connection status every 30 seconds.

## Monitoring

The fix includes comprehensive logging to help debug any issues:
- Network connectivity status changes
- Queue processing triggers
- Sync service calls
- Connection restoration events
- Queue processing results

## Future Improvements

1. **Exponential Backoff**: Implement exponential backoff for failed sync attempts
2. **Queue Prioritization**: Prioritize critical operations in the sync queue
3. **Conflict Resolution**: Enhanced conflict resolution for simultaneous offline/online changes
4. **Battery Optimization**: Optimize network checks for battery life
5. **Queue Persistence**: Ensure queue items persist across app restarts 