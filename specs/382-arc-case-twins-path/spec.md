# Feature Specification: A path typed in another case into an archive with case twins elsewhere opens the folder

**Feature Branch**: `382-arc-case-twins-path`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item a-path-typed-in-another-case-into-an-archive-with-case-twins (backlog/items/a-path-typed-in-another-case-into-an-archive-with-case-twins/desc.md) - implement exactly what it describes." From backlog item a-path-typed-in-another-case-into-an-archive-with-case-twins.

## Background

A TAR or 7z archive in which some folder holds two names that differ only in case (for
example `X\a.txt` and `X\A.txt`) is listed case-sensitively as a whole (feature 252). A
folder of such an archive opened by a path typed in another case than the archive spells
it (`t.tar\DOCS` for the folder `Docs`) - from the command line, Change Directory or a hot
path - names no folder exactly, so the panel silently shortens the path to the archive's
root. A user who then selects all and copies (F5) copies the whole root (`Docs\f.txt`,
`X\a.txt`, `X\A.txt`) instead of the folder asked for. Archives without twins open `Docs`
since feature 273. Nothing is lost, but the following copy takes more than the user meant.

Measured at 59053ae5 with the probe `arctwins_probe.ps1` (built on 273's probe, hidden
desktop): rows MIXED (typed `\DOCS`), MIXDEEP (typed `\dOCS\SUB`) and MIXMISS (typed
`\DOCS\nothing`) FAIL for TAR and 7z - panel at the archive root, F5 copied the whole root;
rows EXACT (twins `Docs` / `DOCS`, typed `\DOCS`) and AMBIG (twins `Docs` / `DOCS`, typed
`\docs`) PASS. 14 PASS / 6 FAIL.

## Clarifications

### Session 2026-11-01

- Q: Should a typed component be accepted when it equals a folder only by the Unicode ordinal case rule but not by the byte fold a listing without twins uses? → A: No - accepted only by the byte fold (what the same archive without twins opens since 273); the ordinal rule only counts towards ambiguity (autonomous run: conservative)
- Q: Should an ambiguous typed name (two folders equal ignoring case) show a message? → A: No - it is handled as any path not found inside an archive today (shortened); the item's *Expected* is met by opening the unambiguous folder (autonomous run: conservative)
- Q: Does the rule apply both when the archive is opened anew and when the panel is already inside the same archive? → A: Yes - every path change inside an archive (command line, Change Directory, hot path, history) goes through the same lookup (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a folder of an archive with twins elsewhere by a path in another case (Priority: P1)

A user types `<archive>\DOCS` (command line, Change Directory, hot path) for an archive
whose folder is spelled `Docs` and whose other folder `X` holds `a.txt` and `A.txt`. The
panel opens `Docs` (shown with the archive's spelling) and Select All + Copy copies only
the files of `Docs`.

**Why this priority**: This is the defect of the item: today the root opens silently and a
following copy takes the whole archive root.

**Independent Test**: The probe row MIXED for TAR and 7z: panel path ends in `\Docs`, the
copy target holds only `f.txt` with its content.

**Acceptance Scenarios**:

1. **Given** a TAR / 7z archive with `Docs\f.txt`, `X\a.txt`, `X\A.txt`, **When** the panel
   is opened at `<archive>\DOCS` and Select All + Copy run, **Then** the panel is at
   `<archive>\Docs` and only `f.txt` arrives.
2. **Given** the same archive with `Docs\Sub\g.txt`, **When** the panel is opened at
   `<archive>\dOCS\SUB`, **Then** the panel is at `<archive>\Docs\Sub` and a copy brings only
   `g.txt`.
3. **Given** the same archive, **When** the panel is opened at `<archive>\DOCS\nothing` (a
   missing tail), **Then** the missing tail is shortened as for any missing path and the
   panel is at `<archive>\Docs`.

---

### User Story 2 - Exact names and twins keep their meaning (Priority: P2)

A typed path that names a folder exactly keeps opening exactly that folder, also when a
twin of it exists; a typed name that matches two folders ignoring case (the twins
themselves) is not guessed.

**Why this priority**: The case-sensitive listing of 252 exists to keep twins apart; the
fix must not open the wrong twin.

**Independent Test**: Probe rows EXACT and AMBIG for TAR and 7z.

**Acceptance Scenarios**:

1. **Given** an archive with folders `Docs` and `DOCS`, **When** the panel is opened at
   `<archive>\DOCS`, **Then** it is at `<archive>\DOCS` and a copy brings only `DOCS`'s file.
2. **Given** an archive with folders `Docs` and `DOCS`, **When** the panel is opened at
   `<archive>\docs`, **Then** neither twin is opened (the path is treated as not found, as
   before).

### Edge Cases

- A component that matches exactly is always taken, even when another folder matches it
  ignoring case.
- A component that matches no folder exactly and exactly one folder ignoring case is taken
  with the folder's own spelling; a component that matches two or more folders ignoring
  case is not found.
- Only the leading components that resolve are re-spelled; from the first component that
  does not resolve, the rest of the path is handled by the existing shortening (file focus,
  shorter path).
- An archive listing that is not case-sensitive is unchanged (it already finds folders
  ignoring case, feature 273).
- The re-spelled path has the typed path's length; a path is never cut.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a path into a case-sensitive archive listing names no folder exactly, each
  component MUST be resolved exactly first and otherwise by the single folder of its parent
  that equals it ignoring case; the path MUST then be stored with the archive's spelling.
- **FR-002**: A component that equals two or more folders of its parent ignoring case MUST NOT
  be resolved by this rule (no guess between twins); the path is then handled as today.
- **FR-003**: "Equal ignoring case" for accepting a folder MUST be the comparison a listing
  without twins uses to find folders (so the result is what the same archive without twins
  would open); for counting ambiguity, a folder equal by either case rule the core uses on
  archive names MUST count.
- **FR-004**: The rest of a path after the first component that does not resolve MUST be kept
  as typed so the existing shortening and file focusing behave as before.
- **FR-005**: Listings that are not case-sensitive, and paths that resolve exactly, MUST behave
  exactly as before.
- **FR-006**: The rule MUST be a pure decision with unit checks; it MUST never cut a path (a
  result that does not fit is refused and the typed path is kept).
- **FR-007**: The rule MUST apply whether the archive is opened anew or the panel is already
  inside the same archive.

### Key Entities

- **Archive listing**: the tree of folders and files of an opened archive with a flag saying
  whether names are compared case-sensitively.
- **Typed path inside the archive**: components separated by `\`, possibly in another case
  than the listing spells them.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe rows MIXED, MIXDEEP and MIXMISS pass for TAR and 7z (6 rows FAIL before,
  PASS after): the panel shows the requested folder and a copy brings only its files.
- **SC-002**: The probe rows EXACT and AMBIG keep passing for TAR and 7z.
- **SC-003**: The probes of features 273 (`arccase273_probe.ps1`, 12 / 0) and 252
  (`arc252_probe.ps1`, 16 / 0) keep passing.
- **SC-004**: The unit checks of the new rule pass, and a negative control (the fallback
  disabled) fails them.

## Assumptions

- Assumption (autonomous run): an ambiguous typed name (two folders equal ignoring case) is
  handled as any path not found inside an archive today (shortened, no message) - the item's
  *Expected* asks for the unambiguous case to open; the not-found handling of archive paths
  in general is unchanged (conservative, §1 step 4).
- Assumption (autonomous run): the rule applies to every case-sensitive archive listing in
  the core's path change (7-Zip and TAR with twins, also the ZIP plug-in's Unix-made
  archives and other plug-ins that list case-sensitively), because it lives in the core's
  path lookup; for each of them a typed path that names a folder exactly is unchanged and
  only a path that today opens a shorter path is affected.
- Assumption (autonomous run): the archive listing's comparison rule itself
  (`SalDirStrCmp` and its consumers: selection, focus, refresh) does not change; only the
  lookup of a typed path when the panel changes its path inside an archive does.
- A copy target typed into an archive in another case (`x.7z\DOCS` from disk) is outside this
  item (Inbox `copying-into-an-archive-folder-typed-in-another-case-packs`).
