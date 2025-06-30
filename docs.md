# FlowIt Documentation

## Overview

FlowIt is a cross-platform application (desktop on Windows/Linux and mobile on Android) built with Flutter. It helps users manage tasks, projects, and workflows in an offline-first manner while synchronizing data to a CalDAV server using VTODO objects. FlowIt extends the standard iCalendar VTODO format with custom x-flowit-* properties to support advanced workflows, forms, and automations.

### Key Principles

- **Offline-First**: Local storage is the source of truth, ensuring reliable usage even when offline
- **Optimistic UI**: The app updates immediately on user actions, then synchronizes changes in the background
- **Minimal Dependencies**: Relies primarily on Flutter's Material widgets and standard libraries
- **Adaptive UX**: Single codebase supporting both desktop (with persistent sidebars) and mobile (with slide-out navigation)
- **Interoperability**: Uses standard iCalendar fields for compatibility, with custom x-flowit-* fields for advanced features

## Architecture

FlowIt follows a layered architecture pattern:

### Data Layer

- **Models**: Define the core data structures (Task, Project)
- **Repositories**: Provide an abstraction over data sources
- **Services**: Implement core functionality like CalDAV synchronization and local storage

### Presentation Layer

- **Screens**: Full-page UI components
- **Widgets**: Reusable UI components
- **Theme**: Consistent styling across the application

### Core

- **Tools**: Utility functions and helpers
- **Constants**: Application-wide constants

## Data Model

### TaskModel

The central data structure representing a task, group, or project. Maps directly to CalDAV VTODO objects.

**Standard iCalendar fields:**
- `uid`: Unique identifier
- `summary`: Task title
- `description`: Detailed task description (supports Markdown)
- `status`: Current state (NEEDS-ACTION, COMPLETED, CANCELLED)
- `dueDate`: When the task is due
- `lastModified`: When the task was last changed
- `created`: When the task was created
- `attendees`: List of people assigned to the task
- `attachments`: List of attached files

**FlowIt-specific extensions:**
- `type`: The type of item (task, task-group, automated-task, flow, project)
- `validator`: Defines how a task is completed (simple checkbox or form)
- `requirement`: Prerequisites or resources needed
- `templateUid`: Reference to a template VTODO
- `processUid`: Reference to parent flow/process
- `reversalTaskUid`: Reference to "undo" task
- `automation`: Automation triggers (for automated-task type)
- `context`: Extra context data

### ProjectModel

Extends TaskModel with additional project-specific fields:
- `etag`: HTTP ETag for synchronization
- `path`: CalDAV resource path
- `calendarId`: Associated calendar identifier

## Core Processes

This section details the key operational flows within FlowIt, describing how data moves through the application.

### Task Creation Process

1. **User Interface**: 
   - `TaskForm` widget collects data for a new task (summary, description, due date)
   - User enters details and clicks "Create"

2. **Local Storage Update**:
   - `TaskRepository.createTask()` is called with the collected data
   - A new `TaskModel` is created with a generated UUID
   - Local storage is updated via `_storage.saveTask(task)`

3. **Server Synchronization**:
   - For project-based tasks, `CaldavService.createTask()` is called
   - `CalDAVVTodoCreator.createTask()` formats the task as a VTODO object
   - A PUT request is sent to the CalDAV server to create the resource
   - On success, the task is now synchronized between local storage and server

### Task Description Update Process

1. **User Interface**:
   - `MarkdownEditor` widget in `TaskItem` captures user edits to the description
   - Changes to the description trigger `onChanged` callback
   - "Save" button is provided to explicitly save changes to the server

2. **Local Storage Update** (Immediate):
   - During typing, description changes are immediately applied to the local task:
     - `TaskRepository.updateTaskDescription(uid, description)` is called
     - This retrieves the task, creates an updated copy, and saves to local storage
     - UI is updated immediately to reflect changes (optimistic UI)

3. **Server Synchronization** (Manual):
   - When "Save" button is clicked, `CaldavService.updateTaskDescription(task, description)` is called
   - This method:
     1. Finds the correct calendar for the task
     2. Creates a WebDAV client connection
     3. Generates iCalendar content with the updated description
     4. Sends a PUT request to update the task on the server
     5. Returns success/failure status
   - User is notified of success/failure via a SnackBar

### Task Status Update Process

1. **User Interface**:
   - Status changes (Complete/Cancel) are triggered via checkboxes in `TaskItem`
   - Different screens may provide dedicated buttons for quick status changes

2. **Standard Completion Flow**:
   - `TaskRepository.completeTask(uid)` is called when a simple completion is needed
   - This updates the task status to `TaskStatus.completed` and sets a new `lastModified` timestamp
   - The updated task is saved to local storage

3. **Validator Completion Flow**:
   - For tasks with form validators, `TaskRepository.completeTaskWithValidator(uid, validatorWithAnswers)` is called
   - This process:
     1. Extracts form answers from the validator data
     2. Stores answers in the task's context
     3. Adds a form summary to the task description
     4. Updates the task's status to completed
     5. Saves the updated task to local storage

4. **Server Synchronization**:
   - `CaldavService.updateTaskStatus(task, status)` is called
   - `CalDAVVTodoUpdater.updateTaskStatus()` generates updated iCalendar content
   - A PUT request updates the task on the CalDAV server

### Task Form Updates (Multiple Fields)

1. **User Interface**:
   - `TaskForm` widget allows editing multiple task fields simultaneously
   - Fields include: summary (title), description, due date, type

2. **Local Storage Update**:
   - When a task is edited, `TaskRepository.updateTask(updatedTask)` is called
   - This method replaces the entire task object in local storage
   - All fields are updated in a single operation

3. **Server Synchronization**:
   - `CaldavService.updateTask(task)` is called for server updates
   - `CalDAVVTodoUpdater.updateTask()` serializes the complete task to iCalendar format
   - The entire VTODO object is replaced on the server via PUT request

### Task Validator Updates

1. **User Interface**:
   - `ValidatorFormBuilder` allows creating and editing task validators
   - Users can switch between default and form validators
   - For form validators, questions and options can be added/edited

2. **Local Storage Update**:
   - `TaskRepository.updateTaskValidator(uid, validator)` updates the validator
   - The task is retrieved, updated with the new validator, and saved to local storage

3. **Task Completion with Validators**:
   - `ValidatorFormRenderer` displays the form for user input when completing a task
   - On submission, `TaskRepository.completeTaskWithValidator()` is called
   - Answers are stored in the task context and a summary is added to the description

4. **Server Synchronization**:
   - Validator changes are sent to the server as part of task updates
   - The validator is stored in the `X-FLOWIT-VALIDATOR` property in the VTODO object

### Due Date Updates

1. **User Interface**:
   - Due date can be set from `TaskForm` or directly in some task views
   - Date picker allows selecting the date

2. **Local Storage Update**:
   - `TaskRepository.updateTaskDueDate(uid, dueDate)` is called
   - The task is updated with the new due date and saved locally

3. **Server Synchronization**:
   - `CaldavService.updateTaskDueDate(task, dueDate)` sends the update to the server
   - The DUE field in the VTODO object is updated on the CalDAV server

## Key Features

### Currently Implemented

1. **CalDAV Integration**
   - Connect to CalDAV server
   - Read/write VTODO objects
   - Two-way synchronization

2. **Project & Task Management**
   - Create/edit/delete projects
   - Create/edit/delete tasks
   - Update task status (complete/cancel)
   - Group tasks within projects

3. **Rich Text Description**
   - Markdown editor for task and project descriptions
   - Preview mode for formatted content

4. **Task Views**
   - Projects list
   - Tasks by project
   - Task details

5. **Adaptive Layout**
   - Desktop: Persistent sidebar navigation
   - Mobile: Slide-out drawer navigation

### In Progress / Planned

1. **Kanban Boards**
   - Visualize tasks in columns
   - Drag and drop for status updates

2. **Validators & Forms**
   - Custom forms for task completion
   - Validation rules

3. **Flows**
   - Sequential task processes
   - Dependency management

4. **Calendar View**
   - Timeline visualization
   - Due date management

## UI Components

### Main Screens

- **MainScreen**: Application shell with navigation
- **HomeScreen**: Dashboard with recent/important tasks
- **ProjectDetailScreen**: View and manage tasks within a project

### Key Widgets

- **ProjectList**: Displays available projects
- **TaskItem**: Individual task display with actions
- **MarkdownEditor**: Rich text editor for descriptions
- **ProjectKanban**: Board view for project tasks
- **ValidatorFormBuilder**: UI for creating task validation forms
- **ValidatorFormRenderer**: UI for completing tasks with validators

## Synchronization

FlowIt uses a bidirectional synchronization mechanism:

1. **Local Updates**
   - User changes are applied to local storage immediately
   - Updates are queued for server synchronization

2. **Server Synchronization**
   - Changes are pushed to the CalDAV server
   - Remote changes are pulled and merged

3. **Conflict Resolution**
   - Last-modified timestamp determines which version wins
   - Where possible, field-level merges are attempted

## Implementation Details

### Repository Pattern 

The TaskRepository serves as an abstraction layer between UI components and data sources:

```dart
// Create a new task
Future<TaskModel> createTask({required String summary, ...})

// Update an existing task
Future<void> updateTask(TaskModel task)

// Field-specific updates
Future<void> updateTaskDescription(String uid, String description)
Future<void> updateTaskValidator(String uid, Map<String, dynamic> validator) 
Future<void> updateTaskDueDate(String uid, DateTime? dueDate)

// Status changes
Future<void> completeTask(String uid)
Future<void> cancelTask(String uid)
Future<void> completeTaskWithValidator(String uid, Map<String, dynamic>? validators)
```

### CalDAV Integration

CaldavService provides methods for interacting with the CalDAV server:

```dart
// Task operations
Future<TaskModel?> createTask({required String projectUid, required String summary, ...})
Future<bool> updateTask(TaskModel task)
Future<bool> updateTaskStatus(TaskModel task, TaskStatus status)
Future<bool> updateTaskDescription(TaskModel task, String description)
Future<bool> updateTaskDueDate(TaskModel task, DateTime? dueDate)
Future<bool> deleteTask(TaskModel task)

// Project operations
Future<ProjectModel?> createProject({required String summary, ...})
Future<bool> updateProjectDescription(ProjectModel project, String description)
Future<bool> deleteProject(ProjectModel project)
```

## Getting Started (Development)

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (included with Flutter)
- Android Studio / VS Code with Flutter plugins
- A CalDAV server for testing

### Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure a CalDAV server for development
4. Run the app with `flutter run`

## Roadmap

### Short Term

- Enhance task description editing
- Improve offline synchronization
- Add basic form validators

### Medium Term

- Implement kanban boards
- Add calendar views
- Support file attachments

### Long Term

- Implement flows and automated tasks
- Add advanced validators
- Support for webhooks and external integrations

---

*This documentation is maintained alongside the FlowIt codebase and will be updated as new features are implemented.* 