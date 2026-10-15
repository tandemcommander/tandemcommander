# Feature Specification: removing a temporary folder never goes through a link

**Feature Branch**: `212-temp-dir-links`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: removing a temporary folder (and the empty folders of a failed unpack) never walks
  into a junction, a directory symbolic link or another directory link - only the link itself is
  removed; the files and folders of its target are untouched.
- **FR-002**: a link that cannot be told apart from a folder counts as a link (fail closed); a
  cloud placeholder is still a folder.
