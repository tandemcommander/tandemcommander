# Feature Specification: Registry Editor - Copy / Move through a registry link in the target tree

**Feature Branch**: `296-regedt-link-target-tree`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item `registry-editor-move-through-a-link-in-the-target-tree` - "Registry Editor: Move into a key holding a registry link to the source writes into the source"; Expected: "A Copy / Move never writes into a key it reads from or later deletes, also through a registry link in the target tree; or such a link is not followed by the copy (refused or skipped with a message)."

## Measured at 4420aae1 (before this feature)

Win32 behaviour (scratch script under `HKCU\Software\TcLinkExp296`, removed): creating a key by name
where a registry link stands opens the key the link points at; where a dangling link stands (its
target does not exist) it **creates** the link's target; a key below a link is created below the
link's target. A link is recognised by opening it as a link and finding its link value.

Probe `probe/link296_probe.ps1 -Expect before` on the Debug x64 build of `main` (hidden desktop;
`probe/link296_before.txt`): **14 PASS / 15 FAIL**, the product's registry key restored identical.
Fixture under `HKCU\Software\TcProbe296`; `<K>` is a Czech name with accents; "link" = a registry
symbolic link made by hand.

- **Move loses data without a box** (LINKMOVE, LINKALIAS): `Zdroj\<K>` (a=1) holds `Z` (z=9);
  `Cil\<K>` holds the link `Z` -> `Zdroj\<K>`. F6 of `<K>` into `...\Cil\` (also written as
  `\HKEY_USERS\<own SID>\...`): no box; the whole source is gone and z=9 with it - it was written
  through the link into the moved key after that key's values had been copied, then deleted with it.
- **Copy writes into the source** (LINKCOPY): F5 of the same: no box; the source `Zdroj\<K>` gains z=9.
- **A link to the source's parent** (LINKUP): `Hore\<K>` holds `U` (u=2) holding `<K>` (w=7);
  `Cil2\<K>` holds the link `U` -> `Hore`. F6 of `Hore\<K>` into `...\Cil2\`: no box; `Hore\<K>` gone,
  w=7 lost, `Hore` gained u=2.
- **A dangling link** (LINKDANGLE): `Cil5\<K>` holds the link `Z` -> `Zdroj\<K>\Nove` (missing). F6 of
  `Zdroj\<K>` into `...\Cil5\`: the copy created `Zdroj\<K>\Nove` inside the source, then "Unable to
  remove the original registry key".
- **The target key itself a dangling link** (LINKTOP): `Cil6\<K>` is a link to `Zdroj\<K>\Nove`. F6
  of `Zdroj\<K>` into `...\Cil6\`: the copy created `Zdroj\<K>\Nove` and recursed into itself (a
  `Nove\Nove\...` chain dozens of keys deep inside the source).
- Controls passing: a link to an unrelated key (LINKOTHER, followed: `Jinde` gets z=9), a link to the
  source's parent when the source does not hold the path back to itself (LINKUPOK, followed: `Plochy`
  gets u=2), a plain Move to another key (MOVE).
- Cause: the recursive copy (`CopyOrMoveKey`, `src/plugins/regedt/fs5.cpp`) creates or opens each
  target subkey by name, which follows a link; the checks of features 292 / 294 look only at the top
  target key.

## Clarifications

### Session 2026-10-22

- Q: Refuse every registry link met in the target tree, or only those through which the copy would
  write into the source? → A: only those that would reach the source: a link to the source key or to
  a key inside it, and a link to a key above the source when the key being copied holds the path from
  there down to the source (the rule of feature 294); a link to any other key is followed as before
  (autonomous run: conservative - keep the existing behaviour for every case the item does not name)
- Q: A dangling link (its target does not exist)? → A: refused with the existing open-error box
  (Retry / Skip / Skip All / Cancel) naming the link's key: creating through it creates a key at
  the link's target, which cannot be shown to lie outside the source without creating it
  (autonomous run: conservative - refuse rather than guess; rule - a safety check fails closed, 098)
- Q: Which message, with which buttons, for a link that reaches the source? → A: the existing "Name:
  <key> Error: Can't move/copy a key to itself." with OK (skip this key) / Cancel (stop), naming the
  full source key that would be written onto itself; no new UI text (autonomous run: item - "refused
  or skipped with a message"; rule - a new string needs the `.slt` refresh a run does not do)
- Q: When is it decided? → A: at the key whose target is the link, before anything of that key is
  written; what was copied above it stays (a Move then keeps its source, because a key was skipped)
  - the limit feature 287 accepted for a refusal inside the recursion (autonomous run: conservative -
  a pre-pass over the whole tree would duplicate the walk and could not stop a change in between)
- Q: What if the link cannot be inspected or its target's identity cannot be read (another error
  than "not found")? → A: the existing open-error box; that key is not copied or moved (autonomous
  run: rule - a safety check fails closed, 098)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Move through a link to the source loses nothing (Priority: P1)

A user moves (F6) a registry key into a key whose tree holds a registry link pointing into the moved
key (or above it, with the path back). The Registry Editor refuses the key that would be written
through the link with the "into itself" message; nothing of the source is lost.

**Why this priority**: today the value is deleted without any box and has no other copy.

**Independent Test**: the hidden-desktop probe creates the links, drives F6 with the target typed,
answers the box, and compares the source tree before and after.

**Acceptance Scenarios**:

1. **Given** `Zdroj\<K>` (a=1) \ `Z` (z=9) and `Cil\<K>\Z` a link to `Zdroj\<K>`, **When** the user
   moves `Zdroj\<K>` into `\HKEY_CURRENT_USER\Software\TcProbe296\Cil\`, **Then** "Name:
   HKEY_CURRENT_USER\Software\TcProbe296\Zdroj\<K>\Z Error: Can't move a key to itself." appears and,
   after Cancel, the source tree is unchanged.
2. **Given** the same, **When** the target is written as `\HKEY_USERS\<own SID>\Software\TcProbe296\Cil\`,
   **Then** the same message appears and the source tree is unchanged.
3. **Given** the same, **When** the user answers OK (skip), **Then** the source tree is unchanged,
   the link is unchanged and only the moved key's own values were copied to `Cil\<K>`.
4. **Given** `Hore\<K>` \ `U` (u=2) \ `<K>` (w=7) and `Cil2\<K>\U` a link to `Hore`, **When** the user
   moves `Hore\<K>` into `...\Cil2\`, **Then** "... `Hore\<K>\U` ... Can't move a key to itself."
   appears and `Hore` with its tree is unchanged.

---

### User Story 2 - A Copy through a link to the source is refused too (Priority: P2)

**Why this priority**: the copy writes into the source while reading it; nothing is lost, but the
source changes.

**Independent Test**: the probe drives F5 the same way.

**Acceptance Scenarios**:

1. **Given** the fixture of Story 1, **When** the user copies `Zdroj\<K>` into `...\Cil\`, **Then**
   "... Can't copy a key to itself." appears and the source tree is unchanged.

---

### User Story 3 - A dangling link is not created through (Priority: P2)

**Why this priority**: the copy creates keys inside the source (and in the worst case a chain of
copies of the source inside itself).

**Independent Test**: the probe drives F6 into a target holding a dangling link, below the target
key and as the target key itself.

**Acceptance Scenarios**:

1. **Given** `Cil5\<K>\Z` a link to the missing `Zdroj\<K>\Nove`, **When** the user moves `Zdroj\<K>`
   into `...\Cil5\`, **Then** the open-error box appears and, after Cancel, the source tree is unchanged.
2. **Given** `Cil6\<K>` a link to the missing `Zdroj\<K>\Nove`, **When** the user moves `Zdroj\<K>`
   into `...\Cil6\`, **Then** the open-error box appears and, after Cancel, nothing at all has changed.

---

### User Story 4 - Other links and plain copies work as before (Priority: P3)

**Acceptance Scenarios**:

1. **Given** `Cil4\<K>\Z` a link to the unrelated `Jinde`, **When** the user moves `Zdroj\<K>` into
   `...\Cil4\`, **Then** no box appears and the link is followed as before (`Jinde` holds z=9).
2. **Given** `Cil3\<K>\U` a link to `Plochy`, the parent of the moved `Plochy\<K>` which holds `U`
   without a subkey `<K>`, **When** the user moves `Plochy\<K>` into `...\Cil3\`, **Then** no box
   appears and the link is followed as before.
3. **Given** no link, **When** the user moves `Zdroj\<K>` into an empty key, **Then** it is moved whole.

### Edge Cases

- A link inside the target tree several levels below the target key: decided at that level.
- A link reached through another link: each link is decided at its own level.
- The target key itself a link to an existing key: already refused by feature 292 when it is the
  source or inside it; otherwise unchanged.
- Quick Rename (F2) of a key to a sibling name that is a dangling link: the same decision at the top
  of the copy.
- A link to the source written under another root name or the merged HKEY_CLASSES_ROOT view: decided
  by identity (feature 292's rule), each half of an HKCR source.
- A registry link inside the **source** tree: not part of this item (assumption below).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before the copy creates or opens a target key by name, it MUST find out whether a
  registry link stands at that name.
- **FR-002**: A link whose target is the key being copied or moved (the operation's source) or a key
  inside it MUST be refused with the existing "Can't move/copy a key to itself." box naming the full
  source key of that level; OK skips that key, Cancel stops the operation; nothing of that key is
  written.
- **FR-003**: A link whose target holds the operation's source MUST be refused the same way when the
  key being copied at that level holds the path from the link's target down to the source.
- **FR-004**: A dangling link MUST NOT be created through: the existing open-error box names the
  link's key (Retry / Skip / Skip All / Cancel); the key is not copied or moved.
- **FR-005**: A link that cannot be inspected or resolved for another reason MUST be handled by the
  existing open-error box (fails closed).
- **FR-006**: Every other link MUST be followed as before; a target key that is not a link MUST be
  handled exactly as before.
- **FR-007**: A Move with a skipped key MUST keep its source (existing behaviour of a skip).
- **FR-008**: No new UI text, no change to the plug-in interface or to what is stored.

### Key Entities

- **Registry link**: a key created as a symbolic link; opening it by name opens the key it points at;
  creating a key through it creates or opens the link's target.
- **Operation's source**: the key the user selected; everything below it is read and, for a Move,
  deleted at the end.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, every refused row leaves the source tree byte-for-byte unchanged and no
  value of the fixture is lost (LINKMOVE, LINKALIAS, LINKCOPY, LINKOK, LINKUP, LINKDANGLE, LINKTOP).
- **SC-002**: The control and regression rows (LINKUPOK, LINKOTHER, MOVE) give the same result as on
  the build before the feature.
- **SC-003**: The probes of features 292 and 294 still pass with no failing row.
- **SC-004**: The probe passes in English and in Czech.

## Assumptions

- Assumption (autonomous run): a registry link inside the source tree (read through the link, and a
  Move deleting what it points at) is not part of this item; it is recorded separately if found
  reachable.
- Assumption (autonomous run): links are recognised by the documented link value; a normal key that
  merely carries such a value is treated as a link and then resolved - harmless, it resolves to itself.
- The probe creates links under the current user's key only (no elevation); HKLM / HKCR cases follow
  the same code and are not driven.
