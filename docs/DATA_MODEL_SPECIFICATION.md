# FlowIt Data Model Specification

## Overview

FlowIt uses standard iCalendar VTODO objects with custom extensions to store complex workflow data. Each VTODO object contains both RFC 5545 standard fields and FlowIt-specific extensions prefixed with `x-flowit-*`.

## Standard iCalendar Fields

Each item is a VTODO with these required or optional fields:

### Required Fields
- **UID** (required): Globally unique identifier
- **SUMMARY** (required): Task title/name
- **DESCRIPTION** (required): Task description, supports Markdown
- **LAST-MODIFIED** (required): For sync/conflict resolution
- **DTSTAMP** (required): Creation timestamp per iCalendar standard

### Optional Standard Fields
- **STATUS**: NEEDS-ACTION, COMPLETED, CANCELLED
- **DUE**: Due date/time
- **PERCENT-COMPLETE**: Completion percentage (0-100)
- **ATTENDEE**: Collaboration participants (detailed below)
- **CATEGORIES**: Classification tags
- **ATTACH**: File attachments
- **ORGANIZER**: Primary responsible person

## ATTENDEE Structure (RFC 5545 Compliant)

FlowIt implements full RFC 5545 ATTENDEE support for collaboration:

### Required Properties
- **EMAIL**: Attendee's email address (URI format, e.g., `mailto:user@domain.com`)

### Optional Properties
- **CN (Common Name)**: Display name for the attendee
- **PARTSTAT (Participation Status)**: Current response status
  - `NEEDS-ACTION` (default): No response yet
  - `ACCEPTED`: Attendee has accepted
  - `DECLINED`: Attendee has declined
  - `TENTATIVE`: Tentatively available
  - `DELEGATED`: Delegated to someone else
- **ROLE**: Attendee's role in the task
  - `REQ-PARTICIPANT` (default): Required participant
  - `OPT-PARTICIPANT`: Optional participant
  - `NON-PARTICIPANT`: Observer only
  - `CHAIR`: Meeting/task chair/leader
- **CUTYPE (Calendar User Type)**: Type of attendee
  - `INDIVIDUAL` (default): Person
  - `GROUP`: Group or distribution list
  - `RESOURCE`: Equipment or facility
  - `ROOM`: Meeting room
  - `UNKNOWN`: Unknown type
- **RSVP**: Whether response is requested (true/false, default: false)
- **DELEGATED-FROM**: Email of person who delegated this task
- **DELEGATED-TO**: Email of person this task was delegated to

### Email Validation Policy
FlowIt performs basic email format validation but does not block malformed emails. If an email is missing or malformed, the user receives a warning popup stating that "this attendee may never receive notifications through email" but can proceed with the addition.

### Example ATTENDEE Entries
```
ATTENDEE;CN=John Doe;PARTSTAT=ACCEPTED;ROLE=REQ-PARTICIPANT:mailto:john@example.com
ATTENDEE;CN=Jane Smith;PARTSTAT=TENTATIVE;ROLE=CHAIR:mailto:jane@company.com
ATTENDEE;CUTYPE=RESOURCE;CN=Conference Room A:mailto:room-a@facilities.com
```

## FlowIt-Specific Extensions

All custom fields are prefixed with `x-flowit-` and store JSON or string values. JSON must be valid (no null for empties; use `{}` or `[]`).

### x-flowit-type (Required)
Defines how FlowIt interprets the VTODO.

**Allowed Values:**
- `task`: Standard actionable item
- `automated-task`: Task that runs automatically based on triggers

**Note**: `project` type is **DEPRECATED** - projects are now represented at the VCALENDAR level.

### x-flowit-validator (Required, can be empty {})
A JSON array describing how a task is completed/validated.
- `[]` for simple "mark complete"
- Complex validator schemas for forms, checklists, etc.
See [Validator Schema Documentation](VALIDATOR_SCHEMA.md) for details.

### x-flowit-requirement (Required, can be {})
JSON specifying prerequisites or resources.
```json
{"requires":["UID_of_another_task"]}
```

### x-flowit-template (Required)
A UID pointing to a "template" VTODO for this item. Allows FlowIt to replicate consistent fields, forms, or structures across tasks.

### x-flowit-process (Required)
A UID referencing the overarching "flow" (another VTODO where x-flowit-type = flow). Ties the current task to a parent flow or process pipeline.

### x-flowit-reversaltask (Optional)
A UID referencing a "reversal" or "undo" task. If the current task triggers irreversible changes, the reversal task is how to revert it.

### x-flowit-automate (Conditionally Required)
A JSON object describing automation triggers, schedules, or scripts. Required only if `x-flowit-type = automated-task`.
```json
{"trigger":"webhook","endpoint":"https://example.com/flowit/hook"}
```

### x-flowit-context (Conditionally Required)
A JSON object with extra context for task types. Include for `x-flowit-type = task` (even if `{}`).
```json
{"priority":"high","department":"finance"}
```

### x-flowit-kanban-column (Conditionally Required)
A JSON object with kanban column assignments. Only for tasks.
```json
[{"uid":"AAAAA-BBBB","column":"In Progress"}]
```

## Calendar/Project Level Properties (VCALENDAR)

Projects are represented as CalDAV calendars, not individual VTODO objects.

### Required VCALENDAR Properties
- **UID**: Globally unique calendar identifier
- **DTSTAMP**: Creation timestamp
- **CREATED**: Creation timestamp from client perspective
- **LAST-MODIFIED**: Last update timestamp
- **SUMMARY**: Project name (display name)
- **STATUS**: Calendar/project status
- **PERCENT-COMPLETE**: Overall completion (0–100)
- **X-FLOWIT-TYPE**: `PROJECT` - FlowIt marker
- **X-FLOWIT-ASFLOW**: `FALSE` - indicates not a flow container
- **X-FLOWIT-KANBAN**: JSON array of kanban states (may be empty)

### Optional VCALENDAR Properties
- **DESCRIPTION**: Project description (Markdown allowed)
- **CATEGORIES**: Tags to classify the project
- **X-FLOWIT-TEMPLATE**: UID if based on a template
- **ORGANIZER**: CalDAV/email address of responsible person
- **ATTENDEE**: Optional collaborators

## Domain Organization (X-FLOWIT-DOMAIN)

Domains provide hierarchical organization for projects, implemented as WebDAV properties on calendar collections.

### Technical Implementation
- **Protocol**: WebDAV property on calendar collections (RFC 4918)
- **Namespace**: `http://flowit.app/ns/`
- **Location**: Calendar collection level (not VCALENDAR or VTODO objects)
- **Format**: String value representing domain name
- **Cardinality**: 0..1 per calendar (optional, maximum one domain per project)

### Behavior
- Missing/empty X-FLOWIT-DOMAIN: project appears in "No Domain" section
- Projects with same domain value are grouped together in UI
- Domain names are user-defined and created dynamically
- Flat structure only (no hierarchical nesting)

## Conflict Resolution

### Timestamp-Based Resolution
- **LAST-MODIFIED** is key to detecting concurrency issues
- Server and local versions compared by timestamps
- Last-updated wins or field-by-field merge when possible

### Merge Strategies
1. **Simple conflicts**: Last-modified timestamp wins
2. **Partial merges**: Field-by-field comparison when feasible
3. **User intervention**: Complex conflicts may require user decision

## Data Validation Rules

### JSON Field Validation
- All x-flowit-* JSON fields must be valid JSON
- Empty values should be `{}` or `[]`, not null
- Required fields must be present even if empty

### UID Requirements
- All UIDs must be globally unique
- Recommended format: UUID v4
- UIDs are immutable once created

### Relationship Integrity
- x-flowit-process must reference existing project/flow
- x-flowit-requirement UIDs must be valid task references
- x-flowit-template UIDs should reference existing templates

## Example Complete VTODO

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
x-flowit-validator:[[{"id":"8b5ffa24","type":"single_select","required":true,"title":"Choose a region","options":[{"id":"emea","text":"EMEA"},{"id":"apac","text":"APAC"},{"id":"americas","text":"Americas"}],"selected":"emea"}]]
x-flowit-requirement:{"requires":["otheruid-1111-2222-3333"]}
x-flowit-template:templateuid-aaaa-bbbb-cccc
x-flowit-process:processuid-pppp-qqqq-rrrr
x-flowit-reversaltask:reversaluid-zzzz-yyyy-xxxx
x-flowit-context:{"priority":"high","department":"finance"}
x-flowit-kanban-column:[{"uid":"board1","column":"In Progress"}]
END:VTODO
```

## Type Migration Rules

### Task Type Conversion
- Tasks can be converted to automated tasks and vice versa
- Type changes preserve all relevant properties
- Type-specific properties are removed when converting to incompatible type

### Project Migration
- Legacy VTODO objects with `x-flowit-type: project` must be migrated to calendar-level representation
- Migration occurs during first sync
- No new project VTODO objects should be created

---
*For detailed validator schema information, see [VALIDATOR_SCHEMA.md](VALIDATOR_SCHEMA.md)*
*For domain implementation details, see [DOMAIN_WEBDAV_IMPLEMENTATION.md](DOMAIN_WEBDAV_IMPLEMENTATION.md)*
*Last updated: 2024-12-19* 