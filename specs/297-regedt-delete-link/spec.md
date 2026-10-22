# Feature Specification: Registry Editor - Delete / Move of a key holding a registry link

**Feature Branch**: `297-regedt-delete-link`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item `registry-editor-delete-or-move-deletes-a-linked-key` - "Registry Editor: Delete or Move of a key holding a registry link deletes the linked key"; Expected: "Deleting or moving a key that holds a registry link never touches the key the link points at: the link itself is removed (opened as a link) or the operation is refused for it with a message; a Move does not turn the link into a copy of its target silently."

## Measured at 49147f36 (before this feature)

Probe `probe/link297_probe.ps1 -Expect before` on the Debug x64 build of `main` (hidden desktop;
`probe/link297_before.txt`): **16 PASS / 14 FAIL**, the product's registry key restored identical.
Fixture under `HKCU\Software\TcProbe297` (and `HKCU\Software\Classes\TcProbe297c`, seen as
`HKEY_CLASSES_ROOT\TcProbe297c`); `<K>` is a Czech name with accents; "link" = a registry symbolic
link made by hand; every link points at `Jinde` (j=5, holding `Sub` s=6), which is never selected.

- **Delete of a key holding a link** (DELTREE, DELHKCR): F8 of `Del\<K>` (a=1, holding the link
  `L` -> `Jinde`), every question Yes: `Jinde` and `Jinde\Sub` deleted, the link left, then "Unable to
  delete a registry key. (5) Access denied" for `Del\<K>`. The same through `HKEY_CLASSES_ROOT`.
- **Delete of the link itself** (DELTOP): F8 of the link `Top\<K>`: `Jinde` deleted, no box, the
  link left (dangling).
- **Delete of a key holding a dangling link** (DELDANGLE): the open-error box for the link; nothing
  can be deleted.
- **Move of a key holding a link** (MOVETREE, MOVESKIP): F6 of `Mov\<K>` (a=1, `Z` z=9, link `L` ->
  `Jinde`) into `Cil\`: `Jinde` copied into `Cil\<K>\L` as a plain key and then deleted, followed by
  "Unable to remove the original registry key. (5)" for `Mov\<K>`; Skip or Cancel - the loss has
  already happened.
- **Move / Quick Rename of the link itself** (MOVETOP, RENAMETOP): `Jinde` copied (into `Cil\<K>` /
  `Top\Nove`) and deleted, no box.
- Controls passing: F5 of `Mov\<K>` (the link's target copied as a plain key, source unchanged), F8 /
  F6 of a key without a link.
- Cause: the delete recursion (`DeleteKey`, `src/plugins/regedt/fs3.cpp`) and the Move's recursion
  (`CopyOrMoveKeyRec` + `SafeDeleteKey`, `fs5.cpp`) open and delete each key by name, which follows a
  link; deleting a link's name deletes the key it points at.

## Clarifications

### Session 2026-10-22

- Q: Delete (F8) of a key whose tree holds a link, or of the link itself? → A: the link itself is
  removed (opened as a link), never the key it points at nor anything below it; a dangling link is
  removed the same way (autonomous run: item - Expected's first option, "the link itself is removed
  (opened as a link)"; the link is part of what the user selected)
- Q: Move (F6, drag and drop) / Quick Rename of a key whose tree holds a link, or of the link itself:
  recreate the link in the target, copy its target, or refuse? → A: refuse that key with the existing
  error box "Unable to remove the original registry key." + the system text for "not supported"
  (Retry / Skip / Skip All / Cancel), naming the link key, before anything of that key is written;
  Skip leaves the link (and therefore its parents) in the source and goes on with the rest; Cancel
  stops (autonomous run: item - Notes "refusing with the existing messages is the conservative
  option"; rule - no new UI string without the `.slt` refresh)
- Q: Copy (F5) of a tree holding a link? → A: unchanged - it copies the link's target as a plain key
  and loses nothing (autonomous run: conservative - the item does not name Copy)
- Q: Links above the selected key (the panel's own path through a link)? → A: followed as before -
  only the key being deleted or moved at each level is looked at as a possible link, as feature 296
  does for the target (autonomous run: conservative)
- Q: What if a key cannot be inspected (an error other than "not found")? → A: the existing error box
  of that operation (Delete: "Unable to open a registry key.", Move: the open-error box); that key is
  not deleted or moved (autonomous run: rule - a safety check fails closed, 098)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Delete never removes the key a link points at (Priority: P1)

A user deletes (F8) a registry key whose tree holds a registry link, or the link itself. The
selected key and the link are removed; the key the link points at, which the user never selected,
stays exactly as it was.

**Why this priority**: today an unselected key (possibly anywhere in the user's hive) is deleted
without a word.

**Independent Test**: the hidden-desktop probe makes the links, drives F8, answers the questions and
compares the fixture before and after.

**Acceptance Scenarios**:

1. **Given** `Del\<K>` holding the link `L` -> `Jinde`, **When** the user deletes `Del\<K>` and
   confirms, **Then** `Del\<K>` and the link are gone, `Jinde` and `Jinde\Sub` unchanged, no error box.
2. **Given** the link `Top\<K>` -> `Jinde`, **When** the user deletes `Top\<K>`, **Then** the link
   is gone and `Jinde` unchanged, no error box.
3. **Given** `Dang\<K>` holding a dangling link, **When** deleted, **Then** `Dang\<K>` and the link are
   gone, no error box.
4. **Given** the same as 1 seen through `HKEY_CLASSES_ROOT`, **When** deleted, **Then** as 1.

---

### User Story 2 - Move / Rename never moves a link into a copy of its target (Priority: P1)

A user moves (F6, drag and drop) or renames (Quick Rename) a key whose tree holds a link, or the
link itself. The link key is refused with a message before anything of it is written; the key the
link points at stays unchanged; the source keeps the link.

**Why this priority**: today the linked key is copied and then deleted.

**Independent Test**: the probe drives F6 / Quick Rename, answers the box with Cancel or Skip and
compares the fixture.

**Acceptance Scenarios**:

1. **Given** `Mov\<K>` {a=1, `Z` z=9, link `L` -> `Jinde`}, **When** moved into `Cil\` and Cancel in the
   box, **Then** the first box is "Unable to remove the original registry key." naming `Mov\<K>\L`;
   `Mov` and `Jinde` unchanged; nothing below `Cil\<K>\L`.
2. **Given** the same, **When** Skip, **Then** exactly that one box; `Z` moved into `Cil\<K>`
   (`Cil\<K>` a=1), `Mov\<K>` kept with a=1 and the link, `Jinde` unchanged, no `Cil\<K>\L`.
3. **Given** the link `Top\<K>`, **When** moved into `Cil\` (Cancel), **Then** the box names
   `Top\<K>`, and the whole fixture is unchanged.
4. **Given** the link `Top\<K>`, **When** Quick-Renamed to `Nove` (Cancel), **Then** the box names
   `Top\<K>`, and the whole fixture is unchanged.

---

### User Story 3 - Everything without links works as before (Priority: P2)

**Acceptance Scenarios**:

1. **Given** `Plain\<K>` without links, **When** deleted / moved, **Then** gone / moved whole, no error box.
2. **Given** `Mov\<K>` with its link, **When** copied (F5) into `Cil\`, **Then** as before: `Cil\<K>\L`
   is a plain key with j=5 and `Sub` s=6, the source and `Jinde` unchanged, no box.

### Edge Cases

- A link inside a subkey several levels down: each level of the recursion checks its own key.
- A link as a predefined part of the system (e.g. `HKLM\SYSTEM\CurrentControlSet`): never the key
  the user deletes or moves in practice; if it were, the same rules apply (the link itself, never its
  target) - and deleting it needs rights the user normally lacks (the existing error box).
- Retry in the Move's refusal box checks again (the link may have been removed meanwhile).
- Skip All in the refusal box skips later refusals and errors as before.
- Deleting the link fails (access denied): the existing "Unable to delete a registry key." box.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Delete MUST recognise, at every key it is about to delete (the selected key and every
  key of its tree), whether that key is a registry link, without following it.
- **FR-002**: A link met by Delete MUST be removed as the link itself; nothing the link points at
  may be enumerated, deleted or changed.
- **FR-003**: Move, drag and drop and Quick Rename MUST recognise a link at every source key of the
  recursion before anything of that key is written and MUST refuse it with the existing
  "Unable to remove the original registry key." error box (Retry / Skip / Skip All / Cancel); Skip
  keeps the link and its parents in the source, Cancel stops.
- **FR-004**: When a key cannot be inspected (an error other than "no such key"), the operation
  MUST show the existing error box and not delete or move that key (fails closed).
- **FR-005**: Copy (F5), and Delete / Move of keys without links, MUST behave exactly as before.
- **FR-006**: No new UI string; key names in the boxes are shown whole (UTF-8).

## Success Criteria *(mandatory)*

- **SC-001**: In every probe row, the key a link points at is byte-for-byte unchanged after Delete,
  Move and Quick Rename (before: deleted in 7 of 7 such rows).
- **SC-002**: The probe passes all rows (before: 16 PASS / 14 FAIL), in English and Czech; the probes
  of features 292, 294 and 296 still pass.
- **SC-003**: The product's registry key is restored identical after every probe run.

## Assumptions

- Assumption (autonomous run): a registry link key cannot hold subkeys of its own (creating below it
  goes through the link), so removing the link itself removes nothing else.
- Assumption (autonomous run): Export and Find (the item's Notes: "also check") only read; a loop or
  a walk out of the selected tree through a link is recorded as an Inbox item if measured, not
  fixed here.
- Links can be created without elevation under `HKCU`; the probe makes and removes them itself.
