# FlowIt UI Design Guidelines

## Overview

FlowIt follows Material Design 3 principles with adaptive layouts that work seamlessly across desktop and mobile platforms. The UI emphasizes consistency, accessibility, and cross-platform compatibility.

## Design Principles

### Material Design 3 Compliance
- Use Flutter's Material components (AppBar, NavigationDrawer, FloatingActionButton, etc.)
- Maintain consistent color schemes, typography, and shape theming via shared ThemeData
- Follow Material Design 3 guidelines for spacing, elevation, and interaction patterns

### Responsive Layout Strategy
- **Desktop (≥ 800px)**: Left sidebar for navigation, main panel for content
- **Mobile (< 800px)**: Single column layout with top app bar or bottom navigation; sidebar becomes slide-out drawer
- Adaptive components that transform based on screen size and platform capabilities

### Consistency Standards
- Unified component library across all screens
- Standardized spacing, colors, and typography
- Consistent interaction patterns and navigation flows

## Layout Patterns

### Desktop Layout
- **Left Sidebar**: 280px width for navigation (projects, groups, tasks)
- **Main Content Area**: Flexible width for task lists, editors, and detail views
- **Persistent Navigation**: Always-visible sidebar for quick project switching
- **Multi-Panel Views**: Support for split-screen workflows where appropriate

### Mobile Layout
- **Slide-out Drawer**: Navigation accessible via hamburger menu
- **Single Column**: Focus on current content with full-screen utilization
- **Bottom Navigation**: For primary app sections (when applicable)
- **Contextual App Bars**: Dynamic titles and actions based on current screen

### Adaptive Components
- Navigation components that transform between sidebar and drawer
- Responsive card layouts that stack on mobile, flow on desktop
- Contextual action buttons that adapt to available space

## Iconography System

### Task Indicators

| Element | Material Icon | Color | Usage |
|---------|---------------|-------|-------|
| Has validators | `fact_check` | `colorScheme.primary` | Task has configured validators |
| Attendees (single) | `person_rounded` | `colorScheme.secondary` | Single attendee assigned |
| Attendees (multiple) | `group` | `colorScheme.secondary` | Multiple attendees assigned |
| Categories | `label_rounded` | `colorScheme.tertiary` | Task belongs to categories |

### Due Date Status

| Status | Material Icon | Color | Usage |
|--------|---------------|-------|-------|
| Overdue | `warning_rounded` | `Colors.red.shade600` | Past due date |
| Normal due date | None | `colorScheme.primary` | Future due date |

### Task Actions

| Action | Material Icon | Color | Usage |
|--------|---------------|-------|-------|
| Set due date | `calendar_today_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Date picker |
| Set validator | `fact_check` | `colorScheme.onSurface.withOpacity(0.6)` | Configure validation |
| Add attendee | `person_add_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Assign attendee |
| Add category | `label_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Assign category |
| Move task | `drive_file_move_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Change project |
| Delete task | `delete_rounded` | `colorScheme.error` | Permanent deletion |
| Archive task | `archive` | `colorScheme.onSurface.withOpacity(0.6)` | Archive action |
| Add GPS | `pin_drop` | `colorScheme.onSurface.withOpacity(0.6)` | Location data |
| Debug info | `info_rounded` | `colorScheme.onSurface.withOpacity(0.6)` | Debug mode only |

### Navigation Icons

| Element | Material Icon | Usage |
|---------|---------------|-------|
| Expand/Collapse | `expand_more_rounded` / `expand_less_rounded` | Toggle detail views |
| Project expand | `expand_more_rounded` / `expand_less_rounded` | Toggle project details |

## Tab Bar Systems

### My Tasks Tab Bar

| Tab | Material Icon | Purpose |
|-----|---------------|---------|
| Today | `today_rounded` | Tasks due today |
| Soon | `schedule_rounded` | Tasks due within a week |
| Later | `event_rounded` | Tasks due later than a week |
| Anytime | `layers_rounded` | Tasks without due dates |

### Project Detail Tab Bar

| Tab | Material Icon | Purpose |
|-----|---------------|---------|
| List | `checklist_rounded` | Task list view |
| Timing | `schedule_rounded` | Tasks by due date |
| Attendee | `groups` | Tasks by attendees |
| Kanban | `view_kanban_rounded` | Kanban board view |
| Agenda | `calendar_month_rounded` | Calendar/agenda view |

## Size Conventions

| Context | Size (px) | Usage |
|---------|-----------|-------|
| Task indicators | 16 | Status icons in main line |
| Task actions | 20 | Action buttons in expanded section |
| Date badge warning | 10 | Alert icon in date badge |
| Navigation icons | 18-20 | Navigation buttons and UI controls |

## Color System

### Material Design 3 Colors
Colors use Material Design 3 color system via `Theme.of(context).colorScheme`:

- **Primary**: Main actions and validators
- **Secondary**: Attendees and collaboration features
- **Tertiary**: Categories and classification
- **Error**: Destructive actions and warnings
- **OnSurface + Opacity**: Neutral actions and UI controls

### Task Status Colors
- **Completed**: Success color (typically green)
- **In Progress**: Primary color
- **Overdue**: Error color (red)
- **Not Started**: Neutral color

## Typography System

### Font Hierarchy
- **Primary Font**: Roboto Flex via Google Fonts
- **Fallbacks**: Roboto → Noto Sans → system-ui → sans-serif
- **Domain Names**: Roboto Serif (Thin, weight: 100)
- **Primary Buttons**: Capitalized Roboto Flex (weight: 600, letter-spacing: 1.25px)

### Usage Guidelines
- Domain names use elegant thin serif font
- Button text automatically capitalized
- Consistent font weights across components
- Proper fallbacks for offline scenarios

*For detailed typography implementation, see [TYPOGRAPHY_USAGE.md](TYPOGRAPHY_USAGE.md)*

## Component Guidelines

### Notion-Like Editor
- Rich text area supporting Markdown in DESCRIPTION field
- Slash commands for inserting special blocks or references
- Consistent with Material Design input field styling
- Support for common formatting (bold, italic, lists, headers)

### Task Views and Organization
- **"Today"** and **"Soon"** lists highlight tasks by due date priority
- **"Unregistered"** shows tasks missing project or due date
- **Project Detail** screens show tasks, groups, and sub-items in organized layout
- Kanban boards for visual project management (future implementation)

### Validator Rendering
- **Checklists**: Material checkbox components with proper state management
- **Single Selects**: Radio buttons, dropdown, or segmented control depending on context
- **Free Fields**: Material text input fields with helper text support
- Progress indicators showing validator completion status

### Category Management
- **Category Chips**: Visual representation as colored Material chips
- **Category Dialog**: Dedicated UI for managing task and project categories
- Consistent color coding and organization

## Interaction Patterns

### Optimistic UI Updates
- Immediate visual feedback for all user actions
- Loading states for background sync operations
- Clear indication of sync status and conflicts

### Navigation Flow
- Consistent back button behavior
- Breadcrumb navigation for deep hierarchies
- Context-aware action buttons in app bars

### Responsive Interactions
- Touch-friendly tap targets on mobile (minimum 44px)
- Hover states for desktop interactions
- Keyboard navigation support for accessibility

## Accessibility Guidelines

### Color and Contrast
- Maintain Material Design 3 contrast ratios
- Support for high contrast modes
- No color-only information conveying

### Interaction Support
- Minimum touch target sizes
- Screen reader compatibility
- Keyboard navigation support
- Focus management for complex UI

### Text and Content
- Scalable text sizes
- Clear information hierarchy
- Alternative text for icons and images

## Error Handling UI

### Graceful Degradation
- Clear messaging when features unavailable
- Offline mode indicators
- Sync status communication

### Error Communication
- Non-blocking error messages
- Contextual help and guidance
- Recovery action suggestions

## Future Considerations

### Extensibility
- Component system designed for new feature addition
- Consistent theming for custom components
- Plugin architecture consideration in UI design

### Performance
- Efficient rendering for large task lists
- Lazy loading for complex views
- Smooth animations and transitions

---
*For implementation-specific navigation details, see [ADAPTIVE_NAVIGATION.md](ADAPTIVE_NAVIGATION.md)*
*For typography implementation, see [TYPOGRAPHY_USAGE.md](TYPOGRAPHY_USAGE.md)*
*Last updated: 2024-12-19* 