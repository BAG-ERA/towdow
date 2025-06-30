# FlowIt – v0 Implementation Checklist

> This single document is intended for an LLM (or human) to follow **step-by-step** and fully build FlowIt from scratch.  It mirrors the detailed requirements in `specs.md`, removes deprecated concepts (group, step), and encodes every architectural rule from the workspace guidelines.

---

## 0. Project Skeleton

- [x] **Create Flutter project** `flutter create flowit_app`
- [x] **Enable Windows/Linux/Android targets**
- [x] **Add dependencies to `pubspec.yaml`**
  - Riverpod (`flutter_riverpod`)
  - Hive (`hive`, `hive_flutter`)
  - HTTP (`http`)
  - UUID (`uuid`)
  - Markdown renderer (`flutter_markdown`)
  - Equality (`equatable`)
  - Logging (`logger`)
  - Test/Mock packages (`flutter_test`, `mocktail`)
- [x] **Configure analysis & formatting rules** (`analysis_options.yaml`)
- [ ] **Tooling** – set up code-generation watch task: `flutter pub run build_runner watch --delete-conflicting-outputs`

## 1. Layer-First Folder Structure  
_Follow separation of concerns & MVVM with Riverpod._

```
lib/
  core/            <-- cross-cutting utils & logging
  data/
    models/        <-- immutable Freezed models
    hive_adapters/ <-- generated Hive type adapters
    repositories/  <-- abstract + impl classes
    services/      <-- CalDAV, sync, local storage
  presentation/
    viewmodels/    <-- ChangeNotifier/StateNotifiers
    screens/       <-- one folder per screen
    widgets/       <-- dumb, reusable widgets
  app.dart         <-- ProviderScope + Router
main.dart
```

**Status: ✅ COMPLETED**

## 2. Domain Models  
_All generated with `freezed` + `hive_type` annotations._

- [x] **Base model** `FlowitItem` (common fields: uid, summary, description, status, lastModified, created, due, categories)
- [x] **Project** (`x-flowit-type: project`)
- [x] **Task** (`x-flowit-type: task`)
- [x] **AutomatedTask** (`x-flowit-type: automated-task`)
- [x] **CaldavAccount** – providerType, serverUrl, username/email, optional token/password, selectedCalendars
- [x] **Validator** (default / form schema)
- [ ] **Requirement**, **Automate**, **Context**, **Kanban** value objects

### Core Utilities
- [x] **Result<T> / Failure** classes (either style) for error propagation without exceptions
- [x] Global `Logger` wrapper using `logger` package
- [ ] Git hooks via `lefthook` (or `pre-commit`) to run format, analyze and tests before each commit

## Internationalization & Localization
- [ ] Add `flutter_localizations` and configure `l10n.yaml`
- [ ] Generate `arb` file for English (`app_en.arb`) – future languages can extend
- [ ] Provide `AppLocalizations` lookup in `MaterialApp`

## 3. Local Storage (Hive)

- [x] **Open Hive boxes at app start** (`tasksBox`, `projectsBox`, `accountBox`)
- [x] **Write & read adapters** for every model
- [x] **LocalStorageService**
  - [x] `Future<List<T>> getAll<T>()`
  - [x] `Future<void> put<T>(T item)`
  - [x] `Future<void> delete<T>(Uid uid)`
  - [x] Stream list for reactive UI
- [ ] Use `flutter_secure_storage` to encrypt sensitive fields (password, token)
- [ ] Plan for box migrations: bump Hive box version & write `Adapter.migrate()` when models change

**Status: ✅ MOSTLY COMPLETED** (secure storage pending)

## 4. Repository Pattern

- [x] Abstract interfaces: `TaskRepository`, `ProjectRepository`, `AccountRepository`
- [x] Local implementation wraps `LocalStorageService`
- [ ] Sync implementation composes Local + CalDAV-Sync queue
- [x] Provide repositories via Riverpod providers

**Status: ✅ MOSTLY COMPLETED** (sync implementation pending)

## 5. Sync Engine & CalDAV Service  
_Full offline queue, retry, capability discovery._

- [ ] **CapabilityDiscoveryService** – OPTIONS & PROPFIND
- [ ] **WebDavClient** – low-level HTTP helpers
- [ ] **CaldavService**
  - [ ] Pull list of VTODOs (paginated)
  - [ ] Push inserts / updates / deletions (batch when possible)
  - [ ] Map iCalendar ↔ model
- [ ] **SyncQueue** (Hive box `syncQueueBox`)
  - [ ] Enqueue local mutations when offline
  - [ ] Background worker flushes queue
  - [ ] Use ETags + `LAST-MODIFIED` for conflict detection
- [ ] **ConflictResolver** – last-modified wins (v0)
- [ ] **SyncController** Riverpod provider – exposes `syncNow()` & sync status stream

## 6. State Management (Riverpod)

- [x] Global `ProviderScope` in `main.dart`
- [x] `taskRepositoryProvider`, `projectRepositoryProvider`, etc.
- [x] `taskListProvider` (AsyncValue<List<Task>>)
- [x] `selectedProjectProvider`, `selectedTaskProvider` etc.
- [x] `syncStatusProvider`

**Status: ✅ COMPLETED**

## 7. ViewModels & Commands  
_Each screen gets its own ViewModel (StateNotifier)._ 

Example: `TaskListViewModel`
- expose `tasks`, `syncing`, `filter`
- commands `addTask()`, `toggleComplete(uid)`, `deleteTask(uid)`

**Status: ❌ TODO**

## 8. UI Screens

- [x] **HomeScreen** – today / soon / unregistered lists
- [x] **ProjectDetailScreen** – workspace for a single project (task lists & optional kanban view)
- [x] **TaskDetailScreen** – full-screen editor for a single task (summary, markdown, validator, metadata)
- [x] **SettingsScreen** – CalDAV connection, server capability panel, theme toggle, diagnostics
- [x] **ConnectionScreen** – onboarding screen shown when no account is configured

**Status: ✅ COMPLETED** (basic placeholder screens)

### Screen Overview (non-technical)

FlowIt has four main areas:
1. Home – shows tasks grouped into Today, Soon, and Unregistered tabs, providing a quick glance at upcoming work.
2. Project Detail – focuses on a single project with either a kanban board or classic task list and displays sync status.
3. Task Detail – rich editor where users modify task fields, markdown description, and validator forms.
4. Settings – houses CalDAV setup, theme switch, and diagnostic tools.

### Adaptive Navigation (high-level)

On desktop, FlowIt displays a fixed left sidebar that combines the main navigation (**My Tasks, Projects, Settings**) with a scrollable project list. Selecting a destination updates the content pane on the right.

On mobile, the sidebar becomes a slide-out drawer. When a user picks a destination, the drawer closes and the content fills the screen; a Floating Action Button appears where appropriate.

### User Flows (first-run & everyday)

1. **App launch**  
   a. Check if a CalDAV connection is stored locally.  
   b. If **none** → navigate to **ConnectionScreen**.  
   c. Else → proceed to **HomeScreen** and start background sync.

2. **ConnectionScreen** (onboarding)  
   • Displays four connection cards: _FlowIt Cloud_, _Google account_, _Nextcloud account_, _Custom CalDAV_.  
   • Upon choosing one, show a credentials form:  
     – FlowIt Cloud: email + password.  
     – Google: OAuth flow.  
     – Nextcloud / Custom: server URL, username, password.  
   • After the credentials are validated, run capability discovery and show a summary (supported components, privileges, etc.).  
   • If **existing calendars** of type VTODO are found → show multi-select list so the user can choose which ones to sync.  
   • If **no calendars** are found → prompt the user to create the first _Project_ (a new remote calendar).  
   • ⛔ **Only one account may exist at a time**: if a connection already exists, this screen is skipped until the user disconnects the current account in Settings.

3. **Offline / connectivity issues**  
   • If the stored account cannot connect (e.g., no internet), show a red cloud-off icon in the top-right corner across the app.  
   • Tapping shows error details and a retry action.  
   • Local tasks stay usable; sync queue waits until connectivity resumes.

4. **Normal operation**  
   • Background sync runs on startup and every N minutes (configurable).  
   • Manual sync button in HomeScreen triggers `syncNow()`.  
   • Task/project edits update local Hive immediately (optimistic UI) and enqueue server updates.

5. **Account management**  
   • In Settings → Connections, the user can _disconnect_ the current CalDAV account.  
   • Once disconnected, the app returns to **ConnectionScreen** to set up a new account.  
   • The user chooses whether to keep or delete local data tied to the previous account.


### Layout Structure (Widget Trees)

- **HomeScreen**
  - `AdaptiveNavigation` (wrapper)
    - `Scaffold`
      - `AppBar`
      - `TabBar` (Today | Soon | Unregistered)
      - `TabBarView`
        - Each tab: `TaskList`
      - `FloatingActionButton` → opens `TaskForm`

- **ProjectDetailScreen**
  - `AdaptiveNavigation` (wrapper)
    - `Scaffold`
      - `AppBar` with project title & sync status chip
      - Body: `KanbanBoard` OR vertical `TaskList` (toggle)
      - `FloatingActionButton` → create task in project

- **TaskDetailScreen**
  - `Scaffold`
    - `AppBar` with Save/Share actions
    - Body: `SingleChildScrollView`
      - `TextField` SUMMARY
      - `MarkdownEditor` DESCRIPTION
      - `ValidatorFormRenderer` (if validator.type == form)
      - Metadata chips (due date, categories, attachments)

- **SettingsScreen**
  - `Scaffold`
    - `ListView`
      - `ServerConnectionDialog` (CalDAV credentials)
      - Theme toggle
      - Debug / diagnostics section (export logs, clear cache)
      - App version & license

### UX & Interaction Design

- Task Creation / Editing
  - [ ] FloatingActionButton (mobile) or toolbar button (desktop) opens **TaskForm** in a modal bottom-sheet.
  - [ ] Fields: Summary (required), Description (Markdown), Due date (optional).
  - [ ] After save, close sheet and refresh current list.

- Lists & Widgets
  - [ ] **TaskList** shows tasks with status checkbox, due-date chip, categories chips.
  - [ ] **KanbanBoard** (ProjectDetail) renders columns from `x-flowit-kanban`; drag-drop optional.
  - [ ] **CalendarItemList** groups projects/flows under each connected calendar.
  - [ ] **SyncStatusBanner** atop content shows "Last sync … / Error".

- Navigation
  - [ ] **AdaptiveNavigation** widget wraps every screen.
    - Desktop (≥ 900 px): persistent `NavigationRail` + vertical divider + main content.
    - Mobile (< 900 px): `Drawer` menu slides in; main `Scaffold` hides navigation until user selects.
  - [ ] Items: My Tasks, Projects, Settings.
  - [ ] Side list (`ProcessList`) shows connected calendars → projects; clicking opens project detail.

### Accessibility & Inclusivity
- [ ] Ensure minimum contrast ratios (Material ColorScheme + high-contrast check)
- [ ] Respect OS font-size / text-scale-factor across all widgets
- [ ] Full keyboard navigation on desktop (Tab traversal, Enter/Space activation)
- [ ] Provide semantic labels for icons and custom controls

- Theming
  - [ ] Implement `AppTheme` (Material 3) with seeded blue color, dark & light variants, rounded 12 px cards, 8 px text-fields, 16 px FAB.
  - [ ] Provide `ThemeMode` toggle in Settings.
  - [ ] On first launch, default to system theme (light/dark) before user overrides.

- Desktop polish (Windows/Linux)
  - [ ] Custom title-bar (`CustomTitleBar`) when `Platform.isWindows` – integrates window controls & page actions.


- Markdown Editing
  - [ ] Use `appflowy_editor` package for Notion-like editor.
  - [ ] Live conversion document ↔ markdown string.
  - [ ] Debounced background sync via `onServerUpdate` callback.


- Interaction patterns
  - [ ] Desktop shortcuts: Ctrl+N (new task), Ctrl+Shift+N (new project), Ctrl+S (save).
  - [ ] Pull-to-refresh gesture on mobile lists triggers `syncNow()`.
  - [ ] Context menu (right-click / long-press) on list items exposes delete / duplicate / convert-type actions.


## 9. Widgets & Components

- Markdown editor with live preview (`flutter_markdown`)
- Validator Form renderer (select / multiselect / freefield)
- Kanban board list (drag & drop optional later)
- SyncStatusBanner (shows last sync / errors)
- CategoryChips & dialogs

## 10. Routing

- Use `go_router` or Navigator 2 (choose one)
- Named routes: `/`, `/connect`, `/project/:uid`, `/task/:uid`, `/settings`

## 11. Testing Strategy

### Unit Tests
- [ ] Every model's `fromJson` / `toJson`
- [ ] All repository methods (using Hive in memory)
- [ ] Sync engine conflict logic (with fake CalDAV)

### Widget Tests
- [ ] HomeScreen list renders tasks correctly
- [ ] TaskDetailScreen edits & saves

### Integration Tests
- [ ] End-to-end: create task offline → enable fake server → auto-sync

### CI
- [ ] GitHub Actions matrix builds: `flutter test`, `flutter analyze`
- [ ] Build artifacts: `flutter build windows --release`, `flutter build linux --release`, `flutter build apk --release`
- [ ] Upload release artifacts to GitHub Releases draft
- [ ] Enforce pre-commit quality gate (same commands as CI) via git hooks



## 12. Polishing & Release

- [ ] App icon & splash
- [ ] Offline smoke test
- [ ] Build Windows, Linux, Android artifacts
- [ ] Tag `v0.0.1`
- [ ] Backup/Export feature: export all data to `.ics` or `.json`; import prompt when ConnectionScreen runs

### OAuth & Authentication
- [ ] Implement Google OAuth flow with `google_sign_in` (desktop & Android supported)
- [ ] Store and refresh access / refresh tokens securely via `flutter_secure_storage`
- [ ] Handle token expiration automatically in `CaldavService`
- [ ] Provide sign-out function that clears tokens and returns to ConnectionScreen

### Optional Notifications (post-v0 flag)
- [ ] Integrate `flutter_local_notifications`
- [ ] Schedule local reminder when task has a due date
- [ ] Allow enabling/disabling notifications in Settings

## 13. Versioning & Changelog
- [ ] Adopt Semantic Versioning (`vMAJOR.MINOR.PATCH`)
- [ ] Maintain `CHANGELOG.md` updated in each merge request
- [ ] Tag versions in git; GitHub Actions auto-creates release notes from changelog

## 14. Crash Reporting (Optional)
- [ ] Integrate Sentry or Firebase Crashlytics for production builds
- [ ] Provide Settings toggle to enable/disable crash collection

---

### Done?  Run the checklist again and ensure 100 % of boxes are checked before release.
