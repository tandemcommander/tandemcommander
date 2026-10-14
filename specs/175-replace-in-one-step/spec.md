# Feature Specification: Convert and Quick Rename replace an existing file in one step

**Feature Branch**: `175-replace-in-one-step`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: NEXT-WORK items 5f and 5g.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user converts files (end of line, code page) in place: each file holds the converted content and
keeps what it had (streams, permissions); a file that cannot be replaced stays as it was.

### User Story 2 (Priority: P2)

A user renames a file onto an existing one and agrees to replace it: the replace happens in one
step, or nothing changes.

## Requirements *(mandatory)*

- **FR-001**: Convert replaces through a complete, flushed temporary file (rule 105).
- **FR-002**: Quick Rename replaces with one rename that replaces the target.
- **FR-003**: no string, interface or registry change.

## Success Criteria *(mandatory)*

- **SC-001**: `probe/replace_probe.ps1` 8 / 0 after; CONV-PLAIN fails before.
