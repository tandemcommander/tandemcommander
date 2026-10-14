# Feature Specification: drop and paste into an archive with a long name

**Feature Branch**: `160-drop-into-long-archive`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 12 (097): "An archive whose name has 260+ bytes: clipboard copy
from it and drop/paste into it are refused (the two fields are process-internal and could be
widened)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 (Priority: P1)

Files dropped (or pasted) into an archive panel whose archive's full name is 260+ bytes are
packed into it, as for any other archive the plug-in handles at that length (since 097).

**Independent Test**: not drivable here (an OLE drag, a clipboard paste) - by reading; a person
step.

## Requirements *(mandatory)*

- **FR-001**: The archive's name is carried whole; the path inside the archive stays refused at
  260+ bytes (097: the listing structure is shared with plug-ins); no name is ever cut.
- **FR-002**: Clipboard copy FROM an archive: not changed - unreachable in the product (it needs
  the shell extension, which is not shipped, 083).
