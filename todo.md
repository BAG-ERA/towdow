# FlowIt v0 Checklist

## 1. Development Environment & Project Setup

- [x] **Install Flutter & Configure IDE**  
  - Ensure Flutter SDK is installed and set up  
  - Configure an IDE (VS Code, Android Studio)  
  - Run `flutter doctor` to confirm no major issues

- [x] **Create Base Flutter Project**  
  - `flutter create flowit_app`  
  - Enable Windows/Linux/Android platforms

- [x] **Version Control**  
  - Initialize a Git repository  
  - Create a basic `.gitignore` (Flutter has a default)  
  - Write a brief README

## 2. Basic App Structure & UI Scaffolding

- [x] **Folder Structure**  
  - Create `lib/core/`, `lib/data/`, `lib/domain/`, `lib/presentation/` directories
  - Set up Clean Architecture structure

- [x] **Main Dart File & Routing**  
  - Set up a `MaterialApp` in `main.dart`  
  - Add a simple `HomeScreen`

- [x] **Theme & Colors**  
  - Define a `ThemeData` in `lib/core/theme/app_theme.dart`  
  - Apply it in `MaterialApp`

- [x] **Adaptive UI Skeleton**  
  - Create a placeholder `HomeScreen` with a scaffold  
  - **Desktop**: left nav panel; **Mobile**: drawer or bottom nav  
  - Use `LayoutBuilder` or `MediaQuery` for adaptive checks

## Next Steps:

- [x] **Enable Developer Mode for Windows**
  - Open Windows Settings
  - Go to Privacy & Security > For Developers
  - Enable "Developer Mode"

- [x] **Data Layer Implementation**  
  - Create Task model
  - Implement local storage service
  - Set up repositories

- [x] **UI Implementation**
  - Create task list view
  - Implement task creation form
  - Add task detail view (TODO)

## 3. Data Modeling & Local Storage

- [x] **Define Models**  
  - In `lib/models/`, add `Task`, `Project`, etc. with fields like `uid`, `summary`, `description`, `status`, `dueDate`

- [x] **Choose a Local DB**  
  - Pick a key-value store (Hive, Sembast, or SharedPreferences)  
  - In `lib/data/`, create a `LocalStorageService`

- [x] **Simple CRUD Operations**  
  - Implement `addTask`, `updateTask`, `deleteTask`, `getAllTasks` in `LocalStorageService`  
  - Test in the main screen's `initState`

- [x] **Basic State Management**  
  - Use Provider for dependency injection
  - TaskRepository manages task state

- [x] **List & Detail Views**  
  - [x] "Task List" page shows tasks from the provider  
  - [x] "Task Detail" page for editing a single task
  - [x] Saving updates to local store

- [x] **Task Detail Screen**
  - Create a dedicated screen for viewing/editing task details
  - Add support for all task fields (description, due date, etc.)
  - Implement markdown editing for description

- [x] **Project Detail Screen**
  - Create a dedicated screen for viewing project details
  - Show tasks within the project
  - Allow task reordering

## Next Tasks:

- [ ] **CalDAV Integration**
  - Research and implement CalDAV client
  - Set up sync logic
  - Handle conflicts

## 4. CalDAV Integration (Simple Phase)

- [ ] **Research CalDAV Libraries / HTTP**  
  - Check for existing Dart packages or use raw HTTP + DAV  
  - Document endpoints/methods

- [ ] **Test CalDAV Server**  
  - Spin up a local or use a hosted solution (e.g., Nextcloud)  
  - Get credentials for a test user

- [ ] **Basic Fetch VTODOs**  
  - In `CaldavService`, implement a method to get VTODO items  
  - Convert them to `Task` (or similar) models

- [ ] **Manual Sync Button**  
  - On the Task List screen, add a "Sync" button  
  - Tapping it pulls tasks from CalDAV into local storage (for now, maybe overwrite local)

- [ ] **Add/Edit Task → Send to CalDAV**  
  - When a task changes locally, push changes to the server  
  - Confirm updates on the CalDAV side

## 5. Conflict Resolution (Initial Implementation)

- [ ] **Track `LAST-MODIFIED`**  
  - Store the server's `LAST-MODIFIED` in your local records  
  - Compare local vs. remote on sync

- [ ] **Simple Last-Updated-Wins**  
  - If remote is newer, overwrite local  
  - If local is newer, push to server

- [ ] **Deletions**  
  - Decide how to handle tasks deleted locally or remotely (mark as `STATUS:CANCELLED` or remove them fully)

## 6. Basic Task Types (Project, Group, Task)

- [ ] **Introduce X-FLOWIT-TYPE**  
  - Store `x-flowit-type:task` or `x-flowit-type:task-group` for demonstration  
  - Distinguish them in code and local DB

- [ ] **UI Differentiation**  
  - Show a different icon or label for "group" vs. "task"  
  - Minimal UI logic for grouping tasks

- [ ] **Extend "Task List"**  
  - Possibly let tasks reference a parent group or project  
  - Keep the UI simple for now, but demonstrate the concept

## 7. Notion-Like Editor (Basic)

- [x] **Markdown TextField**  
  - Use a multi-line TextField for `description` with Markdown syntax  
  - Store text in `description`

- [x] **Render Markdown**  
  - On the detail view, optionally render the markdown preview  
  - Consider a Flutter markdown widget if time allows

- [ ] **Slash Commands** (Optional)  
  - If time permits, add a small slash command feature  
  - Otherwise, skip for v0

- [ ] **Task & Project Description Improvements**
  - [ ] Add slash commands for quick formatting (e.g., /heading, /list, /code)
  - [ ] Implement auto-rendering of markdown while typing
  - [ ] Enable inline editing in preview mode (click to edit specific sections)
  - [ ] Add auto-save functionality with debouncing
  - [ ] Support for task/user mentions with @
  - [ ] Support for date mentions with @today, @tomorrow
  - [ ] Add keyboard shortcuts for common formatting

## 8. Polishing & Testing

- [ ] **UI Cleanup**  
  - Ensure consistent layout and styling  
  - Possibly add app icons or placeholders

- [ ] **Offline Test**  
  - Create tasks while offline, confirm they sync on reconnection

- [ ] **Bug Fixes & Documentation**  
  - Document how to run the app and connect to CalDAV  
  - Let the intern fix discovered issues

- [ ] **v0 Release**  
  - Tag a Git release (e.g., `v0.0.1`)  
  - Provide desktop and mobile builds if feasible

## 9. (Optional) Post-v0 Enhancements

- [ ] **Refine Conflict Resolution**  
  - Possibly do a more granular field-by-field merge  
  - Provide user prompts to resolve conflicts manually

- [ ] **Implement Full Projects & Flows**  
  - Detailed grouping/hierarchy logic with `x-flowit-process`, etc.

- [ ] **Advanced Validation & Automations**  
  - Use `x-flowit-validator` schemas  
  - Let tasks be "automated-task" with triggers

- [ ] **Kanban & Calendar Views**  
  - Offer multiple views (board layout or monthly calendar)
