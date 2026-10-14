# Feature Specification: Pack with "Overwrite" keeps the old archive until the new one exists

**Feature Branch**: `176-pack-overwrite-safe`
**Created**: 2026-10-15
**Status**: Implemented - see fix-log.md
**Input**: NEXT-WORK item 5i.

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user packs files into an archive name that exists and chooses Overwrite. If the pack fails or is
cancelled, the old archive is still there; if it succeeds, the new archive replaces it.

## Requirements *(mandatory)*

- **FR-001**: the old archive is not deleted before the new one was made.
- **FR-002**: a failed or cancelled pack leaves the old archive in its place and nothing else.
- **FR-003**: no string, interface or registry change.

## Success Criteria *(mandatory)*

- **SC-001**: `probe/overwrite_probe.ps1` 12 / 0 after; the fail rows fail before.
