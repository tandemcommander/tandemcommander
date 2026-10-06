# Feature Specification: the small batch (feature 121)

**Feature Branch**: `121-small-batch`
**Created**: 2026-10-06
**Status**: Draft (code complete; GUI runs pending)
**Input**: eleven small, contained defects recorded in `specs/NEXT-WORK.md` item 5 by features 101,
102, 103, 104, 116, 118 and 119 ("Found by ..., not fixed"): the Find window's *Look in* cut at
259 bytes; message boxes breaking lines inside words; silent clipboard copy failures; the
code-page "name already used" text in a UTF-8 field; Disk Map's garbled log; the plug-in folder
picker without the NetHood resolve and the OK-button rule; "plugin has rejected to unload" right
after fcremote; the lower-case Romanian `IDS_CANTMULTIVOL`; Checksum's silent write errors; the
FTP typed-login cut, unwiped login command and torn log texts; the RegEdit Find and FTP Logs /
Welcome windows blocking an installer update; and (added by the coordinator, found by 117's GUI
run) plug-in Save dialogs opening another program's folder. Measured before the work (`research.md`); the
maintainer asked for autonomy.

## Clarifications

### Session 2026-10-06

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Are the premises right? -> A: Mostly; measured by code reading (no GUI run was allowed).
  Wider than recorded: the Find window's Look in was cut also inside a UTF-8 character, and a
  typed path was cut the same way (R1); the message box cut EVERY paragraph wider than the box once
  one long word was in the text (R2); the echo variant of the clipboard copy was silent too (R3);
  the FTP cut hit the user name and the host as well - a cut user name or host is another account
  or server and the password went there (R10). Narrower: the "name already used" text is drawn
  correctly while the system code page matches the language (the fallback of the UTF-8 field) -
  it loses letters only when the code page lacks them (French on CP1250) (R4).
- Q: How long may the Find window's Look in be? -> A: The program's path limit
  (`SAL_MAX_PATH_UTF8` bytes; the field's limit `SAL_MAX_PATH_W` UTF-16 units, whose UTF-8 always
  fits). A panel path that does not fit (with its `;` doubled) is left out, never cut.
- Q: Where may a message box break a line? -> A: Only inside a "word" that alone is wider than the
  box; after a path separator when the piece is at least a third of the width; DrawText breaks the
  rest between words.
- Q: Which existing text reports a clipboard failure? -> A: The system's reason
  (`GetErrorText`), titled with the existing "Copy To Clipboard" menu label without its `&` - the
  title the echo already used, cleaned. No new string. Only the core's user commands report; the
  plug-in services keep their contract (FTP shows its own message for FALSE).
- Q: Checksum's write error text? -> A: The existing `IDS_ERRORCREATINGFILE` "Error creating file."
  with the system's reason (the code of the failed write, `_doserrno`). The truncated file stays.
- Q: FTP: cut at a whole character or refuse? -> A: Refuse (the plug-in's existing
  `IDS_TOOLONGPATH`), for the user name, the host, the password and a user part longer than the
  copy - a cut is another account, server or password. Display texts (wait window, log) are cut
  at a whole character.
- Q: Which plug-in windows may an update close? -> A: RegEdit's Find window while it does not search
  (the core's Find window rule, 080 D5); FTP's Logs window and its welcome-message / server-reply /
  raw-listing window always (read-only). Their Save dialogs still decline.
- Q: The fcremote race - wait or retry? -> A: `Release()` waits in slices of the same budget as
  before and closes every comparator window or dialog that registers meanwhile; an unattended close
  refuses a Compare Files dialog that appears (118's rule); the forced path is unchanged.
- Q: Romanian? -> A: Capitalise the first letter, keep the wording and the corpus' missing
  diacritics (the ZIP plug-in's code page); pin it.
- Q: New strings? -> A: None.

## User Scenarios & Testing

### User Story 1 - Find searches the folder the user is in (Priority: P1)

A user in a deeply nested folder whose path has accented names opens Find: Look in shows the whole
path and Find Now searches there; a long typed path is searched whole.

**Acceptance**: from a 400-byte accented folder with a `;` in a name the Look in text equals the
path with `;` doubled; the one needle file there is found; a typed 420-byte path is searched whole.

### User Story 2 - Messages and errors say what happened (Priority: P2)

A message with a long path keeps its sentences whole; a copy command that fails says so; a failed
checksum save says so; the "name already used" text is exact in any code page; Disk Map's log shows
the names as they are; a typed FTP login that does not fit is refused, never cut.

**Acceptance**: probe rows M1, C1-C3, K1, N1, D1, P1-P3 (`quickstart.md`).

### User Story 3 - Updates and exits do not stop at plug-in windows (Priority: P3)

An installer update goes through while RegEdit's Find window (not searching) or FTP's Logs window is
open; closing the program right after fcremote started it never asks "rejected to unload".

**Acceptance**: probe rows R1, L1, S1.

### Edge Cases

- A panel path whose doubled `;` form exceeds the field: Look in left empty (the search refuses an
  empty Look in with its existing message).
- A single character wider than the message box stands alone; a surrogate pair is never split.
- The clipboard refused inside a SUBST chain of Copy UNC Name: one message (the clipboard's), not
  also "cannot be converted to UNC".
- A Compare Files dialog that registers during an unattended close: refused (no typed name lost).
- An FTP password of exactly 300 bytes (150 two-byte letters) is accepted.

## Requirements

- **FR-001** Look in holds any path up to the program's limit; never cut; heap copies behind it.
- **FR-002** Message box breaks only inside over-wide words.
- **FR-003** Every core user copy command reports a failed copy with the system's reason.
- **FR-004** UTF-8 error fields get UTF-8 text (`LoadStrU8`).
- **FR-005** Disk Map's log list view is Unicode.
- **FR-006** The plug-in folder picker enables OK only for a folder with a path and resolves a
  NetHood folder shortcut.
- **FR-007** The File Comparator's `Release()` closes windows that register while it waits.
- **FR-008** Romanian `IDS_CANTMULTIVOL` starts with a capital letter (pinned).
- **FR-009** Checksum reports a failed save.
- **FR-010** FTP refuses a typed login that does not fit; wipes the panel login's command and
  secret copies; cuts display texts at a whole character.
- **FR-011** RegEdit Find (idle) and FTP Logs / message windows are declared closable for an update.
- **FR-013** A plug-in Save dialog opens in the folder the plug-in asks for (a bare proposed name
  is put into it).
- **FR-012** No plug-in interface change (107), no registry format change, no new string.

## Success Criteria

- **SC-001** saltests: all checks pass, the new pure helpers covered (17,423 -> 17,513).
- **SC-002** Strict encoding guard TOTAL 0; Debug and full Release builds succeed.
- **SC-003** The probe (`probe/batch121_probe.ps1`) passes every row on this build, and its control
  rows show the old behaviour on `Debug_x64_pre121` (GUI runs pending).
