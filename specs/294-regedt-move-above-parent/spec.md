# Feature Specification: Registry Editor - Copy / Move of a key into the key above its parent

**Feature Branch**: `294-regedt-move-above-parent`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item `registry-editor-move-of-a-key-into-the-key-above-its-parent` - "Registry Editor: Move of a key into the key above its parent loses a same-name subkey"; Expected: "A Copy or Move whose recursion would write into the source key itself (a target key that is an ancestor of the source, reached again by a same-name subkey chain) is refused, or the copy never writes into a key it later deletes; nothing is lost. Decided by identity (the rule of feature 292, `src/common/salregkeyid.h`)." From backlog item registry-editor-move-of-a-key-into-the-key-above-its-parent.

## Measured at e752f9b9 (before this feature)

Probe `probe/above294_probe.ps1 -Expect before` on the Debug x64 build of `main` (hidden desktop;
`probe/above294_before.txt`): 14 PASS / 10 FAIL, the product's registry key restored identical.
Fixture under `HKCU\Software\TcProbe294`; `<K>` and `<M>` are Czech names with accents.

- **Move into the key above the parent loses data.** `Zdroj\<K>` (a=1) holds `<K>` (b=2), which
  holds `<K>` (x=3). In the panel at `Zdroj\<K>`, F6 of `<K>` into `\HKEY_CURRENT_USER\...\Zdroj\`
  (the target key `Zdroj\<K>` is the source's parent): no box; left `Zdroj\<K>` with a=1;b=2 - x=3
  is gone, there was no other copy (row ABOVEMOVE).
- **The same through another root name**: the target written as `\HKEY_USERS\<own SID>\...\Zdroj\`
  (ABOVEALIAS).
- **The same two elements down**: F6 of `Hloub\<K>\<M>\<K>` (holding `<M>\<K>` with x=3) into
  `...\Hloub\` (target `Hloub\<K>`): no box, x=3 gone (ABOVEDEEP, ABOVEOK).
- **Copy writes into the source**: F5 of `Zdroj\<K>\<K>` into `...\Zdroj\`: no box; the source
  `Zdroj\<K>\<K>` now also holds x=3 (ABOVECOPY).
- Controls unchanged and passing: a merge of a key without the repeated chain into the key above
  its parent (FLATTEN, FLATCOPY: `Plochy\<K>\<K>` holding `Q` into `...\Plochy\` - merged, no box),
  a move to another key (MOVE), a move into its own subkey (MOVESELF: refused with 1067).
- Cause: `CopyOrMoveFromFS` (`src/plugins/regedt/fs5.cpp`) refuses a target that is the source or
  lies inside it (text and, since 292, identity), never a target that holds the source; the copy
  writes `target\P` for every subkey path `P` of the source, which is the source itself when `P`
  begins with the source's path below the target; Move then deletes the source.

## Clarifications

### Session 2026-10-22

- Q: Refuse every Copy / Move whose target key holds the source (simpler), or only those whose
  copy would actually reach the source (the source holds again the path from the target down to
  itself)? → A: only those that would reach the source - a merge into the key above the parent
  without the repeated chain loses nothing and keeps working as before (autonomous run:
  conservative - keep the existing behaviour for every case the item does not name)
- Q: Which message, with which buttons? → A: the existing message of the "into itself" case, "Name:
  <key> Error: Can't move/copy a key to itself." with OK (skip this key) / Cancel (stop), before
  anything of that key is written; no new UI text (autonomous run: item - "is refused"; rule - a
  new string needs the `.slt` refresh a run does not do)
- Q: Copy as well? → A: yes, refused the same way - it writes into the source tree while reading it
  (autonomous run: item - "Check Copy too")
- Q: What if the check whether the source holds the repeated chain cannot be made (the key cannot be
  opened for another reason than "not found")? → A: the existing open-error box (Retry / Skip / Skip
  All / Cancel); that key is not copied or moved (autonomous run: rule - a safety check fails
  closed, CLAUDE.md 098)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A Move into the key above the parent does not lose a same-name subkey (Priority: P1)

A user in the Registry Editor moves (F6) a key into the key that holds its own parent, and the moved
key holds again the chain of names from that target down to itself (in the simplest case: a subkey
of its own name). The Registry Editor refuses that key with the "into itself" message, and nothing
is written or deleted.

**Why this priority**: today a value of the deepest key is deleted without any box and has no other
copy.

**Independent Test**: the hidden-desktop probe drives F6 with the target typed, answers the box,
and compares the registry before and after.

**Acceptance Scenarios**:

1. **Given** `Zdroj\<K>` (a=1) \ `<K>` (b=2) \ `<K>` (x=3), **When** the user moves `Zdroj\<K>\<K>`
   into `\HKEY_CURRENT_USER\Software\TcProbe294\Zdroj\`, **Then** "Name: <K> Error: Can't move a key
   to itself." appears and, after Cancel, the registry is unchanged.
2. **Given** the same, **When** the target is written as `\HKEY_USERS\<own SID>\Software\TcProbe294\Zdroj\`,
   **Then** the same message appears and the registry is unchanged.
3. **Given** `Hloub\<K>\<M>\<K>` (b=2) holding `<M>\<K>` (x=3), **When** the user moves it into
   `...\Hloub\`, **Then** the same message appears; after Cancel or OK the registry is unchanged.

---

### User Story 2 - The same Copy is refused too (Priority: P2)

Copy (F5) of the same key into the same target is refused with "Name: <key> Error: Can't copy a key
to itself." and the source is not written.

**Why this priority**: no data is deleted, but the source tree is changed while it is read.

**Independent Test**: probe row ABOVECOPY.

**Acceptance Scenarios**:

1. **Given** the fixture of Story 1, **When** the user copies `Zdroj\<K>\<K>` into `...\Zdroj\`,
   **Then** the message appears and, after Cancel, the registry is unchanged.

---

### User Story 3 - Legitimate operations keep working (Priority: P3)

A merge of a key into the key above its parent when it does not hold the repeated chain, a move to
another key and every case refused before behave as before.

**Why this priority**: the fix must not refuse what does not reach the source.

**Independent Test**: probe rows FLATTEN, FLATCOPY, MOVE, MOVESELF.

**Acceptance Scenarios**:

1. **Given** `Plochy\<K>` (a=1) \ `<K>` (b=2) \ `Q` (q=4), **When** the user moves `Plochy\<K>\<K>`
   into `...\Plochy\`, **Then** no box appears, `Plochy\<K>` holds a=1, b=2 and `Q` (q=4), and
   `Plochy\<K>\<K>` is gone; Copy leaves the source as it was.
2. **Given** `Zdroj\<K>\<K>`, **When** the user moves it into another key, **Then** it is moved
   whole without a box; into its own subkey, **Then** it is refused (1067) as before.

### Edge Cases

- Several keys selected: each key is decided on its own (OK skips only that key, Cancel stops the
  rest), as the existing "into itself" refusal does.
- The target key holds the source but the source does not hold the repeated chain: a merge, allowed
  (Story 3).
- The repeated chain differs only in letter case: the same names (the registry ignores case).
- The target is written under another root name or through a registry link: decided by identity,
  as in feature 292.
- `HKEY_CLASSES_ROOT`: a path with two identities (both halves) is checked for each pair of
  identities; any pair that would reach the source refuses the key.
- The target key does not exist yet: it cannot hold an existing source; nothing new is checked.
- The check cannot open the chain below the source for a reason other than "not found": the
  existing open-error box; the key is not copied.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the target key of a key being copied or moved holds the source key (the source's
  identity lies strictly inside the target's) and the source key holds, below itself, the path of
  names that leads from the target key down to the source, the Registry Editor MUST refuse that key
  with the existing message "Name: <key> Error: Can't copy/move a key to itself." (OK = skip the
  key, Cancel = stop) before anything of that key is written, and never delete it.
- **FR-002**: The decision MUST go by identity (feature 292): the path from the target down to the
  source is taken from the identities of the two keys, for every pair of their identities (a path
  under `HKEY_CLASSES_ROOT` has one per half that holds it); case is ignored and only whole path
  elements count.
- **FR-003**: When the existence of that path below the source cannot be established (an error
  other than "not found"), the existing open-error box MUST be shown and the key MUST NOT be copied
  or moved unless the check succeeds on Retry.
- **FR-004**: Copy and Move MUST behave alike for the refusal.
- **FR-005**: Every other Copy / Move (a merge into the key above the parent without the repeated
  chain, a move to another key, the cases refused before, values) MUST behave as before.
- **FR-006**: The pure part (the path of one identity below another, whole elements, case ignored)
  MUST be in `src/common/salregkeyid.h` with `saltests` checks.
- **FR-007**: No UI text is added or removed; no path or name is cut (a joined path that does not
  fit is refused, never shortened).

### Key Entities

- **Key identity**: the full internal name the registry reports for an opened key (feature 292).
- **Path below the target**: the part of the source's identity after the target's identity and a
  backslash; the copy would write `target\P` for each subkey path `P` of the source, reaching the
  source when `P` begins with this path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In every probe row that moves or copies a key into the key above its parent with the
  repeated chain (ABOVEMOVE, ABOVEALIAS, ABOVECOPY, ABOVEDEEP, ABOVEOK) the refusal message is shown
  and the registry is unchanged (0 values lost; before: 4 rows lost x=3, 1 changed the source).
- **SC-002**: Every control and regression row (FLATTEN, FLATCOPY, MOVE, MOVESELF) gives the result
  it gave before the feature.
- **SC-003**: The probe ends with 0 FAIL rows, no crash report and the product's registry key
  restored identical; `saltests` reports 0 failed checks; feature 292's probe still passes.

## Assumptions

- Assumption (autonomous run): a registry link inside the source tree is followed by the check as it
  is followed by the copy itself (both open the path by name); such trees are not driven by the
  probe.
- Assumption (autonomous run): the check opens the source joined with the path below the target as
  one whole path (never cut); when that chain exists the key is refused even if its names were too
  long for the copy to reach them (conservative: refuse rather than guess).
- Assumption (autonomous run): the drag-and-drop route between two Registry Editor panels uses the
  same function and is covered by the same change; it is not driven by the probe.
- Out of scope: Quick Rename (F2), Copy / Move to or from a disk panel, the low-level overwrite
  question.
