# FlowIt Architecture Overview

## 1. Project Overview

FlowIt is a cross-platform application (desktop on Windows/Linux, and mobile on Android) built with Flutter. Its primary purpose is to help users manage tasks, projects, groups, and "flows" in an offline-first manner, while synchronizing data to a CalDAV server (using VTODO objects). FlowIt extends the standard iCalendar VTODO format with extra x-flowit-* properties to handle advanced workflows, forms, and automations.

## 2. Key Principles

### Offline-First
- **Local storage (key-value) is the source of truth**, ensuring reliable usage even when offline
- Local key-value database persists tasks for usage without network connectivity
- Background sync process reconciles with CalDAV server

### Optimistic UI
- **The app updates immediately on user actions**, then synchronizes changes in the background
- Upon user action, local store is updated immediately
- Background sync process handles server reconciliation
- Conflicts use "last-updated wins" strategy or partial merges when feasible

### Minimal Dependencies
- **Rely primarily on Flutter's Material widgets and standard libraries** to keep the code base maintainable
- Use default Material widget set for UI, avoiding large external packages unless crucial
- Focus on Flutter's built-in capabilities

### Adaptive UX
- **A single codebase supports both desktop and mobile layouts**
- Desktop: Persistent sidebars for navigation
- Mobile: Slide-out navigation drawers
- Follows Flutter's adaptive guidelines and best practices

### Interoperability
- **Standard iCalendar fields** let FlowIt integrate with any CalDAV-compliant server or client
- **Custom fields (x-flowit-*)** enable advanced features within FlowIt
- Full RFC 5545 compliance for standard fields

## 3. Project Goals & Roadmap

### Version 0 (v0) - Current Focus

#### CalDAV Integration
- Read/write VTODO objects on a CalDAV server
- Two-way sync (local ↔ remote)
- Basic conflict resolution (last-modified wins)
- **Server Capability Discovery:**
  - Protocol Support Detection (CalDAV, CardDAV, WebDAV)
  - Collection Creation Permissions
  - Calendar Component Support (VEVENT, VTODO, etc.)
  - Address Book Availability
  - WebDAV File Storage
  - Notification Support
  - Calendar Sharing Capabilities

#### Task Structure
- Each item is stored as a VTODO
- Task: A single actionable item

#### Notion-Like Editor
- DESCRIPTION in VTODO supports Markdown
- Potential slash commands, bullet lists, etc. for improved user experience

#### Basic Validators
- Mark tasks as complete with a simple checkbox if no validators are configured
- Or by completing all configured validators

#### Task Views
- **"Today"**: tasks with imminent due dates
- **"Soon"**: tasks with upcoming due dates
- **"Unregistered"**: tasks without due dates or no assigned project

#### Adaptive Layout
- **Desktop**: A sidebar for navigation (projects, groups, tasks), main content area
- **Mobile**: A slide-out drawer replaces the persistent sidebar, main screen focuses on current content

### Version 1 (v1) - Future Goals

#### Attendees & File Attachments
- Use ATTENDEE and ATTACH in VTODO for collaboration

#### Kanban & Calendar Views
- Projects can be displayed in board (kanban) or calendar format

#### Flows
- x-flowit-type: flow to represent processes with an ordered sequence of tasks

#### Task Requirements & Advanced Validators
- x-flowit-validator can store multiple validation requirements including checklists, single selects, and free fields
- x-flowit-requirement references tasks/data that must be completed before a task can be finished
- "Success/Fail" states if needed

#### Automation
- x-flowit-automate describes triggers, schedules, or webhooks for tasks of type automated-task

## 4. Architecture Patterns

### Flutter State Management
- FlowIt uses Provider/Riverpod for maintaining global or modular state
- The chosen approach handles local data, sync statuses, and push/pull logic for CalDAV
- Separation of concerns between UI and business logic

### Project Structure
- **Services**: CalDAV, conflict resolution, sync
- **Models**: project, task, group, flow
- **Data**: local storage repositories
- **UI**: screens, widgets, theming

### Sync Flow Architecture
1. **Local Edit**: user action updates local store immediately
2. **Background Sync**: changes are batched or queued to push to CalDAV
3. **Server Response**: new data is pulled from CalDAV
4. **Merge**: if conflicts appear, apply last-updated logic or partial merges
5. **Local Store Update**: finalize the synced item's state locally

### Error Handling Strategy
- **Offline-first resilience**: App remains functional without network
- **Optimistic updates**: UI responds immediately, sync handles conflicts later
- **Graceful degradation**: Features degrade gracefully when server features unavailable
- **Non-blocking sync**: Sync failures don't prevent core functionality

## 5. Technical Standards

### CalDAV Compliance
- Full RFC 5545 iCalendar compliance for standard fields
- RFC 4918 WebDAV properties for custom metadata
- Standard VTODO object structure with extensions

### Data Storage
- Local key-value database (Hive/Sembast) as primary data store
- JSON serialization for complex FlowIt-specific data
- Conflict resolution based on LAST-MODIFIED timestamps

### UI Framework
- Material Design 3 compliance
- Responsive design patterns
- Accessibility support
- Cross-platform consistency

## 6. Security & Privacy

### Data Protection
- Local storage encryption for sensitive data
- Secure credential storage for CalDAV authentication
- No data collection beyond necessary sync operations

### Server Communication
- HTTPS-only communication with CalDAV servers
- Standard authentication mechanisms (Basic Auth, OAuth, etc.)
- Certificate validation and pinning where appropriate

## 7. Performance Considerations

### Offline Performance
- Local database optimized for fast queries
- Minimal UI blocking during sync operations
- Background processing for heavy operations

### Sync Efficiency
- Incremental sync based on modification timestamps
- Batched operations to reduce server requests
- Smart conflict resolution to minimize data loss

### UI Responsiveness
- Immediate UI updates with optimistic state changes
- Background sync queue management
- Progressive loading for large datasets

## 8. Extensibility

### Plugin Architecture
- x-flowit-* extensions allow new features without breaking compatibility
- JSON schema validation for extension data
- Forward/backward compatibility considerations

### Third-Party Integration
- Standard CalDAV ensures compatibility with external tools
- Export/import capabilities for data portability
- API design allows future integration possibilities

---
*Documentation generated from FlowIt Project Specifications*
*Last updated: 2024-12-19* 