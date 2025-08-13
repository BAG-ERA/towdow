# Routes Reference

Source of truth: `lib/app.dart`

InitialLocation
- `/projects`

Shell (AdaptiveAppLayout)
- `/` → `_AppShell`
- `/today` → `_TaskViewShell(initialTab: 0)`
- `/soon` → `_TaskViewShell(initialTab: 1)`
- `/next-week` → `_TaskViewShell(initialTab: 2)`
- `/later` → `_TaskViewShell(initialTab: 3)`
- `/anytime` → `_TaskViewShell(initialTab: 4)`
- `/projects` → `ProjectsListScreen`
- `/workflows` → `WorkflowListScreen`
- `/project/:path` → `ProjectDetailScreen` (path URL-decoded)
- `/workflow/:path` → `WorkflowDetailScreen` (path URL-decoded)
- `/settings` → `SettingsScreen`

Outside shell
- `/connect` → `ConnectionScreen`

Mapping to AppDestination
- today → `/today`
- soon → `/soon`
- anytime → `/anytime`
- projects → `/projects`
- workflows → `/workflows`
