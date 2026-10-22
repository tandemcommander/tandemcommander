# Feature Specification: Plug-in folder picker never cuts a folder shortcut's target

**Feature Branch**: `304-plugin-picker-shortcut-cut`  
**Created**: 2026-10-22  
**Status**: Draft  
**Input**: Backlog item `plug-in-folder-picker-may-cut-a-folder-shortcut-target-of` - "Plug-in folder picker may cut a folder shortcut target of 260 or more units". From backlog item plug-in-folder-picker-may-cut-a-folder-shortcut-target-of.

## Background (measured at 3fa858bb)

The folder picker that the plug-ins PictView, UnCAB and Undelete show (Browse...) treats a
picked *folder shortcut* (a network location in the user's profile: a folder holding a
`desktop.ini` that names the folder-shortcut class and a `target.lnk`) as the folder it points
at. It reads that target from the shortcut and hands it back as the picked folder.

Measured with standalone programs (`probe/measure*.cpp`):

1. A shortcut whose target has 260 or more UTF-16 units cannot be written by giving the path as
   text (the shell refuses it); it can be written from the target's item list built folder by
   folder - other programs and older Windows versions can produce such links.
2. On a drive that generates 8.3 short names (C:), the shell answers such a target in its short
   form (87-108 units) - the same folder, whole.
3. On a drive without 8.3 names (D:, E:, F: of the measuring machine) the shell answers
   **success with exactly 259 units - the target cut in the middle of a name** - for targets of
   260, 261, 300 and 400 units, with a 260-unit buffer and with a 32,768-unit buffer alike.
   The picker hands that cut path back as the picked folder. A target of 259 units is answered
   whole. The link's own item list names the whole target.

So a larger buffer alone does not fix it: the answer must be recognised as possibly cut.

## Clarifications

### Session 2026-10-22

- Q: When the shell's answer is possibly cut and the link's item list names a longer path that begins with the answer, should the picker follow that whole item-list name or refuse? → A: Follow the whole item-list name (plain form); refuse only when it cannot be proven (autonomous run: item - *Expected* "followed whole ... or refused", whole preferred where UnCAB's 780-byte buffer can take it)
- Q: How is a refusal shown to the user? → A: With the picker's existing "too long" message, nothing picked - no new text (autonomous run: rule - new UI strings need the `.slt` refresh; the picker already refuses a folder that does not fit this way)
- Q: Is a possibly cut answer recognised by its length alone (259 units or more) or by any length? → A: By length: 259 units or more must be proven; shorter answers keep today's behaviour (autonomous run: conservative - measured cut length is exactly 259; changes nothing below it)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long folder-shortcut target is never cut (Priority: P1)

A user picks, in a plug-in's folder picker, a network location whose target folder has a path of
260 or more characters on a drive without 8.3 names. Today the plug-in receives the first 259
characters of the path - another folder (or one that does not exist) - and would extract,
restore or save into it. After the change the picker hands back the whole target folder, or
refuses the pick with the existing "too long" message; never a cut path.

**Why this priority**: a cut path is another folder; files would go to the wrong place without a
word (CLAUDE.md: a path or name is never cut).

**Independent Test**: build a folder shortcut whose `target.lnk` names a target of 260-400 units on
a drive without 8.3 names; resolve it the way the picker does; the result is either the whole
target or a refusal - never a path of 259 units that is a prefix of the target.

**Acceptance Scenarios**:

1. **Given** a folder shortcut whose target has 300 units on a drive without 8.3 names, **When**
   the picker resolves it, **Then** the result names exactly the target folder (whole), or the
   pick is refused.
2. **Given** that whole target and a plug-in whose buffer takes 260 bytes (PictView, Undelete),
   **When** the user confirms the pick, **Then** the existing "too long" message appears and
   nothing is picked (the plug-in's own limit, as for any picked folder).
3. **Given** that whole target and UnCAB (a 780-byte buffer), **When** the user confirms the
   pick, **Then** UnCAB receives the whole target path in the plain form (no `\\?\` prefix) in
   its field; its own OK then refuses a cabinet path over 256 bytes (`CB_MAX_CAB_PATH`) as for
   any typed path - the plug-in's own limit.
4. **Given** a shortcut whose answer has 259 units or more and whose whole name cannot be
   proven (the item list is missing or names something else), **When** the picker resolves it,
   **Then** the pick is refused with the "too long" message - never followed cut, and never
   silently replaced by the shortcut folder itself.

---

### User Story 2 - Everything else stays as it was (Priority: P2)

Shortcuts with shorter targets, targets answered in the 8.3 form, ordinary folders, UNC
folders and folders that are not folder shortcuts behave exactly as before.

**Why this priority**: compatibility (constitution principle II) - the change touches only the
long-target case.

**Independent Test**: the existing saltests checks of the picker's shortcut rule keep passing;
a target of 259 units and one in 8.3 form are followed as before.

**Acceptance Scenarios**:

1. **Given** a folder shortcut whose target has fewer than 259 units, **When** resolved,
   **Then** the result is that target, unchanged.
2. **Given** a folder without `desktop.ini`, without the class, or without `target.lnk`, **When**
   picked, **Then** the picked folder itself is the result, as before.

### Edge Cases

- A target of exactly 259 units, answered whole: followed (proven whole by the item list).
- The answer is in the `\\?\` or `\\?\UNC\` form: compared and handed back in the plain form.
- The link prefers a UNC form (mapped drive) and its item list names the drive form: for an
  answer under 259 units nothing changes; for 259 units or more the two cannot be matched -
  refused (fail closed).
- The item list cannot be read or names no file-system path: an answer of 259 units or more is
  refused; a shorter answer is followed as before.
- Low memory for the 32,768-unit target buffer: the pick is refused (never cut, never the
  shortcut folder silently). Other failures before the target is read (the shortcut cannot be
  opened or loaded, it names no path) keep feature 121's behaviour: the picked folder itself.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The picker MUST never hand back a folder-shortcut target that the shell answered
  possibly cut (259 units or more) unless the whole name is proven by the link's own item list.
- **FR-002**: When the whole name is proven, the picker MUST hand back the whole target in the
  plain form (without `\\?\` / `\\?\UNC\` prefix); the caller's own buffer limit then decides as
  for any picked folder (refusal with the existing "too long" message when it does not fit).
- **FR-003**: When a possibly cut answer cannot be proven whole, the picker MUST refuse the pick
  with the existing "too long" message and pick nothing.
- **FR-004**: The rule deciding "whole / follow the item-list name / refuse" from the shell's
  answer and the item-list name MUST be a pure function covered by saltests checks.
- **FR-005**: Every case with an answer under 259 units, and every folder that is not a folder
  shortcut, MUST behave exactly as before.
- **FR-006**: No new UI text, no change to the plug-in interface (`spl_*.h`, the interface
  version), no change to plug-in call sites.

### Key Entities

- **Folder shortcut**: a folder with `desktop.ini` naming the folder-shortcut class and a
  `target.lnk`.
- **Shell answer**: the target path the shortcut's text form gives (may be cut at 259 units).
- **Item-list name**: the file-system name of the shortcut's item list (whole).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For targets of 260, 261, 300 and 400 units on a drive without 8.3 names, 0 of 4
  resolutions hand back a cut path (before: 4 of 4).
- **SC-002**: For targets of 250 and 259 units and for the 8.3 answers, the result equals the
  result before the change in every case.
- **SC-003**: The pure rule has saltests checks for every branch (whole, proven by item list,
  refused) and all saltests pass.

## Assumptions

- Assumption (autonomous run): the shell's cut answer has exactly MAX_PATH - 1 = 259 units (measured on this Windows 11 build); every answer of 259 units or more is treated as possibly cut and must be proven by the item list.
- Assumption (autonomous run): following the item-list name when it extends the cut answer is "followed whole" in the item's sense (both come from the same link; the item list is what Explorer opens). A mismatch other than "the answer is a prefix of the item-list name" is refused (conservative).
- Assumption (autonomous run): refusal reuses the existing message of the picker (`SplShowNameTooLongW`) - no new string, no translation refresh.
- Reachable only through a network location in the user's profile (feature 286 R4); not driven through the real dialog in this run (the dialog needs a real mouse / keyboard to pick a tree item) - the rule and the resolution are checked end to end by saltests with real folder shortcuts.
- Out of scope: the core's `SalShellLinkGetPathU8` receives the same cut answer (Enter on a shortcut, drop onto a shortcut, Browse of feature 286) - recorded as a separate backlog item.
