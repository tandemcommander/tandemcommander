# Feature Specification: A tar member whose name contains `..` goes to the folder its name points to

**Feature Branch**: `396-tar-dotdot-name`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item tar-member-name-with-dotdot-extracted-into-wrong-folder - implement exactly what it describes." From backlog item tar-member-name-with-dotdot-extracted-into-wrong-folder.

## Background

The TAR plug-in (tar, GNU / PAX tar, cpio, rpm, deb) cleans every member name it reads with one
rule: `/` and `\` become one `\`, `.` is dropped, `..` should remove the previous component and a
leading separator is dropped. The rule, inherited from Open Salamander, resolves `..` wrongly when
the component it drops is the **first** component of the path: it keeps that component's first
letter. Measured at `6db68ab0` (GUI probe on the hidden desktop, Python tarfile fixtures):

| Member name | Listed and extracted as (before) | Should be |
|---|---|---|
| `sub/../a.txt` | `s\a.txt` | `a.txt` |
| `x/../a.txt` | `x\a.txt` | `a.txt` |
| `q/../../f.txt` | `q\f.txt` | `f.txt` |
| `a/..` | `a` | nothing (the archive root) |
| `x/y/../b.txt` | `x\b.txt` (right) | `x\b.txt` |
| `../../empty` | `empty` (right) | `empty` |

With an unrelated member `s/a.txt` in the same archive, a whole Unpack asked "Overwrite file" and,
answered Yes, replaced `s/a.txt` with the data of `sub/../a.txt`; the archive was then deleted
("Delete archive after unpacking"). The GNU long name and the PAX path take the same rule; Copy
out of the opened archive gives the same wrong files.

## Clarifications

### Session 2026-11-02

- Q: Should a member name with a `..` component be resolved (the previous component removed) or refused and reported? → A: resolved - `..` removes the whole previous component, never above the archive root (autonomous run: item - the first outcome of its *Expected*; refusing would change `x/y/../b.txt`, which extracts right today)
- Q: Should a hard-link name with a `..` component now be normalized and matched to a member? → A: no - feature 309's rule stays (such a link is reported and fails the operation) (autonomous run: conservative - the item says "may")
- Q: Should a member whose name resolves to nothing (`a/..`) get a message of its own? → A: no - it takes the existing path of names that normalize to nothing (feature 395) (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unpack puts a `..` member where its name points (Priority: P1)

A user unpacks a tar archive (Alt+F9, whole archive) that holds a member stored as
`sub/../a.txt`. The file is written as `a.txt` at the root of the target, never into an invented
folder `s`, and never over another member of the archive that happens to live there.

**Why this priority**: the wrong folder can collide with an unrelated member, which is then
overwritten after the overwrite question - the user loses that member's data on disk while the
archive may be deleted afterwards.

**Independent Test**: build a tar with `sub/c.txt`, `sub/../a.txt`, `x/y/../b.txt`,
`../../e.txt`, `q/../../f.txt`; unpack it whole with "Delete archive after unpacking" - exactly
`a.txt`, `sub\c.txt`, `x\b.txt`, `e.txt`, `f.txt` appear with their data, nothing is asked.

**Acceptance Scenarios**:

1. **Given** the archive above, **When** it is unpacked whole, **Then** the target holds exactly
   `a.txt`, `sub\c.txt`, `x\b.txt`, `e.txt`, `f.txt` with the right contents, no box is shown and
   the archive is deleted as asked.
2. **Given** an archive with `s/a.txt` (data `S`) and `sub/../a.txt` (data `A`), **When** it is
   unpacked whole, **Then** `a.txt` holds `A`, `s\a.txt` holds `S`, and no overwrite question is
   asked.
3. **Given** a GNU-format tar (long name) or a PAX tar (PAX path) with the member
   `sub/../<120 letters>.txt`, **When** it is unpacked whole, **Then** the file is written at the
   target root under `<120 letters>.txt`.

---

### User Story 2 - The panel listing and Copy show the same names (Priority: P2)

A user opens the archive in a panel. The listing shows `a.txt`, `e.txt`, `f.txt`, `sub` and `x` at
the root - no folders `s` or `q` - and copying the root's contents out (Select All, F5) writes the
same five files as the Unpack of story 1.

**Why this priority**: the listing, Copy, F3 and Unpack all read names through the same rule; what
the user sees must match what an Unpack writes.

**Independent Test**: open the story-1 archive, Select All, Copy to an empty folder - the same five
files, no overwrite question.

**Acceptance Scenarios**:

1. **Given** the story-1 archive opened in a panel, **When** the user selects all and copies to an
   empty folder, **Then** the folder holds exactly the five files of story 1.

---

### User Story 3 - Hard links keep feature 309's protection (Priority: P3)

A hard-link member whose link name has a `..` component (`b.txt -> sub/../a.txt`) stays reported
and fails the Unpack (the archive is kept), as feature 309 decided.

**Why this priority**: regression guard - the fix must not loosen 309's rule.

**Independent Test**: an archive with `a.txt`, `s/a.txt` and the link above - both files extracted,
one box naming `b.txt`, the archive kept.

**Acceptance Scenarios**:

1. **Given** that archive, **When** it is unpacked whole with "Delete archive after unpacking",
   **Then** `a.txt` and `s\a.txt` are written, exactly one box names `b.txt`, and the archive is kept.

### Edge Cases

- `..` at the root, or more `..` than there are folders (`../../e.txt`, `q/../../f.txt`): never
  climbs above the archive root - the remaining name stays at the root.
- A name that resolves to nothing (`a/..`, `a/../`, `sub/..`): it is handled as every name that
  normalizes to nothing already is (feature 395 - a regular file stored only under such a name is
  reported, a folder stays silent).
- A trailing separator after the resolved name (`x/y/../`) still marks a folder (`x`).
- A component that only starts with dots (`..a`, `...`, `a..b`) is an ordinary name, not `..`.
- Two members resolving to one name (`sub/../a.txt` and `a.txt`): the same as two members stored
  under one name today - the later one meets the existing overwrite question.
- Non-ASCII (UTF-8) names: bytes are kept unchanged; only the separators and `.` / `..` components
  are interpreted.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A `..` component of a member name MUST remove the whole previous component of the
  name, wherever that component is (the first one included).
- **FR-002**: A `..` component MUST never climb above the archive root: when there is no previous
  component, it is dropped (`../../empty` stays `empty`).
- **FR-003**: Every other result of the name rule MUST stay as it is today (`.` dropped, `/` and
  `\` as one separator, repeated separators as one, a leading separator dropped, a trailing
  separator kept as the "folder" mark, other bytes unchanged) - in particular every name without a
  `..` component is listed and extracted exactly as before.
- **FR-004**: The fixed rule MUST apply to every name the plug-in reads (ustar, GNU long name, PAX
  path, cpio, rpm, deb), so the panel listing, Copy, F3 and Unpack agree.
- **FR-005**: The unit checks that pinned the legacy result (`sub/../a.txt` -> `s\a.txt`) MUST be
  changed to the correct result and extended with the cases of the table above.
- **FR-006**: A hard-link member whose link name has a `..` component MUST still be reported and
  fail the operation (feature 309's rule unchanged).
- **FR-007**: A name that resolves to nothing MUST go through the existing handling of names that
  normalize to nothing (feature 395), with no new message.

### Key Entities

- **Member name**: the path of a member as stored in the archive; after the rule, the path the
  listing shows and the extraction writes, relative to the archive root.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The GUI probe's five rows that failed at `6db68ab0` (whole Unpack of the mixed
  archive, the collision archive, the GNU and the PAX long name, Copy of the listing root) pass;
  the link row keeps passing.
- **SC-002**: The unit checks pass with the corrected expectations; for every name without a `..`
  component, the result is unchanged (checked over a generated set of names).
- **SC-003**: The probes of features 306, 308, 309 and 395 give the same results as before.
- **SC-004**: No member of a tested archive overwrites another member that the archive stores
  under a different resolved name.

## Assumptions

- Assumption (autonomous run): of the two outcomes the item allows, the run takes the first - a
  `..` component removes the whole previous component (item *Expected*, named first; it is also
  what the rule's own documentation says it does). Refusing such members would change archives that
  extract correctly today (`x/y/../b.txt`) and would conflict with keeping `../../empty` as
  `empty`.
- Assumption (autonomous run): feature 309's link rule stays as it is (a link name with `..` is
  reported, never matched). The item says the link rule "may" then normalize such names; keeping
  it changes least and stays on the safe side (conservative, stop-rules §1 step 4).
- Writers rarely store `..` (GNU tar strips or refuses it), so the change affects only unusual
  archives; their listed names change from the wrong folder to the right one.
