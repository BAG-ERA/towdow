# Move Task Feature Documentation

## Overview

The Move Task feature allows users to transfer tasks between different calendars/projects in FlowIt. This functionality maintains the offline-first architecture while ensuring proper synchronization with CalDAV servers.

## Architecture

### Core Components

1. **MoveTaskCommand** (`lib/presentation/viewmodels/commands/task_commands.dart`)
   - Implements the command pattern for move operations
   - Handles optimistic UI updates
   - Manages sync queue operations

2. **TaskViewModel.moveTask()** (`lib/presentation/viewmodels/task_viewmodel.dart`)
   - Provides high-level interface for moving tasks
   - Manages loading states and error handling
   - Coordinates with repositories and sync services

3. **MoveTaskDialog** (`lib/presentation/widgets/move_task_dialog.dart`)
   - User interface for selecting target calendar
   - Displays available calendars with visual indicators
   - Provides feedback during move operations

4. **TaskItemWidget Integration** (`lib/presentation/widgets/task_item_widget.dart`)
   - Context menu integration for move functionality
   - Accessible from both compact and expanded task views

## How It Works

### 1. User Interaction
- User taps the "Move Task" option in the task context menu
- `MoveTaskDialog` opens, showing available target calendars
- User selects destination calendar

### 2. Local Operations (Offline-First)
- Task's `sourceCalendarUid` is updated to point to target calendar
- Task is saved to local Hive storage immediately
- UI updates optimistically to reflect the change

### 3. Sync Queue Operations
The move operation is treated as two separate CalDAV operations:
- **DELETE**: Remove task from source calendar
- **CREATE**: Add task to target calendar

This approach ensures compatibility with CalDAV servers that don't support direct move operations.

### 4. Background Synchronization
- Operations are queued in the sync service
- Background sync processes the queue when online
- Conflict resolution uses last-modified timestamps

## Data Flow

```
User Action → MoveTaskDialog → TaskViewModel.moveTask() → 
├─ TaskRepository.save() (local update)
└─ SyncService.queueSyncOperation() (remote sync)
   ├─ DELETE from source calendar
   └─ CREATE in target calendar
```

## Key Features

### Offline Support
- Tasks can be moved while offline
- Changes are queued for sync when connectivity returns
- Local storage remains the source of truth

### Error Handling
- Graceful handling of network failures
- User feedback for success/failure states
- Retry mechanisms for failed sync operations

### Validation
- Prevents moving to the same calendar
- Handles tasks without source calendar assignment
- Validates calendar availability and permissions

### UI Integration
- Consistent with existing FlowIt design patterns
- Accessible from task lists and detail views
- Loading states and progress indicators

## Implementation Details

### Task Model Changes
No changes to the Task model were required - the existing `sourceCalendarUid` field is used to track calendar assignment.

### Sync Protocol
Move operations use standard CalDAV PUT/DELETE methods:
1. DELETE original VTODO from source calendar
2. PUT VTODO content to target calendar with same UID

### Calendar Filtering
The move dialog automatically filters:
- Only calendars that support VTODO objects
- Excludes the current source calendar
- Shows read-only status and other metadata

## Testing

Comprehensive tests cover:
- Command pattern execution
- ViewModel state management
- Sync queue operations
- Edge cases (null calendars, empty UIDs)
- Error scenarios

See `test/viewmodels/move_task_test.dart` for complete test coverage.

## Usage Examples

### From Task List
1. Long-press or right-click on task
2. Select "Move Task" from context menu
3. Choose destination calendar
4. Confirm operation

### From Task Detail View
1. Tap expanded task item
2. Use "Move Task" button in action bar
3. Select target calendar
4. Task is moved with visual feedback

## Integration with Existing Features

### Project Views
- Moving tasks updates project task counts
- Kanban boards reflect moved tasks immediately
- Project statistics are recalculated

### Sync Status
- Move operations appear in sync status indicators
- Progress tracking shows queue processing
- Error states are reported to users

### Search and Filtering
- Moved tasks appear in correct calendar contexts
- Search results update to reflect new locations
- Date-based filters work across calendars

## Performance Considerations

- Move operations are optimized for immediate UI feedback
- Batch processing of multiple moves is supported
- Sync queue prevents duplicate operations

## Future Enhancements

Potential improvements include:
- Bulk move operations for multiple tasks
- Move history and undo functionality
- Smart calendar suggestions based on task content
- Integration with automation rules 