# Feature Specification: a name is as long as a Windows file system allows

**Feature Branch**: `222-name-length-units`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: an archive whose member's name has up to 255 UTF-16 units (also more than 255 bytes
  of UTF-8) opens, and the member can be extracted under its whole name.
- **FR-002**: such a name is valid; a name is shortened only at a whole character.
- **FR-003**: an item refused for its length is skipped, the rest of the listing shown.
