# Feature Specification: Registry Editor - Copy and Find never loop through a registry link

**Feature Branch**: `391-regedt-link-loop`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item registry-editor-copy-or-find-through-a-link-to-an-ancestor - Registry Editor: Copy or Find through a link to an ancestor walks in a loop." From backlog item registry-editor-copy-or-find-through-a-link-to-an-ancestor.

## Clarifications

### Session 2026-11-02

- Q: What should Copy do with a key that leads back into the copied tree - follow it, copy it as a link, or refuse it? → A: Refuse only that key, with the existing "Can't copy a key to itself." box naming it (OK skips, Cancel stops); links elsewhere stay followed (autonomous run: item - its Notes name refusing only the looping case as the conservative option)
- Q: Should Find tell the user when it does not follow such a key? → A: No - it skips the key silently; nothing is hidden because the key's contents belong to a key already being searched (autonomous run: conservative - no new string, Find's results stay complete)
- Q: When the identity of a walked key cannot be read, should the walk go on without the check? → A: No - the existing open-error box (Retry / Skip / Skip All / Cancel), fails closed; for the walk's starting key the check is best effort (autonomous run: rule - CLAUDE.md "a safe check fails closed")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Copy of a key that holds a link back to itself (Priority: P1)

A user copies (F5, also drag and drop) a registry key whose tree holds a registry link pointing at the
copied key itself, at a key above it, or at a key that links back to it. Today the copy walks through
the link again and again and writes a chain of keys 27-28 levels deep into the target before Windows
refuses to follow more links (error 87). After the change the copy writes each key of the tree once;
the looping link is refused with the existing "Can't copy a key to itself." box naming the link (OK
skips it and the copy goes on, Cancel stops); nothing is written for it.

**Why this priority**: it writes dozens of unwanted keys into the user's registry and ends with a
misleading error.

**Independent Test**: the probe's COPYSELF / COPYCANCEL / COPYANC / COPYCYCLE rows.

**Acceptance Scenarios**:

1. **Given** `Self\<K>` (a = 1, subkey `Mark`) holding the link `L -> Self\<K>`, **When** the user copies `Self\<K>` into `Cil\` and answers OK, **Then** exactly one box ("Can't copy a key to itself.") names `...\Self\<K>\L`, and `Cil\<K>` holds a = 1 and `Mark` and no `L`; the source is unchanged.
2. **Given** the same, **When** the user answers Cancel, **Then** the copy stops; nothing is written for `L` (what was copied before stays).
3. **Given** `Anc\<K>\D\L -> Anc` (a link to a key above the copied key), **When** `Anc\<K>` is copied, **Then** one box names `...\Anc\<K>\D\L`; `Cil\<K>\D\Mark` is copied, `Cil\<K>\D\L` is not.
4. **Given** a cycle of two links (`Cyc\<K>\L1 -> Cyc2`, `Cyc2\L2 -> Cyc\<K>`), **When** `Cyc\<K>` is copied, **Then** `Cil\<K>\L1` is a plain copy of `Cyc2` (a link elsewhere is followed as before) and one box names `...\Cyc\<K>\L1\L2`; nothing below `Cil\<K>\L1\L2`.

---

### User Story 2 - Find in a tree that holds such a link (Priority: P2)

A user searches the registry (the plug-in's Find, subkeys on) in a key whose tree holds a link back
into the searched tree. Today the same key is listed again below every `L`, `L\L`, ... and the search
ends with an error box. After the change each key is listed once and no box comes: the looping link is
not followed (what lies behind it is already being searched); the link key itself is still listed when
its own name matches.

**Why this priority**: read-only, but the results repeat and the search ends with an error.

**Independent Test**: the probe's FINDSELF / FINDANC / FINDCYCLE rows.

**Acceptance Scenarios**:

1. **Given** the fixture of story 1, **When** the user searches "Mark" (keys) in `Self`, `Anc` or `Cyc`, **Then** exactly one result is listed each time and no error box appears.

---

### User Story 3 - A link elsewhere keeps working as before (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `Mov\<K>\L -> Jinde` (an unrelated key), **When** `Mov\<K>` is copied, **Then** `Cil\<K>\L` is a plain copy of `Jinde` with its subkey, no box (as before).
2. **Given** the same, **When** the user searches "Sub" in `Mov`, **Then** the `Sub` key below `Mov\<K>\L` is found once (as before).

### Edge Cases

- A link to the copied key's parent or any key above it, also above the place where the walk started (a link to the root's key): not followed.
- A cycle through several links whose target names never repeat a walked path: decided by what each opened key is (its identity), not by the path text.
- `HKEY_CLASSES_ROOT` (a merged view): the walk's starting key counts with every half that holds it.
- Move (F6) and Quick Rename: feature 297 already refuses a link source before it is read, so the new check (which runs in the shared recursion for Move too, with the Move wording of the same box) is never reached through a link; Move behaves as before.
- The identity of a key below the start cannot be read (practically only an internal name longer than the identity limit): the existing open-error box (Retry / Skip / Skip All / Cancel) - fails closed, nothing of that key copied or searched.
- The walk's starting key or root has no readable identity: the check works one level later (every key below the start is checked against the keys walked), never refuses a key wrongly.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Copy MUST NOT follow a registry link (or any key reached by name) that is one of the keys the copy is inside of, from the copied key down to the current key, or that holds one of them.
- **FR-002**: Such a key MUST be refused before anything of it is written, with the existing "Can't copy a key to itself." message naming the full source path of the refused key; OK skips it (the copy goes on, the operation ends as partly skipped), Cancel stops the copy.
- **FR-003**: Find MUST NOT search such a key or below it; no message; the key's own name is still tested in its parent's listing as before.
- **FR-004**: A link pointing anywhere else MUST be followed exactly as before by Copy and Find.
- **FR-005**: The decision MUST compare key identities (the internal name the registry reports for the opened key, feature 292), whole path elements, case ignored; never a cut name.
- **FR-006**: No new UI text; no change to Move, Delete, Export or to the target-tree checks of 294 / 296.

### Key Entities

- **Walk chain**: the identities of the keys a Copy or Find walk is inside, from its starting key down to the current key's parent.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, the three looping Copy rows write 0 keys below a refused link (before: 38-55 keys, 27-28 levels deep), with exactly one box each.
- **SC-002**: The three looping Find rows list exactly 1 result each with no box (before: 28 / 10 / 15 and an error box).
- **SC-003**: The control rows (link elsewhere) give the same result as before the change.
- **SC-004**: Probes of 292, 294, 296, 297 and 390 still pass.

## Assumptions

- Assumption (autonomous run): Copy refuses the looping key with the existing "Can't copy a key to itself." box (feature 296's box: OK skips, Cancel stops, no Skip All) - no new string; the conservative option named by the item's Notes (refuse only the looping case).
- Assumption (autonomous run): Find skips the looping key silently - nothing is hidden (its contents are those of a key already being searched), and a box per loop in a long search would only interrupt it.
- Assumption (autonomous run): the item's "until the key-name length limit" was reasoned; measured, Windows stops following links after 27-28 steps with error 87 - the defect is the same.
- Export runs reg.exe / regedit.exe and is out of scope.
