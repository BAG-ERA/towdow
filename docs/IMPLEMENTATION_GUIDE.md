# FlowIt Implementation Guide

## Overview

This guide provides practical implementation details for developing FlowIt features, covering local storage, synchronization logic, UI implementation, and error handling patterns.

## Local Storage Implementation

### Key-Value Database Design
- Use a key-value database (Hive or Sembast) to store VTODO items locally
- Each item stored as JSON with fields: `uid`, `summary`, `description`, `x-flowit-*` data, `lastModified`, etc.
- Local DB serves as the main data store; sync engine updates/reads from CalDAV in background

### Storage Schema
```dart
// Example local storage structure
class LocalTaskStorage {
  final Map<String, dynamic> taskData = {
    'uid': 'task-uuid-here',
    'summary': 'Task title',
    'description': 'Task description with Markdown',
    'status': 'NEEDS-ACTION',
    'due': '20250115T170000Z',
    'lastModified': '20250101T091500Z',
    'xFlowItType': 'task',
    'xFlowItValidator': [],
    'xFlowItRequirement': {},
    'xFlowItProcess': 'project-uuid',
    // ... other fields
  };
}
```

### Offline-First Strategy
- Local database is authoritative for user experience
- All UI operations work against local data immediately
- Background sync reconciles with server when available
- Graceful degradation when network unavailable

## Synchronization Logic

### Sync Flow Implementation
1. **Fetch remote**: On startup or periodic intervals, download updated items from CalDAV
2. **Apply merges**: Compare LAST-MODIFIED; resolve conflicts based on timestamps
3. **Queue changes**: Store user edits locally when offline; push when online
4. **Conflict resolution**: Use "last-updated wins" or field-by-field merge when feasible

### Conflict Resolution Strategy
```dart
class ConflictResolver {
  VTodoItem resolveConflict(VTodoItem local, VTodoItem remote) {
    // Compare LAST-MODIFIED timestamps
    if (local.lastModified.isAfter(remote.lastModified)) {
      return local; // Local wins
    } else if (remote.lastModified.isAfter(local.lastModified)) {
      return remote; // Remote wins
    } else {
      // Same timestamp - attempt field-by-field merge
      return attemptMerge(local, remote);
    }
  }
}
```

### Background Sync Management
- Use Flutter's background processing for sync operations
- Queue operations for batch processing
- Handle network availability changes
- Provide sync status feedback to users

## UI Implementation Guidelines

### Screen Architecture
- **Home Screen**: List tasks for "Today," "Soon," "Unregistered"
- **Project Detail**: Show tasks and groups within that project
- **Flow Detail**: If x-flowit-type = flow, show pipeline or sequence
- **Task Edit**: Page for editing SUMMARY, DESCRIPTION, validators, etc.
- **Category Management**: Interface for adding, removing, and organizing categories

### Key Widget Components

#### Notion-Like Editor
```dart
class NotionLikeEditor extends StatefulWidget {
  final String initialMarkdown;
  final Function(String) onChanged;
  
  // Supports:
  // - Markdown rendering and editing
  // - Slash commands for special blocks
  // - Rich text formatting
  // - Storage in DESCRIPTION field
}
```

#### Validator Rendering
```dart
class ValidatorWidget extends StatelessWidget {
  final List<List<Validator>> validatorLists;
  final Function(List<List<Validator>>) onChanged;
  
  // Renders:
  // - Checklist validators with checkboxes
  // - Single select validators with radio buttons/dropdowns
  // - Free field validators with text inputs
  // - Progress indicators for completion
}
```

#### Category Management
```dart
class CategoryChip extends StatelessWidget {
  final String category;
  final Color color;
  
  // Visual representation as colored Material chips
}

class CategoryDialog extends StatefulWidget {
  // Dedicated UI for managing task and project categories
  // - Add new categories
  // - Edit existing categories
  // - Color assignment
  // - Category organization
}
```

### Adaptive Layout Implementation
```dart
class AdaptiveLayout extends StatelessWidget {
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width >= 800) {
      // Desktop layout: sidebar + main content
      return DesktopLayout();
    } else {
      // Mobile layout: drawer + full screen content
      return MobileLayout();
    }
  }
}
```

## Error Handling & Edge Cases

### Conflict Resolution Edge Cases
```dart
class EdgeCaseHandler {
  VTodoItem handleSameTimestamp(VTodoItem local, VTodoItem remote) {
    // When LAST-MODIFIED is identical
    // Server typically decides or careful field merge
    return serverDecidedMerge(local, remote);
  }
  
  Map<String, dynamic> handleEmptyJSON() {
    // If x-flowit-* fields are not relevant
    // Store {} or [] rather than null
    return {};
  }
  
  void handleDeletion(String taskUid) {
    // Mark as STATUS:CANCELLED or remove entirely
    // Handle references in x-flowit-* fields carefully
    updateReferencingTasks(taskUid);
  }
}
```

### Network Error Handling
- Graceful offline mode transitions
- User notification of sync status
- Retry mechanisms for failed operations
- Data consistency preservation

### Validation Error Handling
```dart
class ValidationHandler {
  bool validateVTodoData(Map<String, dynamic> data) {
    // Validate required fields
    if (!data.containsKey('uid') || !data.containsKey('summary')) {
      return false;
    }
    
    // Validate x-flowit-* JSON fields
    if (!isValidJSON(data['xFlowItValidator'])) {
      data['xFlowItValidator'] = []; // Fallback to empty
    }
    
    return true;
  }
}
```

## State Management Patterns

### Provider/Riverpod Integration
```dart
// Example using Riverpod
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    localStorage: ref.watch(localStorageProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

final taskListProvider = FutureProvider.family<List<Task>, String>((ref, projectUid) {
  return ref.watch(taskRepositoryProvider).getTasksForProject(projectUid);
});
```

### Optimistic State Updates
```dart
class TaskViewModel extends ChangeNotifier {
  Future<void> updateTaskSummary(String taskUid, String newSummary) {
    // 1. Update local state immediately
    updateLocalTask(taskUid, summary: newSummary);
    notifyListeners();
    
    // 2. Queue background sync
    syncService.queueTaskUpdate(taskUid);
  }
}
```

## Performance Optimization

### Database Optimization
- Index frequently queried fields (project UID, due dates)
- Efficient pagination for large task lists
- Background database maintenance

### UI Performance
```dart
class OptimizedTaskList extends StatelessWidget {
  Widget build(BuildContext context) {
    return ListView.builder(
      // Use builder for large lists
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return TaskItemWidget(
          key: ValueKey(tasks[index].uid), // Stable keys
          task: tasks[index],
        );
      },
    );
  }
}
```

### Memory Management
- Dispose of controllers and listeners properly
- Use weak references for large cached objects
- Implement proper lifecycle management

## Testing Strategy

### Unit Tests
```dart
void main() {
  group('Task Repository Tests', () {
    test('should update task locally and queue sync', () async {
      final repository = TaskRepository(mockStorage, mockSync);
      await repository.updateTask(testTask);
      
      verify(mockStorage.updateTask(testTask));
      verify(mockSync.queueUpdate(testTask.uid));
    });
  });
}
```

### Integration Tests
- Test sync scenarios with mock CalDAV server
- Validate conflict resolution logic
- Test offline/online transitions

### Widget Tests
- Test validator rendering and interaction
- Validate adaptive layout behavior
- Test category management UI

## Security Considerations

### Data Protection
- Encrypt sensitive data in local storage
- Secure credential management for CalDAV
- Input validation and sanitization

### Network Security
- HTTPS-only communication
- Certificate validation
- Authentication token management

## Deployment Considerations

### Platform-Specific Implementation
- Handle platform differences (desktop vs mobile)
- Platform-specific native integrations
- File system permissions and storage locations

### Configuration Management
```dart
class ConfigManager {
  static const String caldavEndpoint = String.fromEnvironment('CALDAV_ENDPOINT');
  static const bool debugMode = bool.fromEnvironment('DEBUG_MODE');
  
  // Environment-specific configurations
  // Server endpoints, feature flags, etc.
}
```

## Migration Strategies

### Legacy Data Migration
```dart
class MigrationService {
  Future<void> migrateLegacyProjects() {
    // Convert x-flowit-type:project VTODOs to VCALENDAR level
    // Update references and relationships
    // Preserve data integrity during transition
  }
}
```

### Schema Evolution
- Handle new x-flowit-* field additions
- Maintain backward compatibility
- Graceful handling of unknown fields

---
*For architectural overview, see [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)*
*For data model details, see [DATA_MODEL_SPECIFICATION.md](DATA_MODEL_SPECIFICATION.md)*
*Last updated: 2024-12-19* 