# Feature Specification: a folder named with %...% is opened as it is

**Feature Branch**: `238-literal-percent-paths`
**Created**: 2026-10-16
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: a path given on the command line or typed (pasted, dropped) whose part up to the last
  '%' component exists as written is opened as written - never another folder the expansion names.
- **FR-002**: a path that does not exist as written still has its %VAR% expanded; a relative path
  that starts with a defined variable is the variable.
