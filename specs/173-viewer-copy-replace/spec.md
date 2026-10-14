# Feature Specification: the viewer's Copy to File replaces an existing file in one step

**Feature Branch**: `173-viewer-copy-replace`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: NEXT-WORK item 5c (found by 172's review).

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

A user copies (a part of) a viewed file onto an existing file and agrees to replace it. Afterwards
the file holds the new content and keeps what it was (attributes, permissions) - or, when the
replace is impossible, it is exactly as before and the user is told why. It is never gone.

## Requirements *(mandatory)*

- **FR-001**: the new content is complete on disk before it takes the target's place, in one step
  (rule 105, `SalReplaceWithTempW`).
- **FR-002**: if the target is gone and the new content is only in the temporary file, that file
  is kept and named in the message.

## Success Criteria *(mandatory)*

- **SC-001**: `probe/copy_replace_probe.ps1` - every row PASS after; KEPT fails before.
