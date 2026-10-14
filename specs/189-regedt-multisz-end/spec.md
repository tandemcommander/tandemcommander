# Feature Specification: the end of a Registry Editor text value

**Feature Branch**: `189-regedt-multisz-end`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a `REG_MULTI_SZ` list is shown as its strings separated by spaces whatever the
  number of NULs at its end (one, two, more, none) - no trailing space.
- **FR-002**: the Find window shows a text value stored without its terminator (or with an odd
  byte count) as that text - nothing read past the end of its copy.
