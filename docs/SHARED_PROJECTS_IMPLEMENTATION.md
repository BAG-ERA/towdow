# Shared Projects Implementation

## Overview

This document describes the implementation of shared projects tracking in FlowIt, replacing the previous server-side `flowitOwner` comparison approach due to server issues.

## Architecture

### Models

#### SharedWithMeProject
- **Location**: `lib/data/models/shared_with_me_project.dart`
- **Fields**:
  - `projectId` (String): Project path/identifier  
  - `allTasks` (bool): Whether user has access to all tasks
  - `projectRight` (String): User's permission level (e.g., 'W' for write)
  - `sourceUserEmail` (String): Email of user who shared the project
  - `ack` (bool): User acknowledgment flag (defaults to false)

#### UserPreferences Updates
- **Location**: `lib/data/models/user_preferences.dart`
- **Added field**: `sharedWithMeProjects` (List<SharedWithMeProject>)
- **Added methods**:
  - `isProjectSharedWithMe(String projectId)`: Check if project is shared
  - `getSharedProject(String projectId)`: Get shared project details
  - `acknowledgeSharedProject(String projectId)`: Mark project as acknowledged

### Repositories

#### UserRepository Updates
- **Location**: `lib/data/repositories/user_repository.dart`
- **Added methods**:
  - `updateSharedWithMeProjects(List<SharedWithMeProject> projects)`
  - `acknowledgeSharedProject(String projectId)`

### Services

#### ShareService Integration
- **Location**: `lib/data/services/share_service.dart`
- **Key method**: `getProjectsSharedWithMe()` - Fetches shared projects from server

#### UserSyncService Updates  
- **Location**: `lib/data/services/user_sync_service.dart`
- **Added method**: `updateSharedProjects()` - Fetches and stores shared projects
- **Integration**: Called during both upload and download user data operations
- **S3 Sync**: Shared projects are now included in S3 serialization/deserialization

### UI Layer

#### TaskCalendar.isSharedWithMe() Updates
- **Location**: `lib/data/models/task_calendar.dart`
- **Before**: `isSharedWithMe(String? currentUserPrincipal)` - Compared `flowitOwner`
- **After**: `isSharedWithMe(WidgetRef ref)` - Accesses UserRepository directly through Riverpod
- **Usage**: No arguments needed - method accesses user preferences internally

## Implementation Flow

### 1. Data Sync Flow
```
UserSyncService.downloadUserData() 
└── updateSharedProjects()
    ├── ShareService.getProjectsSharedWithMe()
    ├── Convert to SharedWithMeProject objects  
    └── UserRepository.updateSharedWithMeProjects()
```

### 2. isSharedWithMe Usage Flow  
```
UI Component (with WidgetRef)
├── FutureBuilder<bool>(future: calendar.isSharedWithMe(ref))
└── TaskCalendar.isSharedWithMe() internally:
    ├── Access UserRepository via ref.read(userRepositoryProvider)
    ├── Get UserPreferences from repository
    └── Check if project path exists in sharedWithMeProjects
```

### 3. S3 Sync Integration
- Shared projects are automatically synced to S3 when user preferences change
- UserSyncService.uploadUserData() includes shared projects in serialization
- UserSyncService.downloadUserData() deserializes and stores shared projects

## Key Features

### Offline-First Architecture
- Shared projects are stored locally in UserPreferences
- Works offline once synced from server
- S3 sync ensures data persistence across devices

### Singleton Access Pattern
- No need to pass arguments to `isSharedWithMe()`
- Uses Riverpod for dependency injection to access UserRepository
- Consistent with project's MVVM architecture

### Acknowledgment System
- New shares default to `ack: false`
- UI can mark shares as acknowledged using `acknowledgeSharedProject()`
- Allows notification/highlighting of new shares

### Provider Support
- Account must have `providerType == 'towdow_cloud'` or `'towdow_selfhosted'`
- Custom CalDAV accounts are skipped (no sharing support)

## Migration Notes

### Breaking Changes
- `TaskCalendar.isSharedWithMe()` signature changed from `(String? userPrincipal)` to `(WidgetRef ref)`
- Method is now async and returns `Future<bool>`
- UI components must use FutureBuilder to handle async nature
- Hive adapter registration required for `SharedWithMeProject`

### Backwards Compatibility
- Old `flowitOwner` field remains for potential fallback
- Graceful handling when SharedService is unavailable

## Usage Example

### In UI Components (ConsumerWidget)
```dart
// Use FutureBuilder to handle async sharing check
FutureBuilder<bool>(
  future: calendar.isSharedWithMe(ref),
  builder: (context, snapshot) {
    final isShared = snapshot.data ?? false;
    
    return Text(isShared ? 'Shared with me' : 'My project');
  },
)

// Acknowledge a shared project
await userRepository.acknowledgeSharedProject(projectId);
```

### In ViewModel/Service Classes
```dart
// Get user preferences directly
final preferencesResult = await userRepository.getUserPreferences();
final preferences = preferencesResult.when(
  success: (prefs) => prefs,
  failure: (_) => UserPreferences.defaultPreferences(),
);

// Check if project is shared
final isShared = preferences.isProjectSharedWithMe(projectId);
```

## Files Modified

1. `lib/data/models/shared_with_me_project.dart` - NEW
2. `lib/data/models/user_preferences.dart` - Updated  
3. `lib/data/repositories/user_repository.dart` - Updated
4. `lib/data/services/user_sync_service.dart` - Updated
5. `lib/data/models/task_calendar.dart` - Updated `isSharedWithMe()` signature
6. `lib/main.dart` - Added Hive adapter registration
7. `lib/presentation/widgets/project_detail/project_info_card.dart` - Updated to use new async pattern

## Testing Recommendations

1. Test shared project fetching from server
2. Test S3 sync of shared projects
3. Test `isSharedWithMe()` with Riverpod dependency injection
4. Test FutureBuilder handling in UI components
5. Test acknowledgment functionality
6. Test offline behavior when shared projects are cached 