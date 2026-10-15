# Feature Specification: Change Attributes / Change Case / Convert never reach a link's target

**Feature Branch**: `213-attrs-case-links`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: Change Attributes, Change Case and Convert with "Include subdirectories" never change
  a file reached through a junction, a directory symbolic link or another directory link (outside
  the selection); the link's own entry may change.
- **FR-002**: a link that cannot be told apart from a folder counts as a link (fail closed, as
  Delete); a cloud placeholder is still a folder.
