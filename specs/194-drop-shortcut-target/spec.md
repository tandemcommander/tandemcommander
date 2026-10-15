# Feature Specification: dropping onto a shortcut follows a target of any length

**Feature Branch**: `194-drop-shortcut-target`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: dragging files onto a shortcut in a panel reads the shortcut whole (its own name of
  any length) and goes to its target whatever its length; a target that cannot be read whole is
  not followed (never a cut one).
