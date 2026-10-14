# Feature Specification: the plug-in service "show this file in a panel" keeps a long folder whole

**Feature Branch**: `150-focus-name-long-folder`
**Created**: 2026-10-14
**Status**: Implemented - GUI verified (probe F1 PASS, control FAIL)
**Input**: `specs/NEXT-WORK.md` 5a - found by the review of feature 149: "the core copies the folder
and the name into `MAX_PATH + 200` buffers with `lstrcpyn` - Focus of a file in a folder of 460-779
bytes changes to a CUT folder, possibly another one."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Focus from a plug-in reaches the file (Priority: P1)

**Independent Test**: probe `probe/focus_long_folder_probe.ps1` row F1 - Checksum Verify, Focus on a
file in a 589-byte folder: the panel opens that folder, no box.

## Requirements *(mandatory)*

- **FR-001**: `FocusNameInPanel` MUST hand the panel the whole path and name; a name longer than any
  file name (the panel's `NextFocusName`) is refused, never cut.
- **FR-002**: No interface change, no string, no registry value.

## Success Criteria *(mandatory)*

- **SC-001**: F1 FAIL before (measured: "Error Changing Directory" with the cut path), PASS after.
