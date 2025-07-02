# FlowIt Types Reference

## Overview

FlowIt supports several types of items, each with specific properties and relationships. All types are stored as VTODO objects with different `x-flowit-type` values, except for projects which are represented at the VCALENDAR level.

## Calendar / Project (VCALENDAR level)

> ⚠️ **DEPRECATION NOTICE** – FlowIt no longer stores a dedicated VTODO object of type `project`. A CalDAV calendar **is** the project in the user experience. Legacy VTODO items with `x-flowit-type: project` SHOULD NOT be created anymore and MUST be migrated to a calendar-level representation during the first sync.

### Required Properties (VCALENDAR)
- **UID** – globally unique calendar identifier (if the server does not expose one, FlowIt generates a stable UUID)
- **DTSTAMP** – creation timestamp
- **CREATED** – creation timestamp from the client perspective
- **LAST-MODIFIED** – last update timestamp
- **SUMMARY** – project name (display name)
- **STATUS** – calendar/project status (NEEDS-ACTION, COMPLETED, etc.)
- **PERCENT-COMPLETE** – overall completion (0–100)
- **X-FLOWIT-TYPE**: `PROJECT` – FlowIt marker identifying this calendar as a project
- **X-FLOWIT-ASFLOW**: `FALSE` – indicates the calendar is not a "flow" container
- **X-FLOWIT-KANBAN** – JSON array of kanban states (may be empty)
- **X-FLOWIT-OWNER** – identifier or email of the owner (if ORGANIZER not used)
- **X-FLOWIT-DOMAIN** – domain name for grouping projects (WebDAV property on calendar collections)
- **GETETAG** – server-managed ETag, preserved for caching & sync
- **CALENDAR-ORDER** – integer used for UX ordering
- **ORGANIZER** – CalDAV/email address of the responsible person
- **ATTENDEE** – optional collaborators

### Optional Properties
- **DESCRIPTION** – project description (Markdown allowed)
- **CATEGORIES** – tags to classify the project
- **X-FLOWIT-TEMPLATE** – UID if the project is based on a template

### Example Project (VCALENDAR)
```
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
```

**Note**: X-FLOWIT-DOMAIN is NOT stored in VCALENDAR objects but as a WebDAV property on the calendar collection itself.

## Domain Organization (X-FLOWIT-DOMAIN)

Domains provide a hierarchical organization system for projects, acting as folders to group related calendars/projects together.

### Purpose
- Group related projects under a common domain name
- Provide visual organization in the UI (folder-like structure)
- Enable bulk operations on projects within the same domain
- Support hierarchical project navigation

### Technical Implementation
- **Protocol**: WebDAV property on calendar collections (RFC 4918 PROPPATCH/PROPFIND)
- **Namespace**: `http://flowit.app/ns/` (usually aliased as `FLOWIT:` or dynamic like `ns3:`)
- **Location**: Calendar collection level (not VCALENDAR or VTODO objects)
- **Cardinality**: 0..1 per calendar (optional, maximum one domain per project)
- **Format**: String value representing the domain name
- **Case Sensitivity**: Case-insensitive for display purposes, case-preserving for storage
- **Validation**: Must be a non-empty string if provided, no special character restrictions

### Behavior
- If X-FLOWIT-DOMAIN is missing or empty, the project appears in the "No Domain" section
- Projects with the same domain value are grouped together in the UI
- Domain names are user-defined and can be created dynamically when assigning projects
- Domains have no hierarchical nesting (flat structure only)
- Changing a project's domain immediately triggers a PROPPATCH request to update the server

*For detailed domain implementation, see [DOMAIN_WEBDAV_IMPLEMENTATION.md](DOMAIN_WEBDAV_IMPLEMENTATION.md)*

## Task (x-flowit-type: task)

A single actionable item that represents work to be completed.

### Required Properties
- **Standard VTODO fields:**
  - UID (required)
  - DTSTAMP (required)
  - LAST-MODIFIED (required)
  - SUMMARY (required)
  - DESCRIPTION (required, can be empty)
  - STATUS (required, default: NEEDS-ACTION)
- **x-flowit-type**: `"task"` (required)
- **x-flowit-process**: UID of parent project/flow (required)
- **x-flowit-validator**: Array of validator lists (required, can be empty array for simple checkbox completion)
- **x-flowit-requirement**: Dependency specification (required, can be empty object)

### Optional Properties
- DUE
- CATEGORIES
- ATTENDEE
- x-flowit-template
- x-flowit-reversaltask
- x-flowit-context
- x-flowit-kanban-column

### Relationships
- Can be part of a project or flow
- Can be part of a kanban board
- When created in a flow context, should establish a sibling relationship with the corresponding step

### Example Task
```
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
```

## Automated Task (x-flowit-type: automated-task)

A task that runs automatically based on triggers or schedules.

### Required Properties
- **Standard VTODO fields:**
  - UID (required)
  - DTSTAMP (required)
  - LAST-MODIFIED (required)
  - SUMMARY (required)
  - DESCRIPTION (required, can be empty)
  - STATUS (required, default: NEEDS-ACTION)
  - PERCENT-COMPLETE (required, default: 0)
- **x-flowit-type**: `"automated-task"` (required)
- **x-flowit-validator**: Array (required, typically empty for automated tasks)
- **x-flowit-requirement**: Dependency specification (required, can be empty)
- **x-flowit-automate**: Automation configuration (required, describes automation triggers)
- **x-flowit-context**: Context information (required, can be empty object)

### Optional Properties
- CATEGORIES
- ATTENDEE
- x-flowit-process (UID of parent project or flow)

### Relationships
- Can be part of a project or flow
- Can reference other tasks via x-flowit-requirement

### Example Automated Task
```
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
```

## Type Conversion Rules

### Task Type Conversion
- Tasks can be converted to automated tasks and vice versa
- Type changes preserve all relevant properties
- Type-specific properties are removed when converting to an incompatible type

### Project Migration
- Legacy VTODO objects with `x-flowit-type: project` must be migrated to calendar-level representation
- Migration occurs during first sync
- No new project VTODO objects should be created

## VCALENDAR Level Properties

Properties that exist only at the calendar/project level, not in individual VTODO objects:

### X-FLOWIT-KANBAN (VCALENDAR level only)
⚠️ **MOVED TO VCALENDAR LEVEL**: This property is now X-FLOWIT-KANBAN at the calendar level, not in individual VTODO objects.
- A JSON array of kanban board definitions for the project
- Only applies to calendars with X-FLOWIT-TYPE:PROJECT
- Example: `[{"UID":"AAAAA-BBBB","title":"Kanban board 1","columns":["Easy","Medium","Hard"]},{"UID":"AAAAA-BCBBB","title":"Kanban board 2","columns":["ColA","ColB"]}]`

### X-FLOWIT-ASFLOW (VCALENDAR level only)
⚠️ **MOVED TO VCALENDAR LEVEL**: This property is now X-FLOWIT-ASFLOW at the calendar level.
- Only for calendars with X-FLOWIT-TYPE:PROJECT
- If missing, default to FALSE
- Indicates whether the calendar represents a flow container

## Complete VTODO Example

Below is a comprehensive example of a VTODO that references all relevant standard and FlowIt-specific fields:

```
BEGIN:VTODO
UID:abcd1234-5678-ef00-1111-222233334444
DTSTAMP:20250101T090000Z
LAST-MODIFIED:20250101T091500Z
SUMMARY:Quarterly Report Analysis
DESCRIPTION:Complete the quarterly report analysis and present the findings.
STATUS:NEEDS-ACTION
DUE:20250115T170000Z
PERCENT-COMPLETE:0
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
x-flowit-kanban-column:[{"uid":"board1","column":"In Progress"}]
END:VTODO
```

## Data Model Notes

### JSON Field Requirements
- All x-flowit-* fields that store JSON must be valid JSON
- Empty fields should use `{}` or `[]`, not null
- Required fields must be present even if empty

### UID Management
- All UIDs must be globally unique
- Recommended format: UUID v4
- UIDs are immutable once created

### Relationship Integrity
- x-flowit-process must reference existing project/flow
- x-flowit-requirement UIDs must reference valid tasks
- x-flowit-template UIDs should reference existing templates

---
*For detailed data model specifications, see [DATA_MODEL_SPECIFICATION.md](DATA_MODEL_SPECIFICATION.md)*
*For validator schema details, see [VALIDATOR_SCHEMA.md](VALIDATOR_SCHEMA.md)*
*Last updated: 2024-12-19* 