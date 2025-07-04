# FlowIt Documentation

Welcome to the FlowIt project documentation. This directory contains comprehensive documentation covering architecture, implementation, and usage guidelines for the FlowIt task management application.

## 📋 Documentation Overview

FlowIt is a cross-platform task management application built with Flutter that uses CalDAV for synchronization. The documentation is organized into several key areas:

## 🏗️ Architecture & Design

### Core Architecture
- **[Architecture Overview](ARCHITECTURE_OVERVIEW.md)** - Fundamental principles, project goals, and high-level architecture patterns
- **[Data Model Specification](DATA_MODEL_SPECIFICATION.md)** - Complete specification of VTODO objects, CalDAV integration, and FlowIt extensions
- **[FlowIt Types Reference](FLOWIT_TYPES_REFERENCE.md)** - Detailed reference for all FlowIt object types (tasks, projects, domains)

### Technical Specifications
- **[Validator Schema](VALIDATOR_SCHEMA.md)** - JSON schema and implementation details for task validators
- **[Domain WebDAV Implementation](DOMAIN_WEBDAV_IMPLEMENTATION.md)** - Technical details for domain organization via WebDAV properties

## 🎨 User Interface & Design

### Design Guidelines
- **[UI Design Guidelines](UI_DESIGN_GUIDELINES.md)** - Material Design 3 principles, iconography, and component guidelines
- **[Typography Usage](TYPOGRAPHY_USAGE.md)** - Font system, button styling, and typography implementation
- **[Adaptive Navigation](ADAPTIVE_NAVIGATION.md)** - Responsive navigation patterns for desktop and mobile

### Component Documentation
- **[Create Task Button Examples](CREATE_TASK_BUTTON_EXAMPLES.md)** - Implementation examples for task creation components

## ⚙️ Implementation & Development

### Development Guides
- **[Implementation Guide](IMPLEMENTATION_GUIDE.md)** - Practical implementation details for local storage, sync, and UI patterns

### Feature Documentation
- **[Move Task Feature](MOVE_TASK_FEATURE.md)** - Task movement and project reassignment functionality
- **[Custom Calendar Names](CUSTOM_CALENDAR_NAMES.md)** - Calendar naming and management features

## 🧪 Testing & Quality

### Testing Documentation
- **[Tests Summary](TESTS_SUMMARY.md)** - Overview of testing strategy and test coverage

### Debug & Troubleshooting
- **[Calendar Creation Debug](CALENDAR_CREATION_DEBUG.md)** - Debugging guide for calendar creation issues

## 📚 Change Documentation

### UI & UX Changes
- **[UI Terminology Change](UI_TERMINOLOGY_CHANGE.md)** - Documentation of terminology updates and UI text changes

## 🗂️ Documentation Categories

### By Development Phase
- **Planning & Architecture**: Architecture Overview, Data Model Specification, FlowIt Types Reference
- **Implementation**: Implementation Guide, UI Design Guidelines, Component Documentation
- **Testing & Deployment**: Tests Summary, Debug Guides
- **Maintenance**: Change Documentation, Feature Updates

### By Audience
- **Developers**: Architecture Overview, Implementation Guide, Technical Specifications
- **UI/UX Designers**: UI Design Guidelines, Typography Usage, Adaptive Navigation
- **QA Engineers**: Tests Summary, Debug Guides
- **Product Managers**: Architecture Overview, Feature Documentation

## 🔄 Quick Navigation

### Core Concepts
1. Start with [Architecture Overview](ARCHITECTURE_OVERVIEW.md) for project understanding
2. Review [Data Model Specification](DATA_MODEL_SPECIFICATION.md) for technical foundation
3. Explore [UI Design Guidelines](UI_DESIGN_GUIDELINES.md) for interface standards

### Implementation Workflow
1. [Implementation Guide](IMPLEMENTATION_GUIDE.md) - Technical implementation patterns
2. [FlowIt Types Reference](FLOWIT_TYPES_REFERENCE.md) - Object type specifications
3. [Validator Schema](VALIDATOR_SCHEMA.md) - Task validation system
4. Component-specific documentation for UI implementation

### Integration & Deployment
1. [Domain WebDAV Implementation](DOMAIN_WEBDAV_IMPLEMENTATION.md) - Server integration
2. [Adaptive Navigation](ADAPTIVE_NAVIGATION.md) - Cross-platform UI
3. [Tests Summary](TESTS_SUMMARY.md) - Quality assurance

## 📖 Reading Guide

### For New Team Members
1. **[Architecture Overview](ARCHITECTURE_OVERVIEW.md)** - Understand FlowIt's core principles and goals
2. **[UI Design Guidelines](UI_DESIGN_GUIDELINES.md)** - Learn the design system and UI standards
3. **[Implementation Guide](IMPLEMENTATION_GUIDE.md)** - Get practical development guidance

### For Feature Development
1. **[Data Model Specification](DATA_MODEL_SPECIFICATION.md)** - Understand data structures
2. **[FlowIt Types Reference](FLOWIT_TYPES_REFERENCE.md)** - Reference for object types
3. **[Validator Schema](VALIDATOR_SCHEMA.md)** - Task validation implementation
4. Specific feature documentation as needed

### For UI/UX Work
1. **[UI Design Guidelines](UI_DESIGN_GUIDELINES.md)** - Design principles and patterns
2. **[Typography Usage](TYPOGRAPHY_USAGE.md)** - Font and text styling
3. **[Adaptive Navigation](ADAPTIVE_NAVIGATION.md)** - Navigation patterns
4. **[Create Task Button Examples](CREATE_TASK_BUTTON_EXAMPLES.md)** - Component examples

## 🔗 Related Resources

### External References
- [Material Design 3 Guidelines](https://m3.material.io/)
- [Flutter Documentation](https://docs.flutter.dev/)
- [CalDAV RFC 4791](https://tools.ietf.org/html/rfc4791)
- [iCalendar RFC 5545](https://tools.ietf.org/html/rfc5545)

### Project Resources
- Main codebase: `lib/` directory
- Tests: `test/` directory
- Assets: `assets/` directory
- Project specifications: `specs.md` (root directory)

## 📝 Contributing to Documentation

When updating documentation:
1. Keep cross-references updated between related documents
2. Include practical examples and code snippets
3. Update the last modified date at the bottom of each document
4. Ensure consistency with project terminology and naming conventions

---
*Documentation index last updated: 2024-12-19*
*FlowIt Project Documentation v1.0* 