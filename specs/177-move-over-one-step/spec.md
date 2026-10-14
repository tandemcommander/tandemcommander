# Feature Specification: F6 Move onto an existing file

**Feature Branch**: `177-move-over-one-step`
**Created**: 2026-10-15
**Status**: Closed by measurement - see fix-log.md (no code change)
**Input**: NEXT-WORK item 5h.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P2)

A user moves a file onto an existing one and agrees to replace it; if the move cannot happen, the
existing file stays.

## Requirements *(mandatory)*

- **FR-001**: measure whether a failed move can follow the deletion of the target.

## Success Criteria *(mandatory)*

- **SC-001**: `probe/move_over_probe.ps1` - the target kept when the source cannot be moved.
