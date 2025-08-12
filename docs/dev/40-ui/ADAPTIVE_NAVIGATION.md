# Adaptive Navigation

Sources: `lib/presentation/widgets/adaptive_app_layout.dart`, `lib/app.dart`

Behavior
- Breakpoint: 800 px.
- Desktop: permanent sidebar (280 px), main content area; user account badge at top of sidebar.
- Mobile: drawer navigation; drawer auto-opens on first load then closes on selection.

Destinations (enum `AppDestination`)
- `today` → `/today`
- `soon` → `/soon`
- `anytime` → `/anytime`
- `projects` → `/projects`
- `workflows` → `/workflows`

Routes
- Inside shell (`AdaptiveAppLayout`):
  - `/` (home shell)
  - `/today`, `/soon`, `/next-week`, `/later`, `/anytime`
  - `/projects`, `/workflows`
  - `/project/:path`, `/workflow/:path` (URL-encoded calendar/workflow path)
  - `/settings`
- Outside shell: `/connect`
- Initial location: `/projects`

Notes
- There is no `/task/:uid` route. Task details are shown within screens.
