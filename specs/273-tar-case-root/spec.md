# Feature Specification: A folder inside an archive opened in another case is entered under the archive's own spelling

**Feature Branch**: `273-tar-case-root`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item `copying-from-a-tar-folder-opened-in-another-case-extracts` - "Copying from a
TAR folder opened in another case extracts nothing". From backlog item copying-from-a-tar-folder-opened-in-another-case-extracts.

## Background (measured at ff3cd942)

A user can open a folder inside an archive by typing its path - on the command line, in Change
Directory (Shift+F7), from a hot path or the history. When the archive has no names that differ
only in case (feature 252), the program finds the folder ignoring case: `t.tar\DOCS` opens the
folder the archive spells `Docs`. But the panel keeps the typed spelling `DOCS` as its current
path inside the archive, and this path is what every archive plug-in receives as the folder the
selected items live in.

The TAR plug-in builds the names it extracts from that folder and the selected names
(`DOCS\f.txt`) and looks them up in the archive byte for byte (`Docs\f.txt`): nothing matches,
nothing is extracted and no error is shown. Copy (F5) says "Copy file f.txt" and the target
folder stays empty. The 7-Zip plug-in extracts by item and copies the file. Measured with a
hidden-desktop probe on the build of ff3cd942: TAR `t.tar\DOCS` and `t.tar\dOCS\SUB` - target
empty; 7z - the file arrives; archives holding the case twins `Docs` and `DOCS` - the typed `DOCS`
is the exact folder and copying works.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Copy from a TAR folder opened in another case extracts the files (Priority: P1)

A user opens `<archive.tar>\DOCS` (the archive spells the folder `Docs`) from the command line,
Change Directory or a hot path, selects the files and copies them out with F5.

**Why this priority**: today the copy silently does nothing; the user believes the files were
copied.

**Independent Test**: a hidden-desktop probe: a TAR holding `Docs\f.txt` and `z.txt`, the left
panel started at `<archive>\DOCS`, Select All, Copy into an empty folder - `f.txt` arrives with
its content.

**Acceptance Scenarios**:

1. **Given** a TAR archive holding `Docs\f.txt`, **When** the panel is opened at `<archive>\DOCS`
   and its files are copied, **Then** `f.txt` arrives in the target with its content.
2. **Given** a TAR archive holding `Docs\Sub\g.txt`, **When** the panel is opened at
   `<archive>\dOCS\SUB`, **Then** copying extracts `g.txt`.

### User Story 2 - The panel shows the folder under the archive's own spelling (Priority: P1)

After entering a folder of an archive by a path typed in another case, the panel's path (directory
line, Change Directory field, history) names the folder as the archive spells it - `Docs`, not
`DOCS` - so every operation on the folder (extract, view, pack into, delete from) works with the
archive's real names, for every archive plug-in.

**Why this priority**: it is the single place that fixes the TAR extraction and gives every other
archive plug-in the folder's real name.

**Independent Test**: the same probe reads the panel path (Change Directory field) after the start
- it ends in `\Docs` (`\Docs\Sub` for the deep row), for TAR and 7z.

**Acceptance Scenarios**:

1. **Given** a TAR or 7z archive holding the folder `Docs`, **When** the panel is opened at
   `<archive>\DOCS`, **Then** the panel path ends in `<archive>\Docs`.
2. **Given** an archive holding `Docs\Sub`, **When** it is opened at `<archive>\dOCS\SUB`,
   **Then** the panel path ends in `<archive>\Docs\Sub`.

### User Story 3 - Archives with case twins behave as before (Priority: P1)

**Independent Test**: a TAR / 7z archive holding the folders `Docs` and `DOCS` (case twins - the
listing is case-sensitive since feature 252) opened at `<archive>\DOCS`: the panel is in `DOCS`,
copying extracts only `DOCS`'s file.

**Acceptance Scenarios**:

1. **Given** an archive holding the folders `Docs\f.txt` and `DOCS\g.txt`, **When** it is opened
   at `<archive>\DOCS` and its files are copied, **Then** the panel path ends in `\DOCS` and only
   `g.txt` arrives.

### Edge Cases

- The typed path names a folder that does not exist (`<archive>\DOCS\nothing`): the path is
  shortened to the part that exists, as before; that part is shown under the archive's spelling.
- The typed path already matches the archive's spelling (Enter on a folder, a refresh): unchanged.
- The archive root (an empty path inside the archive): unchanged.
- A case-sensitive listing (case twins): only an exact path is found, as before; the stored path
  is the typed one (it already is the archive's spelling).
- Names that the program takes as equal ignoring case have the same length in bytes (the
  comparison folds byte by byte), so the archive's spelling always fits where the typed path
  fitted; if it ever did not, the typed path is kept (a path is never cut).
- The archive file's own name (`T.TAR` for `t.tar`) belongs to the disk, not to the archive's
  listing: unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After the panel enters a folder inside an archive whose listing compares names
  ignoring case, the panel's current path inside the archive MUST be spelled exactly as the
  archive's listing spells each folder of it.
- **FR-002**: Copy (F5) / Move of files from a TAR folder entered by a path typed in another case
  MUST extract them (the item's failure).
- **FR-003**: A path that already matches the listing's spelling, a case-sensitive listing and the
  archive root MUST behave exactly as before.
- **FR-004**: The existing shortening of a path whose tail does not exist, the file to focus and the
  error handling of a path change MUST stay unchanged.
- **FR-005**: A path is never cut: if the listing's spelling could not be stored whole, the typed
  path is kept (as today).
- **FR-006**: No plug-in interface change; archive plug-ins are not modified.

### Key Entities

- **Path inside the archive**: the folder of the archive the panel shows; the archive plug-ins
  receive it as the folder the selected items live in.
- **Listing spelling**: the bytes of each folder name as the archive's listing holds them.

## Success Criteria *(mandatory)*

- **SC-001**: In the probe, the rows "open in another case, Select All, Copy" for TAR (folder and
  nested folder) fail before and pass after; the same rows for 7z (file copied, panel path) pass
  after.
- **SC-002**: The case-twin control rows (TAR and 7z) pass before and after.
- **SC-003**: Feature 252's probe passes after (16 / 0), the build and the unit checks are green.

## Assumptions

- Assumption (autonomous run): the item's Approach offers two directions; the core one (store the
  path in the listing's spelling) is taken - it fixes every archive plug-in at once, needs no
  plug-in or interface change, and matches the item's Expected ("the panel shows the folder under
  the archive's own spelling").
- Assumption (autonomous run): the changed spelling is also what the directory history and a hot
  path saved afterwards record - the archive's real name.
- The disk part of the path (the archive file) is not touched.
