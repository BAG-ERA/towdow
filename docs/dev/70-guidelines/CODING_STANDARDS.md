# Coding Standards

- MVVM separation: no business logic in widgets; use ViewModels and Commands.
- Data layer: repositories (source of truth) and services (business logic). No UI dependencies.
- State: Riverpod; keep providers in `lib/data/providers/providers.dart` unless feature-specific.
- Errors: use `Result<T>`; no thrown exceptions across layers.
- Logging: use `AppLogger` with appropriate levels; never use `print`.
- Naming: descriptive, full words, explicit intents.
- Formatting: match existing style; avoid deep nesting; early returns.
