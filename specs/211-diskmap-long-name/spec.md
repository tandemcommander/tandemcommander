# Feature Specification: Disk Map never hands the shell another item's path

**Feature Branch**: `211-diskmap-long-name`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: the shell menu, the default command and "Focus in Panel" of a Disk Map item act on
  that item or not at all - never on its folder or another item; an item whose name does not fit
  is refused (a beep).
- **FR-002**: names go to the shell as UTF-16 converted from UTF-8 / WTF-8, never through the code
  page.
