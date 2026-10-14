# Feature Specification: the "N files" texts of a selection in languages with accents

**Feature Branch**: `156-drag-image-text`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: a user report for 0.1.9 (the maintainer, 2026-10-14): "when I drag and drop several
files, Czech shows 'vybrané 2 soubory', but the 'é' is not shown - a question mark instead."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The selection's description reads correctly (Priority: P1)

With a translated UI, dragging several selected items shows "vybrané 2 soubory" whole; the
Copy-from-archive, Delete-from-archive and Pack dialogs for several items show their sentence
whole ("Kopírovat 5 souborů z archivu do").

**Independent Test**: `probe/plural_text_probe.ps1` (Czech UI; the dialogs' texts read back). The
drag image needs a real mouse drag - a step for a person.

## Requirements *(mandatory)*

- **FR-001**: The selection's plural text MUST be built in the encoding of the text it is drawn
  with or put into (UTF-8 at these three sites).
- **FR-002**: No string, interface or registry change.

## Success Criteria *(mandatory)*

- **SC-001**: The pack and unpack rows fail on the build before and pass on the fix; the controls
  pass on both.
