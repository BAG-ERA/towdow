# Project Deletion Sync Fix

## Problem

When deleting a project, the following race condition occurred:

1. **Project deleted locally** - Calendar removed from local storage immediately
2. **Delete operation queued** - Delete operation added to sync queue for server deletion
3. **Sync service runs** - Sync service gets calendars from repository (excluding deleted one)
4. **Server sync re-creates calendar** - If calendar still exists on server, sync service re-creates it locally

This resulted in the project being deleted on the server but still existing locally.

## Root Cause

The sync service in `sync_service.dart` was not aware of pending deletions. When syncing from the server, if a calendar still existed on the server, the sync service would re-create it locally, even if it was in the process of being deleted.

## Solution

Implemented a **pending deletion tracking mechanism** using the existing sync queue:

### 1. Track Pending Deletions

Added `_hasPendingDeletionForCalendar()` method to check if a calendar has pending deletion operations in the sync queue.

### 2. Skip Pending Deletions During Sync

Modified the main sync loop to skip calendars with pending deletions:

```dart
for (final calendar in calendarsToSync) {
  // Check if calendar has pending deletion
  final hasPendingDeletion = await _hasPendingDeletionForCalendar(calendar.path);
  if (hasPendingDeletion) {
    AppLogger.info('🔄 SyncService: Skipping calendar ${calendar.path} - pending deletion');
    continue; // Skip this calendar
  }
  
  // Process calendar normally...
}
```

### 3. Process Orphaned Queue Items

Added `_processOrphanedQueueItems()` method to handle queue items for calendars that no longer exist locally:

```dart
// Process queue items for calendars that no longer exist locally
await _processOrphanedQueueItems(caldavService, errors);
```

## Implementation Details

### Files Modified

- `lib/data/services/sync_service.dart`

### Methods Added

1. `_hasPendingDeletionForCalendar(String calendarPath)` - Checks for pending deletion operations
2. `_processOrphanedQueueItems(CalDAVService caldavService, List<String> errors)` - Processes queue items for deleted calendars

### Methods Modified

1. `_performSync()` - Added pending deletion check and orphaned queue processing

## Benefits

### ✅ **Minimal Changes**
- Only 3 small modifications to sync service
- No changes to ViewModels or UI layer
- Leverages existing queue mechanism

### ✅ **MVVM Architecture Compliance**
- Keeps business logic in service layer
- No changes to ViewModels (separation of concerns)
- Repository pattern remains unchanged

### ✅ **Best Practices**
- **Separation of concerns**: Sync logic stays in sync service
- **Single responsibility**: Each method has one clear purpose
- **Error handling**: Proper error handling and logging
- **Offline-first**: Works with existing offline queue system

### ✅ **Robust Solution**
- Handles race conditions properly
- Prevents re-syncing deleted calendars
- Processes orphaned queue items
- Maintains data consistency

## Testing

Added test case `SyncService should skip calendars with pending deletions` to verify the functionality works correctly.

## Migration

No migration required - this is a backward-compatible change that only affects the sync process.

## Future Considerations

- Consider adding a dedicated "deleted calendars" tracking mechanism for more complex scenarios
- Monitor sync performance to ensure the additional queue checks don't impact performance
- Consider adding metrics to track how often pending deletions are skipped 