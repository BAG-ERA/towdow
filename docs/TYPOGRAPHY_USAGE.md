# FlowIt Typography System

## Overview

The FlowIt app now uses a comprehensive typography system based on Roboto Flex as the primary font, with proper fallbacks and special styling for different UI elements.

## Font Hierarchy

### Primary Font: Roboto Flex
- **Main font family**: Roboto Flex (via Google Fonts)
- **Fallbacks**: Roboto → Noto Sans → system-ui → sans-serif

### Domain Names: Roboto Serif (Thin)
- **Weight**: 100 (thin)
- **Usage**: Domain names and elegant headings
- **Fallbacks**: Roboto Serif → Roboto → Noto Serif → serif

### Primary Buttons: Capitalized Roboto Flex
- **Style**: Automatic capitalization
- **Weight**: 600 (semi-bold)
- **Letter spacing**: 1.25px for improved readability

## Usage Examples

### 1. Create Task Button Component (Recommended)

The `CreateTaskButton` component provides a consistent, properly styled button for task creation across the app:

```dart
import 'package:flowit_app/presentation/widgets/utils/buttons/create_task_button.dart';

// Standard create task button
CreateTaskButton(
  projectCalendarUid: 'project-123', // Optional project context
  onTaskCreated: (taskSummary) {
    print('Task created: $taskSummary');
  },
)

// Compact version for toolbars
CreateTaskButton.compact(
  projectCalendarUid: currentProject?.uid,
  backgroundColor: Colors.green, // Custom color
  onTaskCreated: _refreshTaskList,
)

// Prominent version for main areas
CreateTaskButton.prominent(
  projectCalendarUid: selectedProject?.uid,
  isFullWidth: true,
  onTaskCreated: (summary) => _showSuccessMessage(summary),
)

// Custom styling
CreateTaskButton(
  text: 'Add New Task',
  icon: Icons.add_task,
  backgroundColor: context.chartColors.success,
  textColor: Colors.white,
  size: CreateTaskButtonSize.large,
)
```

### 2. Primary Button Text (Manual Implementation)

```dart
// Using the helper method (recommended)
ChartThemeUsage.buildPrimaryButtonText(context, "Create Task")
// Output: "CREATE TASK" with proper styling

// Using the extension method
context.primaryButtonText("Add Project")
// Output: "ADD PROJECT" with proper styling

// Full primary button widget
ChartThemeUsage.buildPrimaryButton(
  context,
  text: "Create Task",
  onPressed: () {},
  icon: Icon(Icons.add),
)
```

### 3. Domain Name Text (Roboto Serif Thin)

```dart
// Using the helper method
ChartThemeUsage.buildDomainNameText(context, "Work Projects")

// Using the extension method
context.domainNameText("Personal Tasks")

// Direct style access
Text(
  "Project Management",
  style: context.domainNameStyle,
)
```

### 4. Regular Typography Styles

```dart
// All text styles now use Roboto Flex automatically
Text("Chart Title", style: context.chartTypography.titleLarge)
Text("Section Header", style: context.chartTypography.titleMedium)
Text("Body content", style: context.chartTypography.bodyMedium)
Text("Small details", style: context.chartTypography.bodySmall)
```

### 5. Complete Button Example

```dart
ElevatedButton.icon(
  onPressed: () => createNewTask(),
  icon: Icon(Icons.add),
  label: context.primaryButtonText("Create Task"),
  style: ElevatedButton.styleFrom(
    backgroundColor: context.chartColors.primary,
    foregroundColor: context.primaryButtonStyle.color,
  ),
)
```

## CreateTaskButton Component Features

### Size Variants
- **Small**: Compact size for toolbars (`CreateTaskButtonSize.small`)
- **Medium**: Standard size for most use cases (`CreateTaskButtonSize.medium`)
- **Large**: Prominent size for main actions (`CreateTaskButtonSize.large`)

### Factory Constructors
- **`CreateTaskButton.compact()`**: Pre-configured for toolbars and tight spaces
- **`CreateTaskButton.prominent()`**: Pre-configured for main action areas with larger styling

### Project Context Integration
- Pass `projectCalendarUid` to automatically assign new tasks to a specific project
- Follows FlowIt's workspace architecture patterns
- Integrates with existing task management workflow

### Customization Options
- Custom background color (defaults to theme primary)
- Custom text color (defaults to white)
- Custom text and icon
- Full-width option for layout flexibility
- Callback function when task is successfully created

## Typography Scales

### Light Theme Colors
- **Primary text**: `#1C1B1F`
- **Secondary text**: `#49454F`
- **Button text**: `#FFFFFF`
- **Domain names**: `#1C1B1F`

### Dark Theme Colors  
- **Primary text**: `#E6E1E5`
- **Secondary text**: `#CAC4D0`
- **Button text**: `#1C1B1F` (dark text on light buttons)
- **Domain names**: `#E6E1E5`

## Best Practices

1. **Use `CreateTaskButton` component** for all task creation actions to ensure consistency
2. **Provide project context** when available using `projectCalendarUid` parameter
3. **Choose appropriate size variant** based on UI context (compact for toolbars, prominent for main areas)
4. **Use callback functions** to handle post-creation actions like refreshing lists or showing confirmations
5. **Automatic capitalization** is handled for primary buttons - just provide normal text
6. **Material Design 3** principles are maintained throughout the typography system
7. **Font fallbacks** ensure the app works even if Google Fonts fails to load
8. **Responsive design** is supported with proper letter spacing and weights

## Quick Access

The theme provides several quick access methods:

```dart
// Direct style access
context.primaryButtonStyle
context.domainNameStyle
context.chartTypography.titleLarge

// Helper widgets
context.primaryButtonText("text")
context.domainNameText("text")

// Color coordination
context.chartColors.primary
context.taskStatusColor("COMPLETED")
```

## Component Integration Examples

### In Project Detail Screen
```dart
CreateTaskButton.compact(
  projectCalendarUid: project.calendarUid,
  onTaskCreated: (_) => ref.invalidate(projectTasksProvider),
)
```

### In Main Dashboard
```dart
CreateTaskButton.prominent(
  isFullWidth: true,
  onTaskCreated: (summary) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created: $summary')),
    );
  },
)
```

### In App Bar/Toolbar
```dart
CreateTaskButton.compact(
  backgroundColor: context.chartColors.success,
  onTaskCreated: _handleTaskCreated,
)
```

## Font Loading

Fonts are automatically loaded via the `google_fonts` package, which:
- Downloads fonts on first use
- Caches them locally
- Provides fallbacks if network is unavailable
- Ensures consistent rendering across platforms 