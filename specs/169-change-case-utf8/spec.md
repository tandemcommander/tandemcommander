# Feature Specification: Change Case renames accented names correctly

**Feature Branch**: `169-change-case-utf8`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 19, B-4 (068 F-P5-13): AlterFileName byte-folds UTF-8 names;
it drives Change Case, which renames files on disk.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user selects files with Czech, Greek or Cyrillic names and runs Change Case (lower, upper,
mixed, partially mixed): every file gets exactly its name in the chosen case - never an error,
never a different name.

### User Story 2 (Priority: P2)

With the panel's name format option the names are shown in that case, whole letters.

## Requirements *(mandatory)*

- **FR-001**: whole Unicode letters, the file system's (invariant) mapping; a letter whose case
  pair has another UTF-8 length stays; the name keeps its byte length.
- **FR-002**: ASCII behaviour byte for byte as before; no string, interface or registry change.
