# Feature Specification: Copying into an archive folder typed in another case packs into that folder

**Feature Branch**: `383-arc-typed-target-case`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item copying-into-an-archive-folder-typed-in-another-case-packs (backlog/items/copying-into-an-archive-folder-typed-in-another-case-packs/desc.md) - implement exactly what it describes." From backlog item copying-into-an-archive-folder-typed-in-another-case-packs.

## Background

A user copies (F5) or moves (F6) files from a disk folder into an archive by typing the
target in the Copy / Move dialog as a folder inside the archive, spelled in another case
than the archive spells it (`x.7z\DOCS\` while the archive holds the folder `Docs`). The
typed spelling is given to the archive plug-in unchanged as the folder to pack into, so
the files land in a new folder `DOCS` beside `Docs`. Nothing is lost, but the archive now
holds two folders that differ only in case, and other programs extract them as two folders
(or merge them unpredictably). Feature 273 fixed the panel route (a folder opened by a
typed path is stored as the archive spells it); this typed-target route was left.

Measured at e3dfe127 with a hidden-desktop probe (to be committed as
`probe/arctarget383_probe.ps1`): the program started with the left panel on a disk folder
holding `n.txt`, Copy (or Move) opened, the target field set to `<archive><typed>`, OK; the
archive then listed by 7z.exe with the case of every path. 22 PASS / 10 FAIL, the same for
7z and ZIP:

| Row | Archive holds | Typed | Result at e3dfe127 |
|---|---|---|---|
| TYPED | `Docs\f.txt` | `\DOCS\` | FAIL - `DOCS\n.txt` beside `Docs` |
| EXACT | `Docs\f.txt` | `\Docs\` | PASS - `Docs\n.txt` |
| DEEP | `Docs\Sub\g.txt` | `\dOCS\sUB\` | FAIL - `dOCS\sUB\n.txt` |
| NEWTAIL | `Docs\f.txt` | `\DOCS\New\` | FAIL - `DOCS\New\n.txt` (wanted `Docs\New\n.txt`) |
| MOVE (F6) | `Docs\f.txt` | `\DOCS\` | FAIL - `DOCS\n.txt` |
| TWINS | `Docs\f.txt`, `X\a.txt`, `X\A.txt` | `\DOCS\` | FAIL - `DOCS\n.txt` |
| TWINEX | folders `Docs` and `DOCS` | `\DOCS\` | PASS - `DOCS\n.txt` |
| AMBIG | folders `Docs` and `DOCS` | `\docs\` | PASS - `docs\n.txt` (no guess) |

## Clarifications

### Session 2026-11-01

- Q: Which rule decides the folder a typed component names? → A: The rule a panel already uses when the same path is typed to open the archive (features 273 and 382): an exact name first; else the folder the archive's listing finds ignoring case; in an archive listed case-sensitively (case twins somewhere) only the ONE folder equal ignoring case, never a guess between twins (autonomous run: item - "as 273 does for the panel")
- Q: What happens to the part of the typed path that names no existing folder (a new folder)? → A: It keeps the typed spelling; only the leading components that name existing folders are re-spelled (autonomous run: item)
- Q: Where does the listing come from? → A: A panel that shows the same archive, when the archive file's date and size are still those the panel listed; otherwise the archive is listed before packing, as opening it in a panel would (autonomous run: item - "list the archive (or reuse a panel's listing)")
- Q: What if the archive cannot be listed (no lister for its format, the listing fails or is cancelled, low memory)? → A: The typed spelling is used, as before the feature - packing is never refused because of the re-spelling (autonomous run: conservative)
- Q: Does the fix also cover drag and drop or paste into an archive panel? → A: No - those take the folder from a panel whose path is already spelled as listed (273); only the typed target of Copy / Move is in scope (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Copy or move into an existing archive folder typed in another case (Priority: P1)

A user in a disk panel presses F5 (or F6), types `<archive>\DOCS\` as the target while the
archive holds the folder `Docs`, and confirms. The files arrive in `Docs`; no second folder
`DOCS` appears.

**Why this priority**: This is the defect of the item.

**Independent Test**: Probe rows TYPED, DEEP and MOVE for 7z and ZIP: the archive lists
`Docs\n.txt` (`Docs\Sub\n.txt`) and no path starting with the typed spelling.

**Acceptance Scenarios**:

1. **Given** an archive holding `Docs\f.txt`, **When** `n.txt` is copied to `<archive>\DOCS\`,
   **Then** the archive holds `Docs\n.txt` and no folder `DOCS`.
2. **Given** an archive holding `Docs\Sub\g.txt`, **When** `n.txt` is copied to
   `<archive>\dOCS\sUB\`, **Then** the archive holds `Docs\Sub\n.txt`.
3. **Given** an archive holding `Docs\f.txt`, **When** `n.txt` is moved (F6) to
   `<archive>\DOCS\`, **Then** the archive holds `Docs\n.txt` and `n.txt` is gone from the disk.
4. **Given** an archive holding `Docs\f.txt` and the case twins `X\a.txt`, `X\A.txt` (listed
   case-sensitively), **When** `n.txt` is copied to `<archive>\DOCS\`, **Then** the archive
   holds `Docs\n.txt`.

---

### User Story 2 - A new folder under an existing one (Priority: P2)

A user types `<archive>\DOCS\New\` where `Docs` exists and `New` does not. The files go into
a new folder `New` inside the existing `Docs`.

**Why this priority**: The missing tail is common (packing into a new sub-folder) and must
keep the name the user typed for the new part.

**Independent Test**: Probe row NEWTAIL for 7z and ZIP: `Docs\New\n.txt`.

**Acceptance Scenarios**:

1. **Given** an archive holding `Docs\f.txt`, **When** `n.txt` is copied to
   `<archive>\DOCS\New\`, **Then** the archive holds `Docs\New\n.txt`.

---

### User Story 3 - Exact names, twins and ambiguity keep their meaning (Priority: P2)

A typed path that names a folder exactly keeps packing into exactly that folder, also when
its case twin exists; a typed name that matches two folders ignoring case is not guessed.

**Why this priority**: Twins are kept apart on purpose (feature 252); the fix must never
pack into the wrong twin.

**Independent Test**: Probe rows EXACT, TWINEX and AMBIG for 7z and ZIP.

**Acceptance Scenarios**:

1. **Given** an archive holding `Docs\f.txt`, **When** `n.txt` is copied to `<archive>\Docs\`,
   **Then** the archive holds `Docs\n.txt` (unchanged behaviour).
2. **Given** an archive holding the folders `Docs` and `DOCS`, **When** `n.txt` is copied to
   `<archive>\DOCS\`, **Then** the archive holds `DOCS\n.txt` and no `Docs\n.txt`.
3. **Given** an archive holding the folders `Docs` and `DOCS`, **When** `n.txt` is copied to
   `<archive>\docs\`, **Then** neither `Docs\n.txt` nor `DOCS\n.txt` is made (the typed
   spelling is kept, as before).

### Edge Cases

- The target archive is a zero-size file (it is deleted and created anew): nothing to list;
  the typed spelling is used.
- The archive's format has no lister, or listing fails or is cancelled (a password prompt
  answered Cancel): the typed spelling is used; packing goes on as before.
- A panel shows the same archive but the file changed since it was listed (date or size
  differ): the archive is listed again, the panel's listing is not trusted.
- A file (not a folder) in the archive has the typed name beside a folder of another case:
  in a case-sensitive listing the name is ambiguous and kept as typed (382's rule).
- The re-spelled path has the typed path's length; a result that would not fit is not used
  (the typed path is kept) - a path is never cut.
- The typed path's separators (leading / trailing backslash) are kept as typed; only the
  names change.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When files from a disk panel are copied or moved into an archive named in the
  typed target together with a path inside it, the program MUST give the archive plug-in that
  path with every leading component that names an existing folder spelled as the archive's
  listing spells that folder.
- **FR-002**: A component MUST be matched by the rule a panel uses when the same path is
  typed to open the archive (features 273 / 382): exact first; else the folder the listing's
  comparison finds; in a case-sensitive listing only the single folder equal ignoring case,
  and not when a file of that name exists there.
- **FR-003**: From the first component that names no existing folder on, the typed spelling
  MUST be kept.
- **FR-004**: The listing MUST be a panel's listing of the same archive only when the archive
  file's date and size equal those the panel recorded; otherwise the archive MUST be listed
  before packing (with the usual "listing archive" wait window).
- **FR-005**: When no listing can be had (zero-size archive, a format without a lister, a
  failed or cancelled listing, low memory) the typed path MUST be used unchanged and the
  operation MUST go on as before.
- **FR-006**: The re-spelled path MUST NOT be longer than the typed path and MUST NOT be cut;
  a result that does not fit the buffer is discarded in favour of the typed path.
- **FR-007**: Every other part of the Copy / Move into an archive (the checks of features 099,
  119 and 146, the zero-size archive handling, the error paths that return to the dialog with
  the typed text) MUST stay unchanged; the dialog history keeps the text the user typed.
- **FR-008**: The pure part of the rule (applying a resolved spelling over the typed path while
  keeping its separators) MUST be a header-only function under `src/common/` with `saltests`
  checks.

### Key Entities

- **Typed archive root**: the text after the archive name in the typed target, components
  separated by backslashes, optional leading / trailing backslash.
- **Archive listing**: the folders and files of the archive as the archive plug-in lists them,
  with its case rule (case-insensitive, or case-sensitive when case twins exist).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe rows TYPED, DEEP, NEWTAIL, MOVE and TWINS pass for 7z and ZIP (10 rows
  that fail at e3dfe127).
- **SC-002**: The control rows EXACT, TWINEX and AMBIG keep passing and the row PANEL (the other
  panel shows the archive, its listing is reused) passes, for 7z and ZIP - all 18 RUN rows pass
  (the probe's total also counts one END row per RUN row: PASS 36, FAIL 0).
- **SC-003**: The probes of features 273 and 382 keep their results (12 / 0 and 24 / 0).
- **SC-004**: `saltests` passes with the new checks; a negative control (the re-spelling
  disabled) makes the probe fail again.

## Assumptions

- Assumption (autonomous run): TAR does not pack (read-only plug-in), so only packing formats
  are probed (7z and ZIP, both via plug-ins in the default build).
- Assumption (autonomous run): the extra read of the archive is accepted (the item's *Notes*
  name it); it is skipped when a panel's unchanged listing of the same archive exists.
- Assumption (autonomous run): an archive with header encryption may ask for its password once
  more for the listing; Cancel keeps the typed spelling (FR-005). Not probed.
- Assumption (autonomous run): two folders that match the typed name ignoring case (twins,
  none exact) keep the typed spelling - the behaviour before the feature; no message is added.
