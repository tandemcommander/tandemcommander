# Feature Specification: Quick Rename and Move prove another file by the temporary name

**Feature Branch**: `198-rename-proof-temp-name`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: when a rename or move to the source's name in another case finds "already exists",
  the existing target is overwritten only after the temporary-name route proved it another file
  (the target outlived the source's name) - never on different file ids alone.
