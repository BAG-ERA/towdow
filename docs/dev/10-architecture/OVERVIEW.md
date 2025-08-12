# Architecture Overview

- Codebase style: MVVM with Riverpod providers, Repository + Service data-layer, immutable models.
- Principles: Offline-first, Optimistic UI, Minimal dependencies, Adaptive UX.

Layers
- UI: Views (widgets) + ViewModels (state/commands). Views remain dumb; logic lives in ViewModels.
- Data: Repositories expose app data; Services implement business logic (CalDAV, Domain, Kanban, User, Share, Sync).
- Models: Immutable data (Freezed/Hive where applicable).

State management
- Riverpod providers are defined in `lib/data/providers/providers.dart` and feature-specific providers under `presentation/providers/`.

Commands
- User events map to commands (e.g., validator and task command classes under `presentation/viewmodels/commands/`).

Error handling
- Use `Result<T>` (see `lib/core/result.dart`). Do not throw across boundaries.

Logging
- Use `AppLogger` (see `lib/core/logger.dart`). No prints.

Source pointers
- Router and shell: `lib/app.dart`
- Lifecycle: `lib/core/app_lifecycle_manager.dart`
- CalDAV + Sync: `lib/data/services/caldav/`, `lib/data/services/sync/`
