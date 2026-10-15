# Feature Specification: a menu hot key never splits a UTF-8 letter

**Feature Branch**: `236-menu-hotkeys-utf8`
**Created**: 2026-10-16
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a hot key the program gives a popup item is an ASCII letter of its text; never a byte
  inside a UTF-8 character.
- **FR-002**: "&&" is a literal '&', not a hot key.
