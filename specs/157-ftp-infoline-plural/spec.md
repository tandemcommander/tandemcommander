# Feature Specification: the FTP client's information line in languages with accents

**Feature Branch**: `157-ftp-infoline-plural`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` 10a (found by 156's review).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The information line reads correctly (Priority: P1)

An FTP panel with a size-in-bytes column, several files selected, a translated UI: the
information line reads "12 345 bajtů v 3 vybraných souborech" whole (it showed "bajt? v 3
vybran?ch souborech").

**Independent Test**: by reading (the information line exposes no text to a probe); a person
looks at it once with an FTP server.

## Requirements *(mandatory)*

- **FR-001**: `ExpandPluralBytesFilesDirs` for plug-ins returns UTF-8 (contract
  `contracts/expand-plural-bytes-utf8.md`); interface version unchanged.
