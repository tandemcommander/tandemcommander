# Feature Specification: Disk Map closes safely while one of its boxes, menus or shell commands is open

**Feature Branch**: `143-diskmap-release-guard`
**Created**: 2026-10-14
**Status**: Implemented - GUI verified (probe 34 / 0, control 27 / 7); real-mouse rows owed (quickstart)
**Input**: `specs/NEXT-WORK.md`, *Open items at a glance*, A.1 (queue 104, entry 6; feature 118,
`research.md` R7): "Disk Map's `Release()` has no guard: a box, menu or shell operation opened from
the map between the core's decision and the plug-in's turn gets `WM_CLOSE`, and the map is
destroyed inside that modal or menu loop (also on a normal exit)."

## Clarifications

### Session 2026-10-14

The maintainer asked for the backlog to be fixed in order through the Spec Kit flow, without
questions on the way; the decisions below are the author's and are recorded as such.

- Q: What closes a map from outside? -> A: Three routes, all through the plug-in's `Release`: the
  program's normal exit (the map runs on its own thread, so the main window stays usable while a
  box of the map is open), unloading the plug-in, and an installer's unattended close
  (interface 107, feature 118). Each one asks every map window to close.
- Q: What is "a loop the map is inside"? -> A: Anything the map's own thread waits in before its
  code continues: the About box, the Esc close confirmation, the shell context menu of a file or
  of a folder of the path line, a shell command chosen from that menu (Delete with its
  confirmation, Open with, Send to ...), the default shell command of *Open*.
- Q: What happens to a close request that arrives inside such a loop? -> A: The window is never
  destroyed inside the loop. The request is remembered, and:
  - a context menu is ended at once, without a command;
  - the map's own boxes (About, close confirmation) are ended as if cancelled - the close
    confirmation answers itself: the request to close came from outside;
  - a shell command and the shell's own windows are **not** touched (cancelling a shell
    operation half-way is not the plug-in's decision); the map closes when the command returns.
  When the outermost loop returns, the map closes the way it closes today.
- Q: Normal exit while a shell command of the map is still waiting (e.g. its Delete
  confirmation)? -> A: The map closes after the command. If it does not end within the time the
  plug-in already waits for its windows, the core's existing question about a plug-in that does
  not unload appears - unchanged behaviour, no new text.
- Q: Unattended close? -> A: While a map is inside such a loop it withdraws its declaration
  "closes unattended" (a 107 core only), so the core declines at the question as it does for any
  open box; and `Release` refuses silently (closes nothing) when a map is inside such a loop at
  the plug-in's turn - the guard the File Comparator, Checksum and Batch Renamer got in 118.
- Q: New strings, interface, registry values? -> A: None.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Exiting the program never crashes because of an open map menu or box (Priority: P1)

A user has a Disk Map window open with its context menu, its About box, its close confirmation or
a shell command (Delete confirmation) open, and closes the program from its main window (or the
system signs out). The program ends without a crash report; nothing the shell command was doing
is cut off by the plug-in.

**Why this priority**: today the map is destroyed while its code still runs (use of freed
memory) - a crash on exit, every release since Open Salamander.

**Independent Test**: probe on the hidden desktop - open the map, bring it into each state, close
the program's main window; check for a crash report, the exit code and that the process ended.

**Acceptance Scenarios**:

1. **Given** a map with its file context menu open, **When** the program is closed, **Then** the
   menu ends, the map closes, the program ends normally (exit code 0, no crash report).
2. **Given** a map with its About box open, **When** the program is closed, **Then** the box and
   the map close and the program ends normally.
3. **Given** a map with its close confirmation (Esc) open, **When** the program is closed,
   **Then** the confirmation and the map close and the program ends normally.
4. **Given** a map with a shell command's window open (the Delete confirmation of the context
   menu), **When** the program is closed, **Then** the shell window is not answered by the
   plug-in; the map closes after the user answers it; nothing is deleted that the user did not
   confirm.

---

### User Story 2 - An installer's close never destroys a map inside its loop (Priority: P2)

An installer asks the program to close while a map is inside one of its loops.

**Why this priority**: the window of opportunity is milliseconds (the core declines first at
its question), but the result is the same crash.

**Independent Test**: the 118 probe rows with the map in each loop state, plus a row where the
loop opens between the question and the instruction (a seam or timing in the probe).

**Acceptance Scenarios**:

1. **Given** a map inside a loop, **When** an installer asks, **Then** the program declines
   within 1 s, shows nothing new and keeps every window.
2. **Given** a map without a loop (finished, scanning, Log window), **When** an installer asks,
   **Then** the program agrees and ends as in 118 (rows M1-M3 unchanged).

---

### User Story 3 - Closing the map itself keeps working (Priority: P3)

File > Exit, Esc with confirmation, the window's close button, a second map, plug-in unload with
no loop open: unchanged.

**Independent Test**: probe rows for each route on the build before and after.

### Edge Cases

- A close request arrives twice inside the same loop: one close.
- A loop inside a loop (the shell command's own box inside the context menu's command): the map
  closes only after the outermost loop.
- The map's scan is running while a menu is open: the close aborts the scan as today, after the
  loop.
- A close request arrives after the loop ended but before the remembered close ran: one close.
- Several maps, one inside a loop: during an unattended close the plug-in refuses as a whole
  (closes nothing).
- A core older than 107: no unattended-close calls (FR-009 of 118 stays).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A map window MUST NOT be destroyed while its thread is inside one of the loops
  listed in Clarifications; a close request received there MUST be remembered and carried out
  when the outermost loop has returned.
- **FR-002**: A close request inside the map's context menu MUST end the menu without running a
  command.
- **FR-003**: A close request inside the map's own About box or close confirmation MUST end that
  box as cancelled (the confirmation does not need an answer); the map then closes.
- **FR-004**: A close request inside a shell command MUST NOT answer, cancel or close any window
  of the shell; the map closes after the command returns.
- **FR-005**: While a map is inside such a loop, it MUST NOT be declared as closing unattended
  (107 core only); the declaration MUST come back when the loop ends and no close is pending.
- **FR-006**: During an unattended close, `Release` MUST refuse silently (return FALSE, close
  nothing, show nothing) when any map is inside such a loop.
- **FR-007**: On a normal exit or unload, `Release` MUST keep its current waits and its current
  answer when a map does not end in time; no new question or text.
- **FR-008**: No new string, plug-in interface change, registry value or configuration version.

### Key Entities

- **Map window**: one Disk Map top-level window and its thread; holds whether it is inside a
  loop (and how deep), what kind of loop it is, and whether a close is pending.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe of this feature on the build before shows the defect in at least the
  context-menu row (crash report, access violation or a hang at exit) - the negative control.
- **SC-002**: The same probe on this build: every normal-exit row ends the program with exit
  code 0, no crash report, no window left, within 10 s (the shell row after its window is
  answered by the probe as a person would).
- **SC-003**: The unattended rows decline within 1 s with nothing shown and every window kept;
  the 118 probe's Disk Map rows M1-M4 and X1 give their 118 results.
- **SC-004**: `saltests` and `check_encoding.py` unchanged (no new findings).

## Assumptions

- A context menu and the map's boxes are opened by the probe through messages to the map (no
  real mouse on the hidden desktop); the shell's Delete confirmation needs a file in a folder
  where Windows asks (a recycle bin confirmation or a permanent delete with Shift) - if Windows
  does not show it on the hidden desktop, that row is NOT DRIVEN and reasoned from code.
- The program's own exit confirmation is switched off for the probe (the probe library does so).
- Out of scope: the File Comparator / Checksum worker boxes (backlog item A.3, its own feature).
