# Feature Specification: "Include subdirectories" lists a renamed folder's own contents

**Feature Branch**: `209-renamer-subdir-reload`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md

## Requirements *(mandatory)*

- **FR-001**: after a rename (file-name, relative- or full-path mode, and after Undo), ticking
  "Include subdirectories" lists the files of each folder item where that folder IS; never a
  folder of its name elsewhere, never a path relative to the current folder.
