## FlowIt Developer Documentation

### 🎯 Top-level goals and rationale
- **Simple UX**: Fewer concepts, predictable navigation, consistent components. Reduces cognitive load and bugs.
- **Offline-first**: Local key‑value storage is the **source of truth**; actions apply immediately with background sync for reliability and responsiveness.
- **CalDAV-first**: Stay compliant with RFC 4791/5545. **Extend sparingly** via `x-flowit-*` so standard clients keep working.
- **MVVM**: Views are dumb; ViewModels orchestrate repositories/services. Keeps widgets simple and testable.
- **Minimal deps**: Prefer Flutter Material and the standard library for maintainability.

### 🧭 How to navigate this doc set
- **Architecture**: `10-architecture/`
- **Data layer**: `20-data-layer/`
- **Sync & lifecycle**: `30-sync/`
- **UI & adaptive nav**: `40-ui/`
- **Routing reference**: `50-routing/`
- **Feature guides**: `60-features/`
- **Guidelines**: `70-guidelines/`
- **Testing**: `80-testing/`
- **References (machine-readable)**: `98-references/`

### 🏗️ Architecture at a glance
- **Pattern**: MVVM + Commands, unidirectional data flow
- **Data layer**: Repository (source of truth) + Service (business logic / integrations)
- **State**: Riverpod providers (`lib/data/providers/providers.dart`)
- **Errors**: `Result<T>` (`lib/core/result.dart`), avoid throws across layers
- **Logging**: `AppLogger` (`lib/core/logger.dart`)

### 📜 Protocol stance
- **Standard first**: Prefer standard iCalendar/CalDAV fields and flows.
- **Extensions when needed**: `x-flowit-*` are valid JSON strings; never `null` (use `{}`/`[]`).
- **Project metadata at VCALENDAR**: e.g., kanban/domain; **task metadata at VTODO**.

### 📂 `lib/` quick tour

| Area | What lives here | Read next |
|------|------------------|-----------|
| `lib/app.dart` | Router, shell, adaptive layout wiring | `40-ui/ADAPTIVE_NAVIGATION.md`, `50-routing/ROUTES_REFERENCE.md` |
| `lib/main.dart` | Bootstrap, theme extensions | — |
| `lib/core/` | `logger.dart`, `result.dart`, `app_lifecycle_manager.dart` | `30-sync/LIFECYCLE_MANAGER.md` |
| `lib/data/models/` | Immutable entities (Freezed/Hive), VCALENDAR/VTODO mapping | `98-references/VCALENDAR_SCHEMA.json` |
| `lib/data/repositories/` | Data access (local/remote coordination) | `10-architecture/OVERVIEW.md` |
| `lib/data/services/` | Business logic: `caldav/`, `sync/`, domain/kanban/user/share | `30-sync/*`, `60-features/*` |
| `lib/presentation/` | Views, widgets, ViewModels, commands | `10-architecture/OVERVIEW.md` |

### 🔗 Machine-readable references
- **Schemas**: `98-references/VALIDATOR_SCHEMA.json`, `98-references/VCALENDAR_SCHEMA.json`
- **Routes map**: `50-routing/routes.json`

### ✅ Conventions
- **Use exact identifiers and paths** (e.g., `lib/app.dart`, `AppDestination.today`).
- **Prefer links over duplication**; keep docs short and code-linked.
- **English only** in `cocs/dev/`.

### 📌 Keep in sync
- PRs that change routes, lifecycle, or schemas must update the matching docs and JSON under `cocs/dev/`.


