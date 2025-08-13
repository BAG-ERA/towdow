# Testing Strategy

- Unit tests: services, repositories, and viewmodels. Use fakes/mocks.
- Widget tests: views and routing; verify adaptive layout and DI wiring.
- Integration tests: sync flows with mocked/live CalDAV where feasible; offline/online transitions.

Focus areas
- Sync queue behaviors (processQueueOnly, retries).
- CalDAV monitor interval adjustments.
- Domain property updates (local save + queued server update).
