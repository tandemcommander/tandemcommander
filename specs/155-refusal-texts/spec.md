# Feature Specification: refusal texts that say what is refused

**Feature Branch**: `155-refusal-texts`
**Created**: 2026-10-14
**Status**: Implemented - see fix-log.md
**Input**: `specs/NEXT-WORK.md` item 10: "a refused folder copy says 'Cannot copy a file to itself.'
and a move into its own subfolder 'Cannot move a directory to itself.' (107); the pack-into-itself
refusal does not say that deselecting helps (119); the Renamer says 'already exists' (103, 107)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The refusal names the real reason (Priority: P1)

A user copies or moves a folder onto itself or into one of its own subfolders, packs an archive
that is part of the selection into itself, or renames (Renamer) a link onto the file it points
at. The refusal says exactly that, and for the pack how to go on.

**Independent Test**: `probe/refusal_texts_probe.ps1` (107's and 119's probes for the shapes,
their box texts checked; a Renamer row).

**Acceptance Scenarios**:

1. A folder copied onto itself: "Cannot copy a directory to itself."
2. A folder moved into itself or into one of its subfolders: "Cannot move a directory into itself
   or into one of its subdirectories."; moved onto itself: "Cannot move a directory to itself."
3. A pack into an archive that is selected (or lies in a selected folder): "Cannot pack an archive
   into itself. Leave the archive (or the directory that contains it) out of the selection." (the
   box names the archive).
4. The Renamer: a link renamed onto its target "Cannot move a file to itself."; a copy onto
   itself (a rename into another root through an alias) "Cannot copy a file to itself."

## Requirements *(mandatory)*

- **FR-001**: The texts as above; nothing else about the refusals changes (what is refused, the
  buttons) - except that an empty folder copied onto itself by name is refused now too (before:
  nothing happened, nothing said).
- **FR-002**: The strings in free slots of existing bundles, translated (formal register), the
  Renamer's two with the core's existing translations of the same sentences.

## Success Criteria *(mandatory)*

- **SC-001**: The probe's changed rows fail on the build before and pass on the fix; the
  unchanged rows pass on both.
- **SC-002**: 107, 119 and 103's probes unchanged in what they protect.
