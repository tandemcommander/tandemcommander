# Feature Specification: Rename and Move never offer the file of a short-name clash for overwriting

**Feature Branch**: `201-short-name-clash-held`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: renaming or moving a file to a name that is only another file's short (8.3) name
  never offers that other file for overwriting - when it cannot be moved aside (held open), the
  error is reported and nothing is replaced.
