# Feature Specification: the program starts from any install folder

**Feature Branch**: `170-install-path-unicode`
**Created**: 2026-10-14
**Status**: Implemented (start, language, plug-in loading) - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 19, the install-path chain (151's review).

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user installs the program per user, and their profile folder has letters outside the system's
code page (Cyrillic, Chinese, ...). The program starts, in its language, with every plug-in -
also at the first start after an update, which registers new plug-ins and drops removed ones.

### User Story 2 (Priority: P2)

Plugins > Add takes a plug-in from such a folder.

## Requirements *(mandatory)*

- **FR-001**: the program's own files are addressed by UTF-8 paths and opened wide; a path that
  does not fit is refused, never cut; a plug-in whose file cannot be checked is never removed.
- **FR-002**: no string, interface or registry change.
