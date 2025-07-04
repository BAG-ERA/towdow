# CreateTaskButton Component - Usage Examples

## Overview

The `CreateTaskButton` component is a reusable, consistently styled button for creating tasks throughout the FlowIt application. It automatically handles the task creation dialog, project context, and follows the FlowIt typography system.

## Import Statement

```dart
import 'package:flowit_app/presentation/widgets/utils/buttons/create_task_button.dart';
```

## Basic Usage Examples

### 1. Simple Create Task Button

```dart
CreateTaskButton()
```
- Uses default text: "CREATE TASK"
- Default primary color from theme
- Medium size with add icon

### 2. Button with Project Context

```dart
CreateTaskButton(
  projectCalendarUid: project.calendarUid,
  onTaskCreated: (taskSummary) {
    // Handle successful task creation
    print('Task "$taskSummary" created in project ${project.name}');
  },
)
```

### 3. Custom Styled Button

```dart
CreateTaskButton(
  text: 'Quick Add',
  backgroundColor: Colors.green.shade600,
  textColor: Colors.white,
  icon: Icons.add_circle,
  size: CreateTaskButtonSize.large,
)
```

## Factory Constructor Examples

### Compact Button (for Toolbars)

```dart
// In AppBar actions
AppBar(
  title: Text('Project Tasks'),
  actions: [
    CreateTaskButton.compact(
      projectCalendarUid: currentProject.uid,
      onTaskCreated: (_) => _refreshTaskList(),
    ),
    SizedBox(width: 8),
  ],
)

// In FloatingActionButton replacement
CreateTaskButton.compact(
  backgroundColor: context.chartColors.success,
  onTaskCreated: (summary) => _showSnackBar('Created: $summary'),
)
```

### Prominent Button (for Main Areas)

```dart
// In main dashboard or project detail screen
CreateTaskButton.prominent(
  projectCalendarUid: selectedProject?.uid,
  isFullWidth: true,
  onTaskCreated: (taskSummary) {
    // Refresh relevant providers
    ref.invalidate(taskListProvider);
    ref.invalidate(projectTasksProvider);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task "$taskSummary" created successfully'),
        backgroundColor: context.chartColors.success,
      ),
    );
  },
)
```

## Integration with FlowIt Architecture

### 1. In Project Detail Screen

```dart
class ProjectDetailScreen extends ConsumerWidget {
  final Project project;
  
  const ProjectDetailScreen({super.key, required this.project});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          // Compact button in app bar
          CreateTaskButton.compact(
            projectCalendarUid: project.calendarUid,
            onTaskCreated: (_) {
              // Refresh project tasks when new task is created
              ref.invalidate(projectTasksProvider(project.calendarUid));
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Other project content...
          
          // Prominent button for main content area
          Padding(
            padding: EdgeInsets.all(16),
            child: CreateTaskButton.prominent(
              projectCalendarUid: project.calendarUid,
              isFullWidth: true,
              onTaskCreated: (taskSummary) {
                ref.invalidate(projectTasksProvider(project.calendarUid));
                _showTaskCreatedMessage(context, taskSummary);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _showTaskCreatedMessage(BuildContext context, String taskSummary) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task "$taskSummary" added to ${project.name}'),
        action: SnackBarAction(
          label: 'VIEW',
          onPressed: () {
            // Navigate to task or refresh view
          },
        ),
      ),
    );
  }
}
```

### 2. In Task List Widget

```dart
class TaskListWidget extends ConsumerWidget {
  final String? projectCalendarUid;
  
  const TaskListWidget({super.key, this.projectCalendarUid});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    
    return Column(
      children: [
        // Header with create button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tasks',
                style: context.chartTypography.titleMedium,
              ),
              CreateTaskButton.compact(
                projectCalendarUid: projectCalendarUid,
                onTaskCreated: (_) {
                  // Refresh task list
                  ref.invalidate(taskListProvider);
                },
              ),
            ],
          ),
        ),
        
        // Task list
        Expanded(
          child: tasks.when(
            data: (taskList) => ListView.builder(
              itemCount: taskList.length,
              itemBuilder: (context, index) => TaskItemWidget(
                task: taskList[index],
              ),
            ),
            loading: () => Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error: $error'),
            ),
          ),
        ),
        
        // Bottom action if no tasks
        if (tasks.valueOrNull?.isEmpty == true)
          Padding(
            padding: EdgeInsets.all(24),
            child: CreateTaskButton.prominent(
              text: 'Create Your First Task',
              projectCalendarUid: projectCalendarUid,
              isFullWidth: true,
              onTaskCreated: (_) => ref.invalidate(taskListProvider),
            ),
          ),
      ],
    );
  }
}
```

### 3. In Dashboard Home Screen

```dart
class DashboardSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Actions',
                  style: context.chartTypography.titleMedium,
                ),
                CreateTaskButton.compact(),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Quick task creation for different contexts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                CreateTaskButton(
                  text: 'Personal Task',
                  size: CreateTaskButtonSize.small,
                  backgroundColor: context.chartColors.tertiary,
                  onTaskCreated: _handlePersonalTask,
                ),
                CreateTaskButton(
                  text: 'Work Task',
                  size: CreateTaskButtonSize.small,
                  backgroundColor: context.chartColors.primary,
                  projectCalendarUid: _getWorkProjectUid(),
                  onTaskCreated: _handleWorkTask,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _handlePersonalTask(String taskSummary) {
    // Handle personal task creation
  }
  
  void _handleWorkTask(String taskSummary) {
    // Handle work task creation
  }
  
  String? _getWorkProjectUid() {
    // Return default work project UID
    return 'work-project-uid';
  }
}
```

## Advanced Customization

### Custom Color Themes

```dart
// Success theme
CreateTaskButton(
  backgroundColor: context.chartColors.success,
  textColor: Colors.white,
  icon: Icons.check_circle_outline,
)

// Warning theme  
CreateTaskButton(
  backgroundColor: context.chartColors.warning,
  textColor: context.chartColors.onSurface,
  icon: Icons.warning_outlined,
)

// Using project-specific colors
CreateTaskButton(
  backgroundColor: project.color ?? context.chartColors.primary,
  textColor: _getContrastingTextColor(project.color),
)
```

### Conditional Rendering

```dart
// Show different buttons based on context
Widget _buildCreateTaskButton(BuildContext context) {
  final hasActiveProject = ref.watch(activeProjectProvider) != null;
  
  if (hasActiveProject) {
    return CreateTaskButton.compact(
      projectCalendarUid: ref.read(activeProjectProvider)?.uid,
      onTaskCreated: _handleTaskCreated,
    );
  } else {
    return CreateTaskButton(
      text: 'Create Task (No Project)',
      backgroundColor: context.chartColors.warning,
      onTaskCreated: _handleTaskCreated,
    );
  }
}
```

## Integration with Riverpod Providers

```dart
// Refreshing multiple providers after task creation
CreateTaskButton.prominent(
  onTaskCreated: (taskSummary) {
    // Refresh all relevant providers
    ref.invalidate(taskListProvider);
    ref.invalidate(todayTasksProvider);
    ref.invalidate(soonTasksProvider);
    ref.invalidate(laterTasksProvider);
    ref.invalidate(anytimeTasksProvider);
    
    // Update project-specific providers if applicable
    if (projectCalendarUid != null) {
      ref.invalidate(projectTasksProvider(projectCalendarUid!));
      ref.invalidate(projectStatsProvider(projectCalendarUid!));
    }
  },
)
```

## Best Practices

1. **Always provide project context** when available using `projectCalendarUid`
2. **Use appropriate size variants** based on UI context
3. **Implement callbacks** to refresh relevant data providers
4. **Choose colors that match** the surrounding UI context
5. **Show feedback** to users when tasks are created successfully
6. **Handle errors gracefully** in the callback functions
7. **Consider accessibility** by providing meaningful text and adequate contrast 