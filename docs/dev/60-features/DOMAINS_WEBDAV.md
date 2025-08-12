# Domains via WebDAV

Sources: `lib/data/services/domain_service.dart`, CalDAV property operations handled by sync layer.

Model field (VCALENDAR level)
- `X-FLOWIT-DOMAIN` is stored as a string on calendar collections (WebDAV property), mapped to `TaskCalendar.flowitDomain`.

Flow
- Assign/remove domain:
  1) Load calendar from `CalendarRepository`.
  2) Save locally with `withDomain()` / `withoutDomain()`.
  3) Queue calendar update: `SyncService.queueCalendarUpdate(calendar.path)`.
  4) Sync layer issues the PROPPATCH to set/remove the property.

Notes
- Local-first (optimistic) then background sync.
- Domain lists combine values from calendars and standalone storage (see `DomainService.getAvailableDomains`).
