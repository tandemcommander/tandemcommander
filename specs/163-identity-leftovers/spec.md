# Feature Specification: a long name stays selected after a dialog; small identity leftovers

**Feature Branch**: `163-identity-leftovers`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 14: "`UnselectItemWithName` (linguistic comparison + byte-length
guard), `CFindIgnore::Contains` relative kind, Undelete's `ViewFile` disk-cache key dropping a long
name." Measuring the first found a worse defect next to it: the name it compares was cut.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - the item a dialog selected is unselected again (Priority: P1)

Nothing is selected, the focus is on a file whose UTF-8 name has 260 bytes or more (e.g. 140
Czech letters with a caron). The user opens Quick Rename, Change Attributes or Change Case (also
Pack, Email, Convert, a plug-in's Quick Rename) - the command selects the focused item for its
time - and cancels. The item must not stay selected: before, it did, and the next Delete with the
focus on another file asked to delete - and would have deleted - the long-named file.

**Independent Test**: `probe/temp_selection_probe.ps1` - the Delete question after each command
names the focused file alone (a short UTF-8 name as the control).

### User Story 2 - Find's ignore list by the file system's rule (Priority: P2)

A relative entry ("Účty") ignores the folders of that name in any case ("účty"), and not another
folder whose UTF-8 bytes fold into it on the code page (U+0125 / U+0139, U+011A / U+010A).

**Independent Test**: saltests `TestFindIgnore163` (`src/common/salfindignore.h`).

### User Story 3 - Undelete's view cache key holds the whole name (Priority: P3)

Viewing a deleted file in a deep folder uses a disk-cache key with its name (it was dropped).

**Independent Test**: by reading (the buffer is sized for the maxima and refuses instead of cutting).

## Requirements *(mandatory)*

- **FR-001**: The temporarily selected name is kept whole (heap); a name is never cut.
- **FR-002**: The comparisons follow feature 092 (`SalNameEqualOrdinalCI`,
  `SalPathHasPrefixOrdinalCI`); the exact name is still preferred; no byte-length guard.
- **FR-003**: No string, interface or registry change.
