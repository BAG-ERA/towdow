# App Lifecycle Manager

Source: `lib/core/app_lifecycle_manager.dart`

Responsibilities
- Initialize core services (SyncService, CalDAVMonitor, ExternalCalendarSyncService, FileUploadQueueService, ConnectionMonitorService, UserSyncService, AccountRepository).
- Start ExternalCalendarSyncService regardless of account.
- Start main sync stack only if there is an active non-localhost account.
- Maintain state transitions: initial → initializing → ready → backgrounded → resumed → error.
- On resume: ensure services running, trigger `syncAllActiveCaldav`, update shared projects.
- On connection restored: process upload queue and process sync queue only.

Notes
- Background operation continues when UI is minimized.
- Health checks will (re)start external sync and CalDAV monitor if needed.
