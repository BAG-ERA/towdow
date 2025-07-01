FlowIt Project Specifications
1. Overview

FlowIt is a cross-platform application (desktop on Windows/Linux, and mobile on Android) built with Flutter. Its primary purpose is to help users manage tasks, projects, groups, and "flows" in an offline-first manner, while synchronizing data to a CalDAV server (using VTODO objects). FlowIt extends the standard iCalendar VTODO format with extra x-flowit-* properties to handle advanced workflows, forms, and automations.

Key Principles:

    Offline-First: Local storage (key-value) is the source of truth, ensuring reliable usage even when offline.
    Optimistic UI: The app updates immediately on user actions, then synchronizes changes in the background.
    Minimal Dependencies: Rely primarily on Flutter's Material widgets and standard libraries to keep the code base maintainable.
    Adaptive UX: A single codebase supports both desktop (with persistent sidebars) and mobile (with slide-out navigation) layouts, following Flutter's adaptive guidelines and best practices described in Extreme UI Adaptability in Flutter.
    Interoperability: Standard iCalendar fields let FlowIt integrate with any CalDAV-compliant server or client; custom fields (x-flowit-*) enable advanced features within FlowIt.

2. Project Goals & Roadmap
2.1 Version 0 (v0)

    CalDAV Integration
        Read/write VTODO objects on a CalDAV server.
        Two-way sync (local ↔ remote).
        Basic conflict resolution (last-modified wins).
        Server Capability Discovery:
            - Protocol Support Detection (CalDAV, CardDAV, WebDAV)
            - Collection Creation Permissions
            - Calendar Component Support (VEVENT, VTODO, etc.)
            - Address Book Availability
            - WebDAV File Storage
            - Notification Support
            - Calendar Sharing Capabilities

    Task/ Structure
        Each item is stored as a VTODO.
        Task: A single actionable item.

    Notion-Like Editor
        DESCRIPTION in VTODO supports Markdown.
        Potential slash commands, bullet lists, etc. for improved user experience.

    Basic Validators
        Mark tasks as complete with a simple checkbox if no validators are configured, or by completing all configured validators.

    Task Views
        "Today": tasks with imminent due dates.
        "Soon": tasks with upcoming due dates.
        "Unregistered": tasks without due dates or no assigned project.

    Adaptive Layout
        Desktop: A sidebar for navigation (projects, groups, tasks), main content area.
        Mobile: A slide-out drawer replaces the persistent sidebar, main screen focuses on the current content.

2.2 Version 1 (v1)

    Attendees & File Attachments
        Use ATTENDEE and ATTACH in VTODO for collaboration.

    Kanban & Calendar Views
        Projects can be displayed in board (kanban) or calendar format.

    Flows
        x-flowit-type: flow to represent processes with an ordered sequence of tasks.

    Task Requirements & Advanced Validators
        x-flowit-validator can store multiple validation requirements including checklists, single selects, and free fields.
        x-flowit-requirement references tasks/data that must be completed before a task can be finished.
        "Success/Fail" states if needed.

    Automation
        x-flowit-automate describes triggers, schedules, or webhooks for tasks of type automated-task.

3. Architecture & Design Patterns

    Offline-First
        A local key-value database (e.g., Hive or Sembast) persists tasks, ensuring usage without network connectivity.

    Optimistic State Updates
        Upon user action, the local store is updated immediately.
        A background sync process reconciles with the CalDAV server.
        Conflicts use a "last-updated wins" strategy or partial merges when feasible.

    Flutter State Management
        FlowIt can use Provider, Riverpod, or BloC to maintain a global or modular state.
        The chosen approach must easily handle local data, sync statuses, and push/pull logic for CalDAV.

    Minimal Dependencies
        Use the default Material widget set for UI, avoiding large external packages unless crucial.

    Structure
        Services (CalDAV, conflict resolution, sync).
        Models (project, task, group, flow).
        Data (local storage).
        UI (screens, widgets, theming).

4. UI Guidelines & Adaptivity

    Material Design
        Use Flutter's Material components (AppBar, NavigationDrawer, FloatingActionButton, etc.).
        Maintain consistent color schemes, typography, and shape theming via a shared ThemeData.

    Responsive Layout
        Desktop: A left sidebar for navigation, a main panel for content (tasks, editor, etc.).
        Mobile: A single column layout with a top app bar or bottom navigation; the sidebar becomes a slide-out drawer.

    Notion-Like Editor
        Provide a rich text area that supports Markdown.
        Potentially integrate slash commands to insert special blocks or references.
        All final text is stored in the DESCRIPTION field.

    Project & Task Views
        "Today" and "Soon" lists highlight tasks by due date.
        "Unregistered" shows tasks missing a project or due date.
        A "Project Detail" screen lets users see tasks, groups, and sub-items.
        Future: Kanban boards or calendar grids, especially for larger screens.

5. Data Model & CalDAV Integration
5.1 Standard iCalendar Fields

Each item is a VTODO with these required or optional fields:

    UID (required)
    SUMMARY (required)
    DESCRIPTION (required, can contain Markdown)
    STATUS (optional, e.g., NEEDS-ACTION, COMPLETED, CANCELLED)
    DUE (optional)
    LAST-MODIFIED (required for sync/conflict resolution)
    DTSTAMP (required by iCalendar)
    ATTENDEE (optional, detailed in Section 5.1.1)
    CATEGORIES (optional)
    ATTACH (optional)
    ORGANIZER (optional)

5.1.1 ATTENDEE Structure (RFC 5545 Compliant)

FlowIt implements full RFC 5545 ATTENDEE support for collaboration. Each ATTENDEE represents a participant in a task or project.

Required Properties:
- EMAIL: The attendee's email address (URI format, e.g., mailto:user@domain.com)

Optional Properties:
- CN (Common Name): Display name for the attendee
- PARTSTAT (Participation Status): Current response status
  - NEEDS-ACTION (default): No response yet ("Pas encore répondu")
  - ACCEPTED: Attendee has accepted ("Accepté")
  - DECLINED: Attendee has declined ("Refusé")
  - TENTATIVE: Attendee is tentatively available ("Disponible si besoin")
  - DELEGATED: Attendee has delegated to someone else ("Délégué")
- ROLE: Attendee's role in the task
  - REQ-PARTICIPANT (default): Required participant ("Participant requis")
  - OPT-PARTICIPANT: Optional participant ("Participant optionnel")
  - NON-PARTICIPANT: Observer only ("Observateur")
  - CHAIR: Meeting/task chair/leader ("Responsable")
- CUTYPE (Calendar User Type): Type of attendee
  - INDIVIDUAL (default): Person
  - GROUP: Group or distribution list
  - RESOURCE: Equipment or facility
  - ROOM: Meeting room
  - UNKNOWN: Unknown type
- RSVP: Whether response is requested (true/false, default: false)
- DELEGATED-FROM: Email of person who delegated this task
- DELEGATED-TO: Email of person this task was delegated to
- SCHEDULE-AGENT: Scheduling responsibility
- MEMBER: Group membership information

Email Validation Policy:
FlowIt performs basic email format validation but does not block malformed emails. If an email is missing or malformed, the user receives a warning popup stating that "this attendee may never receive notifications through email" but can proceed with the addition. This ensures flexibility while informing users of potential delivery issues.

Example ATTENDEE entries:
```
ATTENDEE;CN=John Doe;PARTSTAT=ACCEPTED;ROLE=REQ-PARTICIPANT:mailto:john@example.com
ATTENDEE;CN=Jane Smith;PARTSTAT=TENTATIVE;ROLE=CHAIR:mailto:jane@company.com
ATTENDEE;CUTYPE=RESOURCE;CN=Conference Room A:mailto:room-a@facilities.com
```

5.2 Conflict Resolution

    LAST-MODIFIED is the key to detecting concurrency issues.
    If server and local versions both changed, FlowIt compares timestamps to decide which version wins or tries a field-by-field merge if possible.

5.3 Sync Flow

    Local Edit: user action updates local store immediately.
    Background Sync: changes are batched or queued to push to CalDAV.
    Server Response: new data is pulled from CalDAV.
    Merge: if conflicts appear, apply last-updated logic or partial merges.
    Local Store Update: finalize the synced item's state locally.

6. FlowIt-Specific iCalendar Extensions

FlowIt uses non-standard iCalendar properties to store advanced workflow data in each VTODO. These are prefixed with x-flowit-. They allow hierarchical tasks, templates, flows, advanced validators, and more.

All these fields store JSON or string values.

    If storing JSON, it must be valid (no null for empties; use {} or []).
    If a field is not relevant, it may be an empty object ({}) or omitted if permissible.

6.1 x-flowit-type (Required)

    Defines how FlowIt interprets the VTODO.
    Allowed Values:
        task
        automated-task
        
    ⚠️ **DEPRECATED**: project (migrated to VCALENDAR level)

6.2 x-flowit-validator (Required, can be empty {})

    A JSON describing how a task is completed/validated.
    Schema detailed in Section 7.
    {"type":"default"} for simple "mark complete," or {"type":"form","form":[...questions...]} for a user form.

6.3 x-flowit-requirement (Required, can be {})

    JSON specifying prerequisites or resources.
    Example: {"requires":["UID_of_another_task"]}

6.4 x-flowit-template (Required)

    A UID pointing to a "template" VTODO for this item.
    Allows FlowIt to replicate consistent fields, forms, or structures across tasks.

6.5 x-flowit-process (Required)

    A UID referencing the overarching "flow" (another VTODO where x-flowit-type = flow).
    Ties the current task to a parent flow or process pipeline.

6.6 x-flowit-reversaltask (Optional)

    A UID referencing a "reversal" or "undo" task.
    If the current task triggers irreversible changes, the reversal task is how to revert it.
    This field is optional for all task types (task, step, automated-task).

6.7 x-flowit-automate (Conditionally Required)

    A JSON object describing automation triggers, schedules, or scripts.
    Required only if x-flowit-type = automated-task.
    Example: {"trigger":"webhook","endpoint":"https://example.com/flowit/hook"}

6.8 x-flowit-context (Conditionally Required)

    A JSON object with extra context for task types.
    Could store priority, environment info, or project-specific metadata.
    If x-flowit-type = task, include it (even if {}).
    Example: {"priority":"high","department":"finance"}

6.9 x-flowit-kanban (VCALENDAR level only)

    ⚠️ **MOVED TO VCALENDAR LEVEL**: This property is now X-FLOWIT-KANBAN at the calendar level, not in individual VTODO objects.
    A JSON array of kanban board definitions for the project.
    Only applies to calendars with X-FLOWIT-TYPE:PROJECT.
    Example: [{"UID":"AAAAA-BBBB","title":"Kanban board 1","columns":["Easy","Medium","Hard"]},{"UID":"AAAAA-BCBBB","title":"Kanban board 2","columns":["ColA","ColB"]}]

6.10 x-flowit-kanban-column (Conditionally Required)

    A JSON object with a list of kanban columns. Only for tasks
    Could store priority, environment info, or project-specific metadata.
    If x-flowit-type = task, include it (even if {}).
    Example: [{"uid":"AAAAA-BBBB","columns":["Easy","Medium","Hard"]}]

6.11 x-flowit-asflow (VCALENDAR level only)

    ⚠️ **MOVED TO VCALENDAR LEVEL**: This property is now X-FLOWIT-ASFLOW at the calendar level.
    Only for calendars with X-FLOWIT-TYPE:PROJECT.
    If missing, default to FALSE.
    Indicates whether the calendar represents a flow container.

7. FlowIt Types

FlowIt supports several types of items, each with specific properties and relationships. All types are stored as VTODO objects with different x-flowit-type values.

7.1 Calendar / Project (VCALENDAR level)

> ⚠️ **DEPRECATION NOTICE** – FlowIt no longer stores a dedicated VTODO object of type `project`.  A CalDAV calendar **is** the project in the user-experience.  Legacy VTODO items with `x-flowit-type: project` SHOULD NOT be created anymore and MUST be migrated to a calendar-level representation during the first sync.

Required Properties (VCALENDAR)
- UID – globally unique calendar identifier (if the server does not expose one, FlowIt generates a stable UUID)
- DTSTAMP – creation timestamp
- CREATED – creation timestamp from the client perspective
- LAST-MODIFIED – last update timestamp
- SUMMARY – project name (display name)
- STATUS – calendar/project status (NEEDS-ACTION, COMPLETED, etc.)
- PERCENT-COMPLETE – overall completion (0–100)
- X-FLOWIT-TYPE: PROJECT – FlowIt marker identifying this calendar as a project
- X-FLOWIT-ASFLOW: FALSE – indicates the calendar is not a "flow" container
- X-FLOWIT-KANBAN – JSON array of kanban states (may be empty)
- X-FLOWIT-OWNER – identifier or email of the owner (if ORGANIZER not used)
- X-FLOWIT-DOMAIN – domain name for grouping projects (WebDAV property on calendar collections, acts as folder organization)
- GETETAG – server-managed ETag, preserved for caching & sync
- CALENDAR-ORDER – integer used for UX ordering
- ORGANIZER – CalDAV/email address of the responsible person
- ATTENDEE – optional collaborators

Optional Properties
- DESCRIPTION – project description (Markdown allowed)
- CATEGORIES – tags to classify the project
- X-FLOWIT-TEMPLATE – UID if the project is based on a template

All other FlowIt-specific extensions (validator, requirement, automate…) remain VTODO-level only.

7.2 Domain Organization (X-FLOWIT-DOMAIN)

Domains provide a hierarchical organization system for projects, acting as folders to group related calendars/projects together.

**Purpose:**
- Group related projects under a common domain name
- Provide visual organization in the UI (folder-like structure)
- Enable bulk operations on projects within the same domain
- Support hierarchical project navigation

**Technical Implementation:**
- **Protocol**: WebDAV property on calendar collections (RFC 4918 PROPPATCH/PROPFIND)
- **Namespace**: `http://flowit.app/ns/` (usually aliased as `FLOWIT:` or dynamic like `ns3:`)
- **Location**: Calendar collection level (not VCALENDAR or VTODO objects)
- **Cardinality**: 0..1 per calendar (optional, maximum one domain per project)
- **Format**: String value representing the domain name
- **Case Sensitivity**: Case-insensitive for display purposes, case-preserving for storage
- **Validation**: Must be a non-empty string if provided, no special character restrictions

**CalDAV Operations:**
- **Discovery**: Retrieved via PROPFIND requests on calendar collections
- **Updates**: Modified via PROPPATCH requests to set/remove the domain property
- **Server Response**: Returns in multistatus XML as `<ns:domain>value</ns:domain>`

**Behavior:**
- If X-FLOWIT-DOMAIN is missing or empty, the project appears in the "No Domain" section
- Projects with the same domain value are grouped together in the UI
- Domain names are user-defined and can be created dynamically when assigning projects
- Domains have no hierarchical nesting (flat structure only)
- Changing a project's domain immediately triggers a PROPPATCH request to update the server

**UI Implications:**
- Projects are visually grouped by domain in navigation sidebars
- Domain folders can be collapsed/expanded to show/hide contained projects
- Domain creation happens through project editing or during project creation
- Bulk domain assignment operations are available for multiple projects

**Migration Considerations:**
- Existing projects without X-FLOWIT-DOMAIN are treated as having no domain
- No data migration is required - the feature is additive
- Legacy CalDAV clients ignore custom WebDAV properties automatically

**PROPPATCH Example:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<D:propertyupdate xmlns:D="DAV:" xmlns:FLOWIT="http://flowit.app/ns/">
  <D:set>
    <D:prop>
      <FLOWIT:domain>Marketing Campaigns</FLOWIT:domain>
    </D:prop>
  </D:set>
</D:propertyupdate>
```

**PROPFIND Response Example:**
```xml
<D:multistatus xmlns:D="DAV:" xmlns:ns3="http://flowit.app/ns/">
  <D:response>
    <D:href>/calendars/user/project-calendar/</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>Marketing Campaign Q1</D:displayname>
        <ns3:domain>Marketing Campaigns</ns3:domain>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
```

7.3 Domain Management

**Domain Lifecycle:**
- Domains are created implicitly when first assigned to a project
- Domains persist as WebDAV properties on calendar collections
- Domain names can be renamed by updating the WebDAV property via PROPPATCH
- Domain removal is achieved by sending a PROPPATCH request to remove the property

**Synchronization:**
- Domain information is discovered during calendar collection PROPFIND operations
- Changes to domain assignments trigger immediate PROPPATCH requests to update the server
- Domain properties are included in standard CalDAV discovery and sync workflows
- No separate sync mechanism is required - domains sync as part of calendar metadata

7.4 Task (x-flowit-type: task)

A single actionable item.

Required Properties:
- Standard VTODO fields:
  - UID (required)
  - DTSTAMP (required)
  - LAST-MODIFIED (required)
  - SUMMARY (required)
  - DESCRIPTION (required, can be empty)
  - STATUS (required, default: NEEDS-ACTION)
- x-flowit-type: "task" (required)
- x-flowit-process: UID of parent project/flow (required)
- x-flowit-validator: [[...]] (required, can be empty array for simple checkbox completion)
- x-flowit-requirement: {"requires":["step-1234-5678-ef00-3333"]} (required)

Optional Properties:
- x-flowit-template (optional)
- x-flowit-reversaltask (optional)
- DUE
- CATEGORIES (optional)
- ATTENDEE (optional)
- x-flowit-process (optional, UID of parent project or flow)

Relationships:
- Can be part of a project or flow
- Can be part of a kanban board
- When created in a flow context, should establish a sibling relationship with the corresponding step

7.5 Automated Task (x-flowit-type: automated-task)

A task that runs automatically based on triggers or schedules.

Required Properties:
- Standard VTODO fields:
  - UID (required)
  - DTSTAMP (required)
  - LAST-MODIFIED (required)
  - SUMMARY (required)
  - DESCRIPTION (required, can be empty)
  - STATUS (required, default: NEEDS-ACTION)
  - PERCENT-COMPLETE (required, default: 0)
- x-flowit-type: "automated-task" (required)
- x-flowit-validator: [] (required, typically empty for automated tasks)
- x-flowit-requirement: {} (required, can be empty)
- x-flowit-automate: {} (required, describes automation triggers)
- x-flowit-context: {} (required, can be empty object)

Optional Properties:
- CATEGORIES (optional)
- ATTENDEE (optional)
- x-flowit-process (optional, UID of parent project or flow)

Relationships:
- Can be part of a project or flow
- Can reference other tasks via x-flowit-requirement

7.6 Type Conversion Rules

- Tasks can be converted to automated tasks and vice versa
- Type changes preserve all relevant properties
- Type-specific properties are removed when converting to an incompatible type

7.7 Complete VTODO Examples

Below are examples of VTODO objects for each FlowIt type:

Project Example (VCALENDAR level):
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//FlowIt//FlowIt v0.1//EN
UID:project-1234-5678-ef00-1111
DTSTAMP:20250101T090000Z
CREATED:20250101T090000Z
LAST-MODIFIED:20250101T091500Z
SUMMARY:Marketing Campaign Q1
DESCRIPTION:## Q1 marketing *campaign planning* and execution
STATUS:NEEDS-ACTION
ORGANIZER:mailto:owner@example.com
PERCENT-COMPLETE:0
X-FLOWIT-TYPE:PROJECT
X-FLOWIT-ASFLOW:FALSE
X-FLOWIT-KANBAN:[{"UID":"board1","title":"Campaign Board","columns":["Planning","In Progress","Review","Done"]}]
X-FLOWIT-TEMPLATE:templateuid-aaaa-bbbb-cccc
X-FLOWIT-OWNER:owner@example.com
GETETAG:"12345-67890"
CALENDAR-ORDER:1
ATTENDEE:mailto:collaborator@example.com
END:VCALENDAR

Note: X-FLOWIT-DOMAIN is NOT stored in VCALENDAR objects but as a WebDAV property on the calendar collection itself. The domain for this project would be discoverable via PROPFIND on the calendar collection containing this VCALENDAR.

Task Example:
BEGIN:VTODO
UID:task-1234-5678-ef00-5555
DTSTAMP:20250101T090000Z
LAST-MODIFIED:20250101T091500Z
SUMMARY:Write Blog Post
DESCRIPTION:Create a blog post about new product features
STATUS:NEEDS-ACTION
DUE:20250115T170000Z
PERCENT-COMPLETE:0
x-flowit-type:task
x-flowit-process:project-1234-5678-ef00-1111
x-flowit-validator:[]
x-flowit-requirement:{}
x-flowit-kanban-column:[{"uid":"board1","column":"In Progress"}]
END:VTODO

Automated Task Example:
BEGIN:VTODO
UID:auto-1234-5678-ef00-6666
DTSTAMP:20250101T090000Z
LAST-MODIFIED:20250101T091500Z
SUMMARY:Schedule Social Media Post
DESCRIPTION:Automatically post content to social media
STATUS:NEEDS-ACTION
PERCENT-COMPLETE:0
x-flowit-type:automated-task
x-flowit-process:project-1234-5678-ef00-1111
x-flowit-validator:[]
x-flowit-requirement:{}
x-flowit-automate:{"trigger":"webhook","endpoint":"https://api.social.com/post","method":"POST","headers":{"Authorization":"Bearer token123"},"body":{"platform":"twitter","content":"{{content}}","scheduledTime":"{{due}}"}}
x-flowit-context:{"platform":"twitter","timezone":"UTC"}
END:VTODO

8. x-flowit-validator Schema

FlowIt's x-flowit-validator is an array of validator lists. Each validator list contains validators that must be completed for task validation. Each validator stores both its configuration and current state. The property must follow this JSON schema (serialized as a single line in the iCalendar property):

{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "x-flowit-validator Schema",
  "type": "array",
  "items": {
    "type": "array",
    "items": {
      "oneOf": [
        {
          "type": "object",
          "properties": {
            "id": {
              "type": "string",
              "description": "Unique identifier for this validator (UUID recommended)"
            },
            "type": {
              "type": "string",
              "enum": ["checklist"]
            },
            "required": {
              "type": "boolean",
              "description": "Whether this validator must be completed to validate the task"
            },
            "title": {
              "type": "string",
              "description": "Display title for this validator"
            },
            "items": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "type": "string",
                    "description": "Unique identifier for this checklist item"
                  },
                  "text": {
                    "type": "string",
                    "description": "Display text for this checklist item"
                  },
                  "checked": {
                    "type": "boolean",
                    "default": false,
                    "description": "Current state: whether this item is checked"
                  }
                },
                "required": ["id", "text", "checked"],
                "additionalProperties": false
              }
            }
          },
          "required": ["id", "type", "required", "title", "items"],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "id": {
              "type": "string",
              "description": "Unique identifier for this validator (UUID recommended)"
            },
            "type": {
              "type": "string",
              "enum": ["single_select"]
            },
            "required": {
              "type": "boolean",
              "description": "Whether this validator must be completed to validate the task"
            },
            "title": {
              "type": "string",
              "description": "Display title for this validator"
            },
            "options": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "type": "string",
                    "description": "Unique identifier for this option"
                  },
                  "text": {
                    "type": "string",
                    "description": "Display text for this option"
                  }
                },
                "required": ["id", "text"],
                "additionalProperties": false
              },
              "description": "Available options to select from"
            },
            "selected": {
              "type": "string",
              "description": "Currently selected option ID (must match one of the option IDs, or empty string if none selected)",
              "default": ""
            }
          },
          "required": ["id", "type", "required", "title", "options", "selected"],
          "additionalProperties": false
        },
        {
          "type": "object",
          "properties": {
            "id": {
              "type": "string",
              "description": "Unique identifier for this validator (UUID recommended)"
            },
            "type": {
              "type": "string",
              "enum": ["free_field"]
            },
            "required": {
              "type": "boolean",
              "description": "Whether this validator must be completed to validate the task"
            },
            "title": {
              "type": "string",
              "description": "Display title for this validator"
            },
            "value": {
              "type": "string",
              "description": "Current text content",
              "default": ""
            },
            "helper": {
              "type": "string",
              "description": "Optional helper text to guide the user",
              "default": ""
            }
          },
          "required": ["id", "type", "required", "title", "value"],
          "additionalProperties": false
        }
      ]
    }
  }
}

### Validator Behavior

- **Empty validator array (`[]`)**: Task can be completed by clicking the checkbox (simple completion)
- **Non-empty validator array**: All validator lists must be completed before the task can be marked as complete:
  - **Checklist**: All items with `checked: true` (if `required: true`)
  - **Single Select**: Must have a `selected` value that matches one of the option IDs (if `required: true`)
  - **Free Field**: Must have non-empty `value` (if `required: true`)

### Validator State Management

Each validator maintains its own state within the x-flowit-validator property:
- State changes are immediately persisted to the VTODO
- Validator lists can be added or removed independently
- Task completion status depends on all required validators in all lists being satisfied

### Example Validators

**Empty validators (simple checkbox completion):**
```json
[]
```

**Single validator list with checklist:**
```json
[
  [
    {
      "id": "checklist-001",
      "type": "checklist",
      "required": true,
      "title": "Pre-flight checklist",
      "items": [
        {"id": "item-1", "text": "Review documentation", "checked": true},
        {"id": "item-2", "text": "Test in staging environment", "checked": false},
        {"id": "item-3", "text": "Get approval from manager", "checked": false}
      ]
    }
  ]
]
```

**Single validator list with single select:**
```json
[
  [
    {
      "id": "select-001",
      "type": "single_select",
      "required": true,
      "title": "Choose deployment environment",
      "options": [
        {"id": "dev", "text": "Development"},
        {"id": "staging", "text": "Staging"},
        {"id": "prod", "text": "Production"}
      ],
      "selected": "staging"
    }
  ]
]
```

**Single validator list with free field:**
```json
[
  [
    {
      "id": "field-001",
      "type": "free_field",
      "required": true,
      "title": "Deployment notes",
      "value": "Deployed successfully with minor config changes",
      "helper": "Include any configuration changes or special notes"
    }
  ]
]
```

**Single validator list with multiple validators:**
```json
[
  [
    {
      "id": "checklist-001",
      "type": "checklist",
      "required": true,
      "title": "Quality checks",
      "items": [
        {"id": "item-1", "text": "Code review completed", "checked": true},
        {"id": "item-2", "text": "Tests passing", "checked": true}
      ]
    },
    {
      "id": "select-001",
      "type": "single_select",
      "required": true,
      "title": "Priority level",
      "options": [
        {"id": "low", "text": "Low"},
        {"id": "medium", "text": "Medium"},
        {"id": "high", "text": "High"},
        {"id": "critical", "text": "Critical"}
      ],
      "selected": "medium"
    },
    {
      "id": "field-001",
      "type": "free_field",
      "required": false,
      "title": "Additional comments",
      "value": "",
      "helper": "Optional field for extra context"
    }
  ]
]
```

9. Example VTODO

Below is an example of a VTODO that references all relevant standard and FlowIt-specific fields:

BEGIN:VTODO
UID:abcd1234-5678-ef00-1111-222233334444
DTSTAMP:20250101T090000Z
LAST-MODIFIED:20250101T091500Z
SUMMARY:Quarterly Report Analysis
DESCRIPTION:Complete the quarterly report analysis and present the findings.
STATUS:NEEDS-ACTION
DUE:
PERCENT-COMPLETE:
ORGANIZER:author@acme.com
ATTENDEE:mailto:assistant@acme.com
CATEGORIES:Reports,Financial,Quarterly
x-flowit-type:task
x-flowit-validator:[[{"id":"8b5ffa24-1b20-4672-9d23-d54693821eba","type":"single_select","required":true,"title":"Choose a region","options":[{"id":"emea","text":"EMEA"},{"id":"apac","text":"APAC"},{"id":"americas","text":"Americas"}],"selected":"emea"}]]
x-flowit-requirement:{"requires":["otheruid-1111-2222-3333"]}
x-flowit-template:templateuid-aaaa-bbbb-cccc
x-flowit-process:processuid-pppp-qqqq-rrrr
x-flowit-reversaltask:reversaluid-zzzz-yyyy-xxxx
x-flowit-context:{"priority":"high","department":"finance"}
END:VTODO

10. Implementation Details
10.1 Local Storage

    Use a key-value database to store VTODO items locally.
    Each item can be stored as JSON with fields such as uid, summary, description, x-flowit-* data, lastModified, etc.
    Offline usage: The local DB is the main data store; the sync engine updates/reads from CalDAV in the background.

10.2 Synchronization Logic

    Fetch remote: On startup or periodic intervals, download updated items from CalDAV.
    Apply merges: Compare LAST-MODIFIED; if local changed more recently, push to server; if server changed more recently, update local.
    Queue changes: If the user edits a VTODO offline, store changes locally; once online, push them.

10.3 UI Implementation

    Screens:
        Home Screen: List tasks for "Today," "Soon," "Unregistered."
        Project Detail: Show tasks and groups within that project.
        Flow Detail: If x-flowit-type = flow, show a pipeline or sequence.
        Task Edit: A page for editing the SUMMARY, DESCRIPTION, etc.
        Category Management: Interface for adding, removing, and organizing categories.

    Widgets:
        Notion-Like Editor for the DESCRIPTION.
        Validator rendering for checklists, single selects, and free field inputs.
        Sidebar / Drawer for navigation.
        Category Chips: Visual representation of categories as colored chips.
        Category Dialog: UI for managing task and project categories.

10.4 Error Handling & Edge Cases

    Conflict: If LAST-MODIFIED is the same on local & remote, the server typically decides or FlowIt merges carefully.
    Empty JSON: If x-flowit-* fields are not relevant, store {} or [] rather than null.
    Deletion: Mark a task as STATUS:CANCELLED or remove it entirely; handle references in x-flowit-* carefully.

11. Design

11.1 Iconography

This section defines Material Design icon mappings used throughout FlowIt for actions, status indicators, and UI elements.

11.1.1 Task Indicators

| Element | Material Icon | Color | Meaning |
|---------|---------------|-------|---------|
| Has validators | `fact_check` | `colorScheme.primary` | Task has configured validators |
| Attendees | `person_rounded` if 1 attendee, `group` if two or more | `colorScheme.secondary` | Task has assigned attendees |
| Categories | `label_rounded` | `colorScheme.tertiary` | Task belongs to categories |

11.1.2 Due Date Status

| Status | Material Icon | Color | Meaning |
|--------|---------------|-------|---------|
| Overdue | `warning_rounded` | `Colors.red.shade600` | Task is past due |
| Normal due date | None | `colorScheme.primary` | Due date in the future |

11.1.3 Task Actions

| Action | Material Icon | Color | Meaning |
|--------|---------------|-------|---------|
| Set due date | `calendar_today_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Open date picker |
| Set validator | `fact_check` | `colorScheme.onSurface.withOpacity(0.6)` | Configure task validator |
| Add attendee | `person_add_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Assign an attendee |
| Add category | `label_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Assign a category |
| Move task | `drive_file_move_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Change project |
| Delete task | `delete_rounded` | `colorScheme.error` | Permanently delete |
| Archive task | `archive` | `colorScheme.onSurface.withOpacity(0.6)` | Permanently delete |
| Add GPS coordinate | `pin_drop` | `colorScheme.onSurface.withOpacity(0.6)` | Permanently delete |
| Debug info | `info_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Show UID (debug mode only) |

11.1.4 Navigation and Interface

| Element | Material Icon | Color | Usage |
|---------|---------------|-------|-------|
| Expand/Collapse | `expand_more_rounded` / `expand_less_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Toggle task detail view |
| Project expand | `expand_more_rounded` / `expand_less_rounded` | `colorScheme.onSurface.withOpacity(0.5)` | Toggle project details |

11.1.5 Tab Bar Icons

### My Tasks Tab Bar

| Tab | Material Icon | Meaning |
|-----|---------------|---------|
| Today | `today_rounded` | Tasks due today |
| Soon | `schedule_rounded` | Tasks due within a week |
| Later | `event_rounded` | Tasks due later than a week |
| Anytime | `layers_rounded` | Tasks without due dates |

### Project Detail Tab Bar

| Tab | Material Icon | Meaning |
|-----|---------------|---------|
| List | `checklist_rounded` | Task list view |
| Timing | `schedule_rounded` | Tasks organized by due date |
| Attendee | `groups` | Tasks organized by attendees |
| Kanban | `view_kanban_rounded` | Kanban board view |
| Agenda | `calendar_month_rounded` | Calendar/agenda view |

11.2 Size Conventions

| Context | Size (px) | Usage |
|---------|-----------|-------|
| Task indicators | 16 | Status icons in main line |
| Task actions | 20 | Action buttons in expanded section |
| Date badge warning | 10 | Alert icon in date badge |
| Navigation | 18-20 | Navigation buttons and UI controls |

11.3 Color Palette

Colors use Material Design 3 color system via `Theme.of(context).colorScheme`:

- **Primary**: Main actions and validators
- **Secondary**: Attendees and collaboration  
- **Tertiary**: Categories and classification
- **Error**: Destructive actions
- **OnSurface + Opacity**: Neutral actions and UI controls




