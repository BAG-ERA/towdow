---
description: Junie MVVM Guidelines for TowDow Flutter project (inspired by Cursor rules)
globs:
  - "**/*.dart"
  - "**/*.md"
alwaysApply: true
---
Purpose
- Provide clear, enforceable guidance for Junie when editing this repository.
- Mirror the architectural intent of .cursor/rules/mvvm.mdc while adapting to Junie’s tooling, workflow and constraints described in the project assistant environment.

Global principles
- Separation of Concerns: Keep data and UI layers clearly separated. UI shows state and forwards user intent; business logic resides in ViewModels, Repositories, and Services.
- MVVM in Flutter:
  - Views (Widgets/Screens): Stateless regarding business logic. Contain only trivial UI logic: simple conditionals for visibility, layout and routing, animation logic as needed.
  - ViewModels: Expose immutable view state and Commands; own UI/business logic; notify listeners for UI updates.
  - Data Layer: Repositories (source of truth) + Services (external I/O such as WebDAV/HTTP/storage).
- Unidirectional Data Flow: Inputs -> Commands -> ViewModel -> State -> View.
- Immutability: Prefer immutable data models (freezed / built_value). Avoid mutable shared state.
- Dependency Injection: Use provider for wiring dependencies. Avoid global singletons.

Naming and structure
- Class naming: HomeViewModel, HomeScreen, UserRepository, ClientApiService, etc. Avoid names colliding with Flutter SDK types.
- File layout: Layer-first structure (data/, domain/, presentation/). Keep gigantic files split; if a widget exceeds ~600 lines, refactor into smaller widgets.
- Abstract repositories: Define abstract interfaces and multiple implementations if needed (e.g., dev/staging).
- Logging: Use the project’s logging utilities. Messages should include context (class/method) and be informative.
- File headers: Start each file with a brief description of its purpose.

Events and commands
- Handle user interactions via Command objects/methods on ViewModels. Views should not mutate models directly.
- Use ChangeNotifier/ValueListenable for View-to-ViewModel updates. Widgets subscribe to ViewModel changes, never vice versa.

Data handling
- Offline-first: Local storage is the source of truth when offline; sync services reconcile with remote (CalDAV/WebDAV). Ensure resilient behavior without network.
- Optimistic UI: Reflect user actions immediately, then sync; on failure, reconcile and notify the user appropriately.
- Persistence: Prefer key–value stores for app/config data where appropriate.
- Non-standard VTODO tolerance: Services and sync logic must accept and correct malformed VTODOs (e.g., missing x-flowit-type). Default to a generic task with default validator and no project when fields are missing, then resync corrected entries.

Testing
- Unit tests: Cover ViewModels, Services, and Repositories. Test individual methods’ logic.
- Widget tests: Cover Views, routing, and dependency injection wiring.
- Fakes: Provide fake implementations for repositories/services to enable deterministic tests.
- Run the tests with: flutter test

Codebase rules
- Minimal dependencies: Prefer Flutter Material and stdlib; avoid unnecessary packages.
- Result-based error handling: Where suitable, use Result-style objects instead of throwing; log and surface actionable info.
- Never hardcode production secrets or environment-specific constants. Use configuration and DI.
- Ignore lib.old errors; it’s reference code and not part of the build.
- Cross-platform UX: Design adaptively for mobile and desktop (sidebars on desktop, slide-out on mobile) per Flutter guidance.
- Interoperability: Use standard iCalendar fields for CalDAV compatibility; x-flowit-* for advanced features.

Junie-specific operating guidance
- Make minimal, surgical changes to satisfy an issue. Prefer additive edits (new small functions, isolated fixes) over broad refactors.
- Keep users informed using <UPDATE> tags per the assistant workflow. Always include plan progress marks (✓, *, !).
- Use specialized repo tools (search_project, get_file_structure, open) before broad operations. Avoid cat/echo for file edits; use the provided create/search_replace tools.
- Do not create files outside the repository. Place new guidelines under .junie/rules/.
- When editing, respect analysis_options.yaml and existing patterns. Keep lint compliance.
- For long files (>600 lines), consider extracting helpers if you must modify logic to reduce risk, but prioritize minimal change to fix the issue.
- Prefer composing with existing services/repositories; don’t introduce new global state.
- When adding logs, use the project’s AppLogger with appropriate levels (debug/info/warning/error) and context.
- Write or run targeted tests when feasible; use integration tests present in test/ to validate sync-critical paths.

How Junie should interpret conflicts
- If .cursor rules and these Junie rules conflict, follow these Junie rules when acting through this assistant.
- If repository code conventions contradict generic advice, favor repository-specific conventions.

Placement and application
- This file intentionally mirrors .cursor/rules/mvvm.mdc content and intent, adapted for Junie. Keep alwaysApply: true.
