# Feature Specification: the Registry Editor's Find refuses input that does not fit

**Feature Branch**: `191-regedt-find-input`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a time field of any length is checked without overrunning anything; a wrong one
  gets the "bad format" message.
- **FR-002**: a hex pattern (or a plain one in the code page) longer than the search can keep is
  refused with a message - never written past its buffer, never cut.
