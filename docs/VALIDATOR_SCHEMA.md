# FlowIt Validator Schema Documentation

## Overview

FlowIt's `x-flowit-validator` is an array of validator lists that defines how tasks are completed and validated. Each validator list contains validators that must be completed for task validation. Each validator stores both its configuration and current state.

## Schema Structure

The `x-flowit-validator` property must follow this JSON schema (serialized as a single line in the iCalendar property):

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "x-flowit-validator Schema",
  "type": "array",
  "items": {
    "type": "array",
    "items": {
      "oneOf": [
        // Validator types defined below
      ]
    }
  }
}
```

## Validator Types

### 1. Checklist Validator

Creates a list of checkable items that can be marked as complete.

```json
{
  "id": "string (UUID recommended)",
  "type": "checklist",
  "required": "boolean",
  "title": "string",
  "items": [
    {
      "id": "string",
      "text": "string", 
      "checked": "boolean (default: false)"
    }
  ]
}
```

**Properties:**
- **id**: Unique identifier for this validator (UUID recommended)
- **type**: Must be `"checklist"`
- **required**: Whether this validator must be completed to validate the task
- **title**: Display title for this validator
- **items**: Array of checklist items
  - **id**: Unique identifier for this checklist item
  - **text**: Display text for this checklist item
  - **checked**: Current state - whether this item is checked

### 2. Single Select Validator

Allows selection of one option from a predefined list.

```json
{
  "id": "string (UUID recommended)",
  "type": "single_select",
  "required": "boolean",
  "title": "string",
  "options": [
    {
      "id": "string",
      "text": "string"
    }
  ],
  "selected": "string (default: empty)"
}
```

**Properties:**
- **id**: Unique identifier for this validator (UUID recommended)
- **type**: Must be `"single_select"`
- **required**: Whether this validator must be completed to validate the task
- **title**: Display title for this validator
- **options**: Available options to select from
  - **id**: Unique identifier for this option
  - **text**: Display text for this option
- **selected**: Currently selected option ID (must match one of the option IDs, or empty string if none selected)

### 3. Free Field Validator

Provides a text input field for free-form user input.

```json
{
  "id": "string (UUID recommended)",
  "type": "free_field",
  "required": "boolean",
  "title": "string",
  "value": "string (default: empty)",
  "helper": "string (optional)"
}
```

**Properties:**
- **id**: Unique identifier for this validator (UUID recommended)
- **type**: Must be `"free_field"`
- **required**: Whether this validator must be completed to validate the task
- **title**: Display title for this validator
- **value**: Current text content
- **helper**: Optional helper text to guide the user (optional field)

### 4. File Validator

Provides file upload functionality with encrypted storage.

```json
{
  "id": "string (UUID recommended)",
  "type": "file",
  "required": "boolean",
  "title": "string",
  "files": "array (default: empty)",
  "encryptionKey": "string (automatically generated)",
  "helper": "string (optional)"
}
```

**Properties:**
- **id**: Unique identifier for this validator (UUID recommended)
- **type**: Must be `"file"`
- **required**: Whether this validator must be completed to validate the task
- **title**: Display title for this validator
- **files**: Array of file attachment objects
- **encryptionKey**: Automatically generated encryption key for file security
- **helper**: Optional helper text to guide the user (optional field)

## Validator Behavior

### Task Completion Logic

- **Empty validator array (`[]`)**: Task can be completed by clicking the checkbox (simple completion)
- **Non-empty validator array**: All validator lists must be completed before the task can be marked as complete

### Completion Requirements by Type

- **Checklist**: All items with `checked: true` (if `required: true`)
- **Single Select**: Must have a `selected` value that matches one of the option IDs (if `required: true`)
- **Free Field**: Must have non-empty `value` (if `required: true`)
- **File**: Must have at least one file in the `files` array (if `required: true`)

### State Management

- Each validator maintains its own state within the x-flowit-validator property
- State changes are immediately persisted to the VTODO
- Validator lists can be added or removed independently
- Task completion status depends on all required validators in all lists being satisfied

## Example Implementations

### 1. Empty Validators (Simple Checkbox)
```json
[]
```
Tasks with empty validators can be completed by simply clicking a checkbox.

### 2. Single Validator List with Checklist
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

### 3. Single Validator List with Single Select
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

### 4. Single Validator List with Free Field
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

### 5. Single Validator List with File Validator
```json
[
  [
    {
      "id": "file-001",
      "type": "file",
      "required": true,
      "title": "Upload documentation",
      "files": [],
      "encryptionKey": "a3f8b2e1c4d5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1",
      "helper": "Please upload the required documentation files"
    }
  ]
]
```

### 6. Complex Multi-Validator List
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

### 7. Multiple Validator Lists
```json
[
  [
    {
      "id": "checklist-001",
      "type": "checklist",
      "required": true,
      "title": "Technical requirements",
      "items": [
        {"id": "item-1", "text": "API integration tested", "checked": false},
        {"id": "item-2", "text": "Database migration completed", "checked": false}
      ]
    }
  ],
  [
    {
      "id": "select-002",
      "type": "single_select",
      "required": true,
      "title": "Approval status",
      "options": [
        {"id": "pending", "text": "Pending Review"},
        {"id": "approved", "text": "Approved"},
        {"id": "rejected", "text": "Rejected"}
      ],
      "selected": ""
    }
  ]
]
```

## Validation Rules

### JSON Schema Compliance
- All validator objects must conform to the defined schema
- Required fields must be present
- Field types must match schema definitions

### ID Uniqueness
- All validator IDs must be unique within the task
- All option IDs must be unique within their validator
- All checklist item IDs must be unique within their validator

### State Consistency
- `selected` values must match existing option IDs or be empty
- `checked` values must be boolean
- `required` values must be boolean

## UI Implementation Guidelines

### Checklist Rendering
- Display each item as a checkbox with text
- Check state persisted immediately on change
- Visual indication of completion progress

### Single Select Rendering
- Display as radio buttons, dropdown, or segmented control
- Only one option selectable at a time
- Clear indication of current selection

### Free Field Rendering
- Display as text input field
- Show helper text when provided
- Real-time validation for required fields

### File Validator Rendering
- Display file upload interface with drag-and-drop support
- Show list of uploaded files with download/delete actions
- Display file metadata (name, size, upload date)
- Show helper text when provided
- Indicate encryption status for security

### Completion Status
- Show overall progress across all validator lists
- Indicate which validators are required vs optional
- Prevent task completion if required validators incomplete

## Error Handling

### Invalid Schema
- Gracefully handle malformed validator JSON
- Fallback to simple checkbox completion
- Log errors for debugging

### Missing References
- Handle missing option IDs in selected values
- Reset to empty state if invalid reference found
- Preserve other valid state

### Migration Support
- Support schema evolution
- Handle unknown validator types gracefully
- Preserve data during upgrades

---
*For complete data model information, see [DATA_MODEL_SPECIFICATION.md](DATA_MODEL_SPECIFICATION.md)*
*Last updated: 2024-12-19* 