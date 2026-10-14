# Feature Specification: the core's code-page file dialogs

**Feature Branch**: `172-core-save-dialogs`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: NEXT-WORK item 19 ("configuration export's start folder"), widened by measuring.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user exports the configuration, copies a part of a viewed file to a file, or opens another file
in the viewer, and types or picks a name with accented or non-Latin letters (or a folder with
them). The file is saved / opened under exactly that name.

### User Story 2 (Priority: P2)

A user picks a program or a folder with *Browse...* in the configuration; the field shows exactly
the chosen path, or a refusal when it does not fit the field - never a cut or garbled path.

## Requirements *(mandatory)*

- **FR-001**: the core's file dialogs are wide; the names they return are UTF-8 for the core.
- **FR-002**: a name the target field cannot hold is refused (`IDS_TOOLONGPATH`), never cut.
- **FR-003**: no string, interface or registry change.

## Success Criteria *(mandatory)*

- **SC-001**: `probe/save_dialogs_probe.ps1` 26 / 0 after, with failures before (negative control).
