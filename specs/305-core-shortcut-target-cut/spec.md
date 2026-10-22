# Feature Specification: The core never follows a shortcut to a cut target path

**Feature Branch**: `305-core-shortcut-target-cut`  
**Created**: 2026-10-22  
**Status**: Draft  
**Input**: Backlog item `a-shortcut-whose-target-path-has-260-or-more-characters-is` - "A shortcut whose target path has 260 or more characters is followed to a cut path". From backlog item a-shortcut-whose-target-path-has-260-or-more-characters-is.

## Background (measured at 31239f48)

The core reads the target of a shortcut (`.lnk`) in four places: Enter on a shortcut in a panel
(`CFilesWindow::Execute`), *Go to Shortcut Target* (`CFilesWindow::FocusShortcutTarget`), a drop
onto a shortcut in a panel (`GetCurrentDir`, feature 194), and Browse For Folder on a network
location (folder shortcut, `SalFolderShortcutTargetU8`, feature 286). All four go through one
reader that trusts the shell's "success".

Measured with a standalone program built against the core's reader (a plain shortcut and a
folder shortcut whose item list, built folder by folder, names targets of 250 / 259 / 260 / 261
/ 300 / 400 units):

1. On D: (no 8.3 short names): for 260, 261, 300 and 400 units the reader returns **success with
   259 units - `\\?\D:\Build\...` cut in the middle of a name**, a folder that does not exist; the
   raw-path form of the question gives the same cut answer; the folder-shortcut reader
   (Browse) returns the cut path as the target. 250 and 259 units are whole.
2. On C: (8.3 names): 260+ units are answered in the 8.3 form (87-109 units) - the same folder,
   whole.
3. Feature 304 measured that the link's own item list names the whole target and fixed the
   plug-ins' twin of this reader the same way.

A cut that falls on a backslash names the parent folder - Enter or *Go to* would open another
folder, a drop would put the files into another folder.

## Clarifications

### Session 2026-10-22

- Q: When the shell's answer is possibly cut and the link's item list names a longer path that begins with the answer, follow the item-list name or refuse? → A: Follow the whole item-list name in the plain form; refuse only when it cannot be proven (autonomous run: item - *Expected*)
- Q: How does a refused target reach the user? → A: Through each caller's existing handling of a target that cannot be read - no new text (autonomous run: item - *Expected* "the callers' existing too long / not a valid shortcut handling"; rule - new UI strings need the `.slt` refresh)
- Q: The raw-path question (environment strings not expanded) - can the item list prove it? → A: No; a raw answer of 259 units or more is refused (autonomous run: item - *Approach* "fail closed")
- Q: Is a possibly cut answer recognised by its length (259 units or more)? → A: Yes, as feature 304; shorter answers keep today's behaviour (autonomous run: conservative - the measured cut is exactly 259 units)
- Q: Should a drop onto a shortcut whose target is refused be blocked (stop cursor) instead of taking today's route for a shortcut whose target cannot be read? → A: Today's route, unchanged - the core only stops taking the cut path as the drop folder (autonomous run: conservative - keeps the existing behaviour for every case the item does not name)
- Q: Should an 8.3 answer (a volume with short names) be expanded to the long form? → A: No - it names the same folder whole; unchanged (autonomous run: conservative - the item does not name it)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long shortcut target is never followed cut (Priority: P1)

A user has a shortcut (written by a program that stores a long item list) whose target folder
or file has a path of 260 or more characters on a volume without 8.3 names. Today Enter, *Go to
Shortcut Target*, a drop onto the shortcut and Browse For Folder on such a network location all
take the first 259 characters - another folder, or one that does not exist. After the change
they take the whole target, or treat the shortcut as one whose target cannot be read - never a
cut path.

**Why this priority**: a cut path is another place; a drop would put files into another folder
(CLAUDE.md: a path or name is never cut).

**Independent Test**: build shortcuts whose item list names a target of 260-400 units on a
volume without 8.3 names; read them through the core's reader; the result is the whole target
or a refusal - never a 259-unit prefix of the target.

**Acceptance Scenarios**:

1. **Given** a shortcut to a 300-unit folder on a volume without 8.3 names, **When** the core
   reads its target, **Then** it gets the whole folder path in the plain form (no `\\?\`).
2. **Given** that shortcut, **When** the user presses Enter on it or uses *Go to Shortcut
   Target*, **Then** the panel opens / focuses the whole target (the core's paths are long-path
   capable), not another folder.
3. **Given** a network location whose target has 300 units, **When** it is picked in Browse For
   Folder, **Then** the existing "too long" refusal of feature 286 applies (the target does not
   fit the caller's `MAX_PATH` buffer) - not the cut path.
4. **Given** a shortcut whose answer has 259 units or more and whose whole name cannot be proven
   (no item list, an item list naming something else, the raw-path question), **When** the core
   reads it, **Then** the reader fails and the caller does what it does today for a target it
   cannot read.

---

### User Story 2 - Everything else stays as it was (Priority: P2)

Shortcuts with shorter targets, targets answered in the 8.3 form, shortcuts to servers (read
through the raw path or the item list), and folders that are not folder shortcuts behave
exactly as before.

**Why this priority**: compatibility (constitution principle II).

**Independent Test**: the existing saltests checks of features 128, 181, 194 and 286 keep
passing; targets of 250 and 259 units and 8.3 answers are read as before.

**Acceptance Scenarios**:

1. **Given** a shortcut whose target has fewer than 259 units, **When** read, **Then** the
   result is unchanged and the item list is not consulted.
2. **Given** a shortcut to a server (`\\server`), **When** Enter / *Go to* tries the Network
   plug-in, **Then** it behaves as before.

### Edge Cases

- A target of exactly 259 units, answered whole: followed (the item list proves it).
- The answer in the `\\?\` or `\\?\UNC\` form: compared and returned in the plain form.
- A mapped drive: the UNC-preferred answer and the item list's drive form cannot be matched for
  259+ units - refused (fail closed); shorter answers unchanged. This includes a whole UNC answer
  of exactly 259 units, which was followed before (accepted after review 1: it cannot be told
  from a cut one; every longer UNC answer was cut before).
- The item list cannot be read or names no file-system path: a 259+ answer is refused.
- The whole name does not fit the caller's buffer as UTF-8: refused as today (never cut).
- A refused target on Enter: the existing route for an unreadable target - the shortcut file is
  opened through its association (the shell's own handling of the shortcut).
- A refused target on *Go to Shortcut Target*: the existing "the shortcut's path cannot be
  obtained" message.
- A refused target on a drop: the shortcut is not taken as a folder - the existing route for a
  shortcut whose target cannot be read.
- A refused target in Browse For Folder: the existing "too long" refusal (feature 286), nothing
  picked - never the shortcut folder itself silently.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The core's shortcut-target reader MUST never return an answer of 259 units or more
  unless the link's own item list proves the whole name (equal, or the answer is the beginning
  of the longer item-list name).
- **FR-002**: When proven, the reader MUST return the whole item-list name in the plain form
  (without `\\?\` / `\\?\UNC\`), or fail when it does not fit the caller's buffer (never cut).
- **FR-003**: A raw-path question (environment strings not expanded) with an answer of 259 units
  or more MUST fail (the item list is not comparable).
- **FR-004**: A refusal MUST be distinguishable as "too long" so that Browse For Folder keeps
  its existing "too long" refusal instead of silently taking the shortcut folder.
- **FR-005**: The decision "as before / follow the item-list name / refuse" MUST be a pure rule
  in a header under `src/common/` with saltests checks for every branch, plus an end-to-end check
  with real long-target shortcuts on a volume without 8.3 names and a fake link for the refusal.
- **FR-006**: Every answer under 259 units MUST be returned exactly as before, without reading the
  item list; no new UI text; no change to the plug-in interface.

### Key Entities

- **Shell answer**: the target path the shortcut's text form gives (may be cut at 259 units).
- **Item-list name**: the file-system name of the shortcut's item list (whole).
- **Plain form**: a path without the `\\?\` / `\\?\UNC\` prefix.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For targets of 260, 261, 300 and 400 units on a volume without 8.3 names, 0 of 4
  reads return a cut path (before: 4 of 4), for plain shortcuts and folder shortcuts.
- **SC-002**: For targets of 250 and 259 units and for 8.3 answers, the result equals the result
  before the change in every case.
- **SC-003**: All saltests pass, with checks for every branch of the rule; a negative control
  (the rule made to return the answer as it is) fails them.

## Assumptions

- Assumption (autonomous run): the shell's cut answer has exactly MAX_PATH - 1 = 259 units (measured on this Windows 11 build, also by feature 304); every answer of 259 units or more is treated as possibly cut.
- Assumption (autonomous run): the item's *Evidence* names `fileswn0.cpp` "Enter" and `fileswn2.cpp` "Go to Shortcut Target"; in the code it is the other way round (`fileswn0.cpp` = `FocusShortcutTarget`, `fileswn2.cpp` = `Execute`). Both are covered; the call sites need no change - the fix is in the reader.
- Assumption (autonomous run): Enter / drop through the real panel are not driven in this run (a drop needs a real mouse); the reader every caller uses is checked end to end by saltests with real shortcuts.
- Out of scope: the shell's own handling of a shortcut (association, drop handler of the `.lnk`) when the core refuses the target - unchanged route.
