# Feature Specification: an update goes through with a finished comparison, map or verification open

**Feature Branch**: `118-plugin-update-close`
**Created**: 2026-10-05
**Status**: Implemented - GUI runs pending
**Input**: `specs/NEXT-WORK.md` item 4, "Left" (left by feature 088): "windows of the non-viewer
plug-ins (File Comparator, Batch Renamer, Disk Map, Checksum) still decline an update".

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options. No GUI run
was possible (the installed program was in use, and another agent ran GUI probes of older
features): the research is code reading (`research.md`); the GUI evidence is the pending probe
(`quickstart.md`). Plug-in interface 107 of feature 088 is used as it is - no new service.

- Q: What does "holds nothing to lose" mean for a window that is still working? -> A: The 088
  contract (A1/A2) forbids declaring a window with "unsaved input, a running operation or a
  transfer" and forbids cancelling "work the user did not ask to cancel". **Read here**: an
  operation or work is something whose interruption changes or loses data - a file operation, a
  transfer, a result that exists nowhere but in the window and was meant to be kept. A read-only
  computation whose only product is what the window shows (a comparison, a disk scan, a
  verification) is not: it can be repeated exactly, and closing the window after it finished
  loses the same view. The maintainer's own lean for Disk Map ("scanning / finished: nothing to
  lose") is this reading. Recorded in `architecture/06-plugin-architecture.md`.
- Q: File Comparator? -> A: **Declared in every state** - finished, and also while comparing (the
  comparison is cancelled silently, exactly as Esc / close does). Its dialogs (Compare Files,
  Options, Go to ...) and message boxes ("The files are identical. Close?", errors) are separate
  undeclared windows: while one is open the update is declined. A result that arrives after the
  close request (a race) no longer shows its message box.
- Q: Disk Map? -> A: **Declared** - scanning and finished (the scan is aborted by the window's
  own close). Its Log window and its file tooltip are declared too (both hold nothing and would
  otherwise decline while shown); its About box and its Esc close confirmation decline.
- Q: Checksum? -> A: **Verify window: declared** (running or finished - it only reads the list
  and the files). **Calculate window: declared only when it holds nothing unsaved** - after its
  hash type it calculated was saved (one save writes one type - by default the window calculates
  five: CRC, MD5, SHA1, SHA256, SHA512) and nothing changed since, or when the calculation
  produced nothing to save. While it reads folders or calculates, and while it holds a hash type
  that was not saved (also a partial list after Cancel, also after a row was removed, also after
  a re-save truncated the file of a saved type and did not complete), it declines: the hashes are
  the work the window exists to produce. (Code review S1/S2: the first version declared the
  window after any one save and never withdrew it on a failed re-save.)
- Q: Batch Renamer? -> A: **Never declared.** Its dialog holds typed masks and options and the
  undo list of renames already done (closing it loses the Undo); during a rename it is disabled.
  It keeps declining in every state - the decided behaviour, not a leftover.
- Q: What does `Release(parent, FALSE)` do during an unattended close? -> A: Shows nothing (none
  of the four asked anything there before either - verified). File Comparator, Disk Map and
  Checksum close their windows and let their threads end with the 5 s the 088 viewers get
  (`CloseAllWindows(FALSE, 5000)`, `KillAll(FALSE, 5000)`), never forced. **A guard, not relied
  on**: if a window that holds work is open at that moment (it was opened or changed between the
  core's decision and the plug-in's turn), the plug-in refuses silently and closes nothing - File
  Comparator for an open Compare Files dialog, Checksum for a Calculate window with work, Batch
  Renamer for any of its windows.
- Q: Other enabled plug-ins with top-level windows? -> A: Recorded, not changed (`research.md`
  R6): the Registry Editor's Find window and the FTP plug-in's Logs and Welcome Message windows
  decline; FTP and SFTP decline anyway while a panel shows their file system (080 D7). The
  remaining enabled plug-ins have no top-level windows of their own outside modal dialogs.
- Q: New strings, registry, interface? -> A: None. Interface stays 107, no configuration change.

## User Scenarios & Testing

### User Story 1 - An update is not blocked by a finished piece of work left open (Priority: P1)

A user compared two files, mapped a disk or verified a checksum list and left the window open. A
package manager updates Tandem Commander while nobody is at the machine.

**Acceptance Scenarios**:

1. **Given** a File Comparator window with a finished comparison, **When** the installer asks the
   program to close, **Then** the program agrees, closes the window without showing anything and
   ends (before: the update failed).
2. **Given** a Disk Map window (scan finished or still running, Log window shown or not), **When**
   the installer asks, **Then** the program agrees and ends; a running scan is aborted.
3. **Given** a Checksum Verify window (finished or still verifying), **When** the installer asks,
   **Then** the program agrees and ends.
4. **Given** a File Comparator window that is still comparing, **When** the installer asks,
   **Then** the program agrees; the comparison is cancelled without a message.

### User Story 2 - Work that would be lost keeps the program running (Priority: P1)

1. **Given** a Checksum Calculate window whose hashes were not saved (or are still being
   calculated, or were changed after saving), **When** the installer asks, **Then** the program
   declines at once, shows nothing, and the window keeps its list.
2. **Given** a Calculate window whose every calculated hash type was saved, **When** the
   installer asks, **Then** the program agrees and the saved files are unchanged.
3. **Given** a Calculate window with several hash types of which only one was saved, or whose
   re-save over a saved list failed after the file was truncated, **When** the installer asks,
   **Then** the program declines.
4. **Given** a Batch Renamer dialog, **When** the installer asks, **Then** the program declines
   and the dialog keeps the masks and its Undo.
5. **Given** a dialog or message box of any of these plug-ins (Compare Files, "The files are
   identical", Disk Map About), **When** the installer asks, **Then** the program declines.

### User Story 3 - Nothing changes for a person (Priority: P2)

1. **Given** any of these windows, **When** the user exits the program normally, **Then** the
   behaviour is that of 0.1.8 (the windows close; Batch Renamer and Checksum ask nothing, as
   before).
2. **Given** a comparison the user closes while it runs, **When** the comparison ends at that
   moment with a result, **Then** the window closes (before: the result's message box appeared and
   the close was lost).

### Edge Cases

- A Disk Map window thread that outlives a refused `Release()`: it wrote into freed memory (the
  thread items were freed before the threads ended) - fixed on the way (FR-008).
- Disk Map still loads in cores from interface 103: the 107 services are called only in a 107
  core (FR-009).
- A plug-in window opened or changed between the core's decision and the plug-in's turn: the
  plug-in refuses silently (FR-006).
- A worker of a verification or comparison that hits a read error exactly while the window
  closes can still show its error box (owned by the closing window, pre-existing, recorded).
- Disk Map's scan worker: `CDiskMap::Abort()` handed the worker over to delete itself before
  aborting it - a worker that had already finished was used after it was freed; now reachable
  by an unattended close during a scan, so fixed (FR-011).

## Requirements

### Functional Requirements

- **FR-001**: The File Comparator's comparator window MUST be declared closes-unattended for its
  whole life; its dialogs and message boxes are not.
- **FR-002**: Disk Map's map window, its Log window and its file tooltip MUST be declared.
- **FR-003**: Checksum's Verify window MUST be declared; its Calculate window MUST be declared
  exactly while it holds nothing unsaved (calculation ended and every calculated hash type saved
  completely and unchanged since, or nothing to save), and withdrawn otherwise - also from the
  moment a save opens (truncates) the file of a saved type until that save completes.
- **FR-004**: Batch Renamer's windows MUST NOT be declared.
- **FR-005**: During an unattended close, `Release(parent, FALSE)` of the four plug-ins MUST show
  nothing; File Comparator, Disk Map and Checksum close their windows with a 5 s wait for windows
  and threads, never forced.
- **FR-006**: During an unattended close, a plug-in MUST refuse (return FALSE, close nothing) when
  one of its windows holds work: a Compare Files dialog, a Calculate window with work, any Batch
  Renamer window.
- **FR-007**: A comparator window asked to close while comparing MUST close without showing the
  result's message box when the worker finishes before it sees the request; a result of a worker
  that is being dropped (window destroyed, comparison replaced) shows no box.
- **FR-008**: Disk Map's `Release()` MUST free its thread records only after the window threads
  ended.
- **FR-009**: Disk Map MUST call `IsUnattendedClose` / `SetWindowClosesUnattended` only in a core
  of interface 107 or later.
- **FR-010**: No new interface, string, registry value or configuration version.
- **FR-011**: Disk Map MUST NOT touch a scan worker after handing it over to delete itself.

## Success Criteria

- **SC-001**: The probe (`probe/update_close_probe.ps1`) on this build: every row PASS - agree in
  F1, F2, M1-M3, V1, V2, C3, X1, R1; decline (within 1 s, nothing shown, windows and work kept) in
  F3, F4, M4, C1, C2, C4, C5, C6, B1, N2.
- **SC-002**: The same probe on the build before (`-Expect before`): every plug-in row declines
  (the control), R1 agrees.
- **SC-003**: Debug and full Release builds, `saltests` 14,576 / 0, encoding guard strict
  `TOTAL: 0`.
