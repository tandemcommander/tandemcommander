# Feature Specification: ISO plug-in - an HFS+ folder whose ID is lower than its parent's lists its contents in it

**Feature Branch**: `349-uniso-hfs-folder-order`
**Created**: 2026-10-31
**Status**: Draft
**Input**: Backlog item `iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent` (`backlog/items/iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent/desc.md`) - "ISO plug-in: an HFS+ folder whose ID is lower than its parent lists its contents at the root". From backlog item iso-plug-in-an-hfs-folder-whose-id-is-lower-than-its-parent.

## Background (measured at 5cf6564a)

An HFS+ volume keeps its entries in a catalog sorted by the number (catalog ID) of the folder each entry is
in. Every folder gets its number when it is made. A folder made first and moved later (on a Mac) into a
folder made after it keeps its lower number: the entries inside it come in the catalog before the moved
folder's own entry. The ISO plug-in lists the catalog in its order and puts an entry whose folder it has
not listed yet at the root of the HFS+ part ("HFS (...)").

A hidden-desktop probe (draft `iso349_probe.ps1`; seed = an xorriso ISO 9660 + HFS+ hybrid holding
`a/a.txt`, `a/sub/s.txt`, `b/b.txt`, `c/c.txt`, `k/k.txt`, `k/kd/kd.txt`, a chain `n1/n2/n3/n4` of long
names whose inside is over the panel listing's folder-part limit, `top.txt`; copies whose HFS+ catalog
was changed as macOS leaves it after a move and sorted again) on the Debug build of `main`, Unpack
(Alt+F9) with "Delete archive after unpacking":

| Row | Catalog | At HEAD |
|---|---|---|
| H-OK (control) | as made | every file in its folder, image deleted (right) |
| H-MOVE | `a` moved into `b`, then `b` into `c` | **`a.txt`, `sub/s.txt`, `b.txt` written at the HFS+ root** instead of `c/b/a/...`, `c/b/b.txt`; image deleted |
| H-LONG | `k` moved into `n4` (the listing leaves `k` out: its path is too long) | "(206)" report names `k`, but **`k.txt` and `kd/kd.txt` written at the HFS+ root**; image kept |
| H-CYCLE | `a` and `b` each the other's parent (damaged) | `a.txt`, `sub/s.txt` at the root, `b` at the root; **image deleted** although `a` and `b` reach no root |

## Clarifications

### Session 2026-10-31

- Q: Where is an entry listed whose folder record comes later in the catalog? → A: In that folder: the folders it lies in are listed first, at their own place, whatever the catalog order (autonomous run: item *Expected*)
- Q: What happens to the entries of a folder the listing leaves out (329) when they come before it? → A: They are left out with it, the whole subtree; only the folder is named in the report, as for a left-out folder met first (autonomous run: item *Expected*)
- Q: What if the folders' parents form a loop (damaged catalog: no folder of the loop reaches the root)? → A: The folders of the loop and everything inside them are left out and the listing is marked incomplete (a whole unpack fails, the image is kept); no new message (autonomous run: item *Expected* "a guard against cycles" + conservative - 332's damaged records are handled the same way, silently)
- Q: What about an entry whose folder is not a listed folder of the catalog at all (the volume's root used as the label, HFS+ metadata folders such as hard-link data, a damaged folder record, a folder number that no record has)? → A: Unchanged - listed at the HFS+ root as today (autonomous run: conservative - the item does not name them; 332's and its hard-link Inbox items own them)
- Q: Does anything else of the listing change (names, sizes, which records are listed or reported)? → A: No - only the order in which records are taken (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The contents of a moved folder stay in it (Priority: P1)

A user opens a disc image with an HFS+ part made on a Mac where a folder was moved into a newer folder,
and copies or unpacks it. Every file appears and is written inside its own folder, not at the root of the
HFS+ part.

**Why this priority**: The item's main point - files written to the wrong place, the folder structure lost.

**Independent Test**: Probe row H-MOVE: Unpack of the image with `a` moved into `b` and `b` into `c`.

**Acceptance Scenarios**:

1. **Given** an image whose HFS+ folder `a` (lower number) was moved into `b`, and `b` into `c`,
   **When** the user unpacks the whole image, **Then** `HFS (...)\c\b\a\a.txt`, `c\b\a\sub\s.txt` and
   `c\b\b.txt` are written, nothing extra at the HFS+ root, and the image is deleted when "Delete archive
   after unpacking" is on (nothing is missing).
2. **Given** an ordinary image (no folder moved), **When** it is unpacked, **Then** the result is the
   same as before (H-OK).

---

### User Story 2 - A left-out folder takes its whole subtree with it (Priority: P2)

A moved folder whose new path is too long for the panel listing is left out (feature 329) - its contents
must not appear anywhere, not at the HFS+ root.

**Why this priority**: The second sentence of the item's *Expected*; otherwise files land at the root.

**Independent Test**: Probe row H-LONG.

**Acceptance Scenarios**:

1. **Given** an image whose folder `k` (with `k.txt` and `kd/kd.txt`) was moved into a folder whose path
   leaves `k` out, **When** the user unpacks the whole image, **Then** neither `k.txt` nor `kd.txt` is
   written anywhere, one "(206)" report names `k`, and the image is kept.

---

### User Story 3 - A damaged catalog whose folders loop does not misplace files (Priority: P3)

**Why this priority**: The item asks for a guard against cycles; a crafted or damaged image must not list
the loop's files somewhere or let Unpack delete the image.

**Independent Test**: Probe row H-CYCLE.

**Acceptance Scenarios**:

1. **Given** an image whose folders `a` and `b` are each the other's parent, **When** the user unpacks
   the whole image, **Then** nothing of `a` or `b` is written, the rest is, no new message appears, and
   the image is kept.

### Edge Cases

- A chain of several moved folders (each lower than its new parent): every level lands in place (H-MOVE).
- A folder moved into a folder that is itself left out: its contents are left out (`Under` of 329).
- A folder whose parent is itself (a loop of one): left out as a loop.
- Two folder records with the same number (damaged): entries go under the first one, as today.
- A record of a type not handled inside a moved folder: as today, the listing ends there marked
  incomplete - unless the folder is left out, then it is skipped with it.
- A very deep chain of folders whose records all come late: no recursion limit is reached (the folders
  are taken one by one).
- Out of memory while collecting the folders: the listing is marked incomplete and an "insufficient
  memory" error ends the HFS+ listing, as other out-of-memory cases of the reader.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The HFS+ listing MUST list every entry under its own folder's path whatever the order of
  the catalog records, when that folder is a listed folder record of the catalog.
- **FR-002**: A folder MUST be listed (or left out) before any entry inside it is taken; when the folder's
  record comes later in the catalog, the folder and the folders above it that are not listed yet are
  taken first, outermost first, and their own records are not taken a second time.
- **FR-003**: Entries inside a folder the listing leaves out MUST be left out with it (the whole subtree)
  whatever the catalog order; only the folder is reported.
- **FR-004**: Folders whose parent chain loops MUST be left out together with everything inside them and
  the listing MUST be marked incomplete (a whole unpack fails, the image is kept); no new message.
- **FR-005**: An entry whose folder is not a listed folder record of the catalog MUST be listed at the
  HFS+ root as before.
- **FR-006**: Nothing else of the listing changes: names, sizes, attributes, the records listed, damaged
  and not-handled records (332), the listing rule and reports (329), and each entry's record reference
  used by extraction.
- **FR-007**: The decision which folders must be taken first (and whether the chain loops) MUST be a pure
  rule with unit checks (project rule: pure decisions in a header with `saltests`).

### Key Entities

- **Catalog folder record**: an HFS+ folder - its own number, its parent's number, its position in the
  catalog.
- **Pending ancestors**: the folders above an entry not yet listed or left out, outermost first.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `iso349_probe`: H-MOVE, H-LONG, H-CYCLE fail on `main` (3 / 4 FAIL measured) and all 4
  rows pass after the change.
- **SC-002**: The earlier HFS+ probes keep their results (322, 329, 332, 333, 339).
- **SC-003**: The unit checks of the rule pass and a mutant that skips the pending folders or the loop
  guard fails them.

## Assumptions

- Assumption (autonomous run): the images are crafted from an xorriso hybrid by changing the catalog as
  macOS would after a move (the moved folder's key, its thread record, the valences) and sorting it again;
  no Mac-made image is used - a person step to check one is owed (as 332 / 339).
- Assumption (autonomous run): a moved folder made on macOS keeps its catalog number (TN1150: a catalog
  node ID is assigned at creation and never changes on a move).
- The Release build is not driven; the reader code is the same.
- Assumption (autonomous run, review 1 N2): a record of a type not handled takes the folders above it
  before the HFS+ listing ends there - only in an out-of-order catalog; the listing is marked incomplete
  as before.
- Assumption (autonomous run, review 1 S1): catalog IDs below 16 are reserved (TN1150) and never a moved
  folder - they are not taken first; a damaged record with such an ID is placed as before.
