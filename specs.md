FlowIt Project Specifications
1. Overview

FlowIt is a cross-platform application (desktop on Windows/Linux, and mobile on Android) built with Flutter. Its primary purpose is to help users manage tasks, projects, groups, and “flows” in an offline-first manner, while synchronizing data to a CalDAV server (using VTODO objects). FlowIt extends the standard iCalendar VTODO format with extra x-flowit-* properties to handle advanced workflows, forms, and automations.

Key Principles:

    Offline-First: Local storage (key-value) is the source of truth, ensuring reliable usage even when offline.
    Optimistic UI: The app updates immediately on user actions, then synchronizes changes in the background.
    Minimal Dependencies: Rely primarily on Flutter’s Material widgets and standard libraries to keep the code base maintainable.
    Adaptive UX: A single codebase supports both desktop (with persistent sidebars) and mobile (with slide-out navigation) layouts, following Flutter’s adaptive guidelines and best practices described in Extreme UI Adaptability in Flutter.
    Interoperability: Standard iCalendar fields let FlowIt integrate with any CalDAV-compliant server or client; custom fields (x-flowit-*) enable advanced features within FlowIt.

2. Project Goals & Roadmap
2.1 Version 0 (v0)

    CalDAV Integration
        Read/write VTODO objects on a CalDAV server.
        Two-way sync (local ↔ remote).
        Basic conflict resolution (last-modified wins).

    Task/Group/Project Structure
        Each item is stored as a VTODO.
        Project: Top-level container for tasks and groups.
        Group: Sibling tasks grouped under a parent project.
        Task: A single actionable item.

    Notion-Like Editor
        DESCRIPTION in VTODO supports Markdown.
        Potential slash commands, bullet lists, etc. for improved user experience.

    Basic Validators
        Mark tasks as complete with a simple checkbox (or a more advanced form if x-flowit-validator is configured).

    Task Views
        “Today”: tasks with imminent due dates.
        “Soon”: tasks with upcoming due dates.
        “Unregistered”: tasks without due dates or no assigned project.

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
        x-flowit-validator can store forms.
        x-flowit-requirement references tasks/data that must be completed before a task can be finished.
        “Success/Fail” states if needed.

    Automation
        x-flowit-automate describes triggers, schedules, or webhooks for tasks of type automated-task.

3. Architecture & Design Patterns

    Offline-First
        A local key-value database (e.g., Hive or Sembast) persists tasks, ensuring usage without network connectivity.

    Optimistic State Updates
        Upon user action, the local store is updated immediately.
        A background sync process reconciles with the CalDAV server.
        Conflicts use a “last-updated wins” strategy or partial merges when feasible.

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
        Use Flutter’s Material components (AppBar, NavigationDrawer, FloatingActionButton, etc.).
        Maintain consistent color schemes, typography, and shape theming via a shared ThemeData.

    Responsive Layout
        Desktop: A left sidebar for navigation, a main panel for content (tasks, editor, etc.).
        Mobile: A single column layout with a top app bar or bottom navigation; the sidebar becomes a slide-out drawer.

    Notion-Like Editor
        Provide a rich text area that supports Markdown.
        Potentially integrate slash commands to insert special blocks or references.
        All final text is stored in the DESCRIPTION field.

    Project & Task Views
        “Today” and “Soon” lists highlight tasks by due date.
        “Unregistered” shows tasks missing a project or due date.
        A “Project Detail” screen lets users see tasks, groups, and sub-items.
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
    ATTENDEE (optional)
    ATTACH (optional)

5.2 Conflict Resolution

    LAST-MODIFIED is the key to detecting concurrency issues.
    If server and local versions both changed, FlowIt compares timestamps to decide which version wins or tries a field-by-field merge if possible.

5.3 Sync Flow

    Local Edit: user action updates local store immediately.
    Background Sync: changes are batched or queued to push to CalDAV.
    Server Response: new data is pulled from CalDAV.
    Merge: if conflicts appear, apply last-updated logic or partial merges.
    Local Store Update: finalize the synced item’s state locally.

6. FlowIt-Specific iCalendar Extensions

FlowIt uses non-standard iCalendar properties to store advanced workflow data in each VTODO. These are prefixed with x-flowit-. They allow hierarchical tasks, templates, flows, advanced validators, and more.

All these fields store JSON or string values.

    If storing JSON, it must be valid (no null for empties; use {} or []).
    If a field is not relevant, it may be an empty object ({}) or omitted if permissible.

6.1 x-flowit-type (Required)

    Defines how FlowIt interprets the VTODO.
    Allowed Values:
        automated-task
        task
        task-group
        flow

6.2 x-flowit-validator (Required, can be empty {})

    A JSON describing how a task is completed/validated.
    Schema detailed in Section 7.
    {"type":"default"} for simple “mark complete,” or {"type":"form","form":[...questions...]} for a user form.

6.3 x-flowit-requirement (Required, can be {})

    JSON specifying prerequisites or resources.
    Example: {"requires":["UID_of_another_task"]}

6.4 x-flowit-template (Required)

    A UID pointing to a “template” VTODO for this item.
    Allows FlowIt to replicate consistent fields, forms, or structures across tasks.

6.5 x-flowit-process (Required)

    A UID referencing the overarching “flow” (another VTODO where x-flowit-type = flow).
    Ties the current task to a parent flow or process pipeline.

6.6 x-flowit-reversaltask (Required)

    A UID referencing a “reversal” or “undo” task.
    If the current task triggers irreversible changes, the reversal task is how to revert it.

6.7 x-flowit-automate (Conditionally Required)

    A JSON object describing automation triggers, schedules, or scripts.
    Required only if x-flowit-type = automated-task.
    Example: {"trigger":"webhook","endpoint":"https://example.com/flowit/hook"}

6.8 x-flowit-context (Conditionally Required)

    A JSON object with extra context for task types.
    Could store priority, environment info, or project-specific metadata.
    If x-flowit-type = task, include it (even if {}).
    Example: {"priority":"high","department":"finance"}

7. x-flowit-validator Schema

FlowIt’s x-flowit-validator must follow this JSON schema (serialized as a single line in the iCalendar property):

{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "x-flowit-validator Schema",
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["default"]
        }
      },
      "required": ["type"],
      "additionalProperties": false
    },
    {
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["form"]
        },
        "form": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "questionid": {
                "type": "string",
                "description": "Use a UUID (dash-separated or snake_case)."
              },
              "questiontype": {
                "type": "string",
                "enum": ["select", "freefield", "multiselect"]
              },
              "questiontext": {
                "type": "string"
              },
              "mandatory": {
                "type": "boolean"
              },
              "questionoption": {
                "type": "array",
                "items": {
                  "type": "string"
                }
              }
            },
            "required": [
              "questionid",
              "questiontype",
              "questiontext",
              "mandatory",
              "questionoption"
            ],
            "additionalProperties": false
          }
        }
      },
      "required": ["type", "form"],
      "additionalProperties": false
    }
  ]
}

Notes:

    type = "default": a minimal validator allowing quick completion.
    type = "form": requires an array of questions.
    questionid must be a unique string (recommended UUID).
    If no question options apply (e.g., for freefield), store "questionoption":[] not null.

8. Example VTODO

Below is an example of a VTODO that references all relevant standard and FlowIt-specific fields:

BEGIN:VTODO
UID:abcd1234-5678-ef00-1111-222233334444
DTSTAMP:20250101T090000Z
LAST-MODIFIED:20250101T091500Z
SUMMARY:Quarterly Report Analysis
DESCRIPTION:Complete the quarterly report analysis and present the findings.
STATUS:NEEDS-ACTION

x-flowit-type:task
x-flowit-validator:{"type":"form","form":[{"questionid":"8b5ffa24-1b20-4672-9d23-d54693821eba","questiontype":"select","questiontext":"Choose a region?","mandatory":true,"questionoption":["EMEA","APAC","Americas"]}]}
x-flowit-requirement:{"requires":["otheruid-1111-2222-3333"]}
x-flowit-template:templateuid-aaaa-bbbb-cccc
x-flowit-process:processuid-pppp-qqqq-rrrr
x-flowit-reversaltask:reversaluid-zzzz-yyyy-xxxx
x-flowit-context:{"priority":"high","department":"finance"}

END:VTODO

9. Implementation Details
9.1 Local Storage

    Use a key-value database to store VTODO items locally.
    Each item can be stored as JSON with fields such as uid, summary, description, x-flowit-* data, lastModified, etc.
    Offline usage: The local DB is the main data store; the sync engine updates/reads from CalDAV in the background.

9.2 Synchronization Logic

    Fetch remote: On startup or periodic intervals, download updated items from CalDAV.
    Apply merges: Compare LAST-MODIFIED; if local changed more recently, push to server; if server changed more recently, update local.
    Queue changes: If the user edits a VTODO offline, store changes locally; once online, push them.

9.3 UI Implementation

    Screens:
        Home Screen: List tasks for “Today,” “Soon,” “Unregistered.”
        Project Detail: Show tasks and groups within that project.
        Flow Detail: If x-flowit-type = flow, show a pipeline or sequence.
        Task Edit: A page for editing the SUMMARY, DESCRIPTION, etc.

    Widgets:
        Notion-Like Editor for the DESCRIPTION.
        Validator Form rendering if x-flowit-validator → form.
        Sidebar / Drawer for navigation.

9.4 Error Handling & Edge Cases

    Conflict: If LAST-MODIFIED is the same on local & remote, the server typically decides or FlowIt merges carefully.
    Empty JSON: If x-flowit-* fields are not relevant, store {} or [] rather than null.
    Deletion: Mark a task as STATUS:CANCELLED or remove it entirely; handle references in x-flowit-* carefully.

10. Conclusion

This FlowIt Project Specification provides an end-to-end view of the application’s goals, architecture, UI guidelines, and crucial data model details. By adhering to these specifications, developers ensure:

    Interoperability with standard CalDAV/iCalendar tools.
    Advanced workflow functionality via x-flowit-* properties.
    Robust offline capabilities and consistent conflict resolution.
    A maintainable, adaptive Flutter codebase that scales from mobile to desktop.

FlowIt’s design emphasizes minimal external dependencies, maximum adaptability, and an elegant user experience for managing everyday tasks as well as complex, automated flows. By following this document, the engineering team can implement and evolve FlowIt with confidence.