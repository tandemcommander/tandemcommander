# Fix log: feature 118 - plug-in windows and an installer's close request

Branch `118-plugin-update-close` on top of 117 (`72a14a8e`). Decisions by the author (the
maintainer asked for autonomy), listed in `spec.md` Clarifications. No GUI run in this session:
the installed program was in use and another agent ran GUI probes on the hidden desktop - the
probe is written and parse-checked, its runs are owed (`quickstart.md`).

## Decisions per plug-in

| Plug-in | State | Decision |
|---|---|---|
| File Comparator | comparison finished | agree - declared at `WM_CREATE` |
| | still comparing | agree - the comparison is cancelled silently (`CW_EXIT`, as Esc / close) |
| | Compare Files dialog, Options, Go to, any message box ("The files are identical. Close?") | decline - separate undeclared windows |
| Disk Map | scan finished or still running | agree - the scan is aborted by the window's own close |
| | Log window shown, file tooltip shown | agree - both declared (both hold nothing; the tooltip is a plain popup that D8 would count) |
| | About box, Esc close confirmation | decline |
| Checksum | Verify, running or finished | agree - declared at `WM_INITDIALOG` |
| | Calculate: reading folders, calculating, finished but not saved, a type not saved (one save writes one type), partial after Cancel, a row removed after saving, a re-save that truncated a saved list and did not complete | decline - the hashes are the window's work; not declared |
| | Calculate: every calculated type saved and unchanged, or nothing to save | agree - declared |
| | Save dialog, overwrite question, worker error boxes, configuration | decline |
| Batch Renamer | dialog open (masks, options, Undo of renames done), rename running | decline - never declared |

The reading behind "still comparing / scanning / verifying = nothing to lose": the 088 contract
forbids declaring a window with "a running operation" and cancelling "work the user did not ask
to cancel"; an operation is work whose interruption changes or loses data. A read-only computation
whose only product is the view is repeated exactly; closing it after it finished loses the same
view. Recorded in `architecture/06-plugin-architecture.md`.

## Changes

- **File Comparator** (`filecomp.cpp`, `filecomp.h`, `mainwnd.cpp`, `dialogs.cpp`, `dialogs.h`):
  comparator window declared at `WM_CREATE`; `CompareDialogsOpen` counts Compare Files dialogs
  (`WM_INITDIALOG` .. `WM_DESTROY`, modeless and modal); `Release()` during an unattended close
  refuses while one is open, else `CloseAllWindows(FALSE, 5000)` and `KillAll(FALSE, 5000)`.
  Result race (FR-007): in `WM_USER_WORKERNOTIFIES`, with `CW_EXIT` any result posts `CM_EXIT` and
  shows no box (a cancelled worker posts it itself); with `CW_SILENT` (window being destroyed,
  comparison replaced) no box. `CancelWorker` initialised in the constructor.
- **Disk Map** (`DiskMapPlugin.cpp`, `GUI.MainWindow.h`, `GUI.LogWindow.h`, `GUI.ToolTip.h`):
  map, Log and tooltip windows declared right after creation through
  `DiskMapDeclareClosesUnattended`, which - like `DiskMapIsUnattendedClose` - calls the 107 service
  only when `SalamanderVersion >= 107` (Disk Map still loads in cores from 103). `Release()`:
  unattended `KillAll(FALSE, 5000)`; the thread records are freed only after the threads ended
  (before: freed first, so a window thread outliving a refused `Release()` wrote
  `MainWindow = 0` into freed memory).
- **Checksum** (`checksum.cpp`, `dialogs.cpp`, `dialogs.h`): `CSFVMD5Dialog::HoldsWork()`
  (FALSE; Calculate: `!WorkEnded || (!Saved && Save enabled)`), `UpdateClosesUnattended()`
  (declares or withdraws, keeps `WindowsHoldingWork` in step with `Interlocked*`), called at
  `WM_INITDIALOG`, `OnThreadEnd`, after a save, after `DeleteItem`; the counter is decremented at
  `WM_DESTROY`. A save counts only when `ferror` and `fclose` report no error. `Release()` during
  an unattended close refuses while `WindowsHoldingWork > 0`, else 5 s close and thread wait.
- **Batch Renamer** (`renamer.cpp`): `Release()` during an unattended close refuses (silently,
  closing nothing) while a window is open.

No core change, no interface change (107), no strings, no registry or configuration change.

## Code review (coordinator) - ACCEPT pending GUI, fixed in this session

- **S1 (data safety)**: `Saved` was only ever set: after a good save, a second save over the same
  file truncates it at `_wfopen("wb")`; if that write failed the window stayed declared while it
  held the only good copy. Now the save forgets, at the open, every saved type whose list is the
  opened file (volume serial + file index; all of them when the file cannot be identified),
  withdraws the declaration at once, and counts its type again only after `ferror` / `fclose`
  succeed.
- **S2 (decision, the safe one)**: "what the window shows is in the saved file" was false - the
  window calculates every enabled type (five by default) and a save writes one. `SavedTypes` is a
  bit per type; the window is declared only when every calculated type is saved; `DeleteItem`
  clears all. Spec, architecture/06 and CHANGELOG say so.
- **Disk Map `CDiskMap::Abort()` use-after-free** (recorded by me as upstream, R7; reachable by an
  unattended close during a scan): fixed, contained - `CWorkerThread::AbortAndSelfDelete()` sets
  the abort flag while the object is alive, hands it over, and waits on the handle taken before.
  The worker's own clean-up of the detached root (`Aborting() && IsSelfDelete()`) is unchanged.
- **Recorded** (research R7, NEXT-WORK plug-in leftovers 6): Disk Map's `Release()` has no guard
  like the other three (a box, menu or shell operation started from the map between the decision
  and the plug-in's turn gets `WM_CLOSE` inside its loop - pre-existing, milliseconds); the File
  Comparator terminates the remote comparator before a window close that may time out (as on the
  normal path).
- **Probe**: P1 `End-P` called `GetWindow` on `Drv098f` (only `Drv118` declares it) - every row
  after the first decline would have ended in PROBE ERROR; fixed, and every `[Type]::Member` and
  every command of the probe were checked against their declarations (script). P2 the Calculate
  rows shared a folder (C3's list entered C4's selection) - one folder per row now. Added C5 (S2:
  several types, one saved -> decline; NOT DRIVEN if the configuration calculates one type) and
  C6 (S1: every type saved, then type 0 saved again over its own file while the probe holds a
  byte-range lock - the open truncates, the write fails -> decline; NOT DRIVEN when the failure
  does not happen that way, the STATE row says how). C3 now saves every type the Save dialog
  offers. M1/M2 read the scan state from the map's own menu (File > Abort enabled, after
  `WM_INITMENU`); B1, C1-C6 check their own window (`$script:RowWin`); M2's right panel is the
  small folder.

## Review (hostile re-read of the diff)

- *Unsaved work is never lost silently in an unattended close*: Calculate with work and Batch
  Renamer are undeclared (the core declines at the question and again at the instruction), and
  their plug-ins refuse in `Release()` if one appeared in between - nothing is closed before the
  refusal (the checks come first). The File Comparator's Compare Files dialog likewise.
- *Nothing shown*: none of the four `Release()` paths asks anything (verified, also before); the
  comparator's result box after a close request is suppressed; Disk Map's Esc confirmation is only
  on the key, never on `WM_CLOSE`; Checksum's `WM_CLOSE` ends the dialog without a question.
- *Threads stopped before windows go*: comparator `WM_DESTROY` waits for its worker (pumping);
  Disk Map's `OnDestroy` aborts and waits for the scan; Checksum's `WM_DESTROY` stops and waits for
  its worker; then `KillAll(FALSE, 5000)` - never `TerminateThread` in an unattended close (force
  is FALSE). If 5 s are not enough, `Release()` returns FALSE and the core abandons the close (the
  windows asked to close still close - the 088 contract's documented behaviour).
- Found while re-reading and fixed: Disk Map called the 107 services unconditionally although it
  loads in 103-106 cores (now guarded); the comparator's result handler read `CancelWorker`, which
  the constructor left uninitialised (now initialised); a dropped worker's result (`CW_SILENT`)
  could show a box while the window was being destroyed (now suppressed).
- Left, recorded (`research.md` R7, NEXT-WORK item 5 / plug-in leftovers 6): a worker's error box
  can still appear while its window closes (hex view read error, checksum read error) -
  pre-existing, also on a normal exit; Checksum Save never reported write errors.

## Gates

| Gate | Result |
|---|---|
| `Debug_x64_pre118` | copied from `Debug_x64` before the first build (117 build), `Intermediate` removed (350 MB) |
| `build.cmd` Debug | succeeded, 0 warnings, 0 errors (three times: after the change, after my review fixes, after the code review's) |
| `build.cmd full release` | succeeded twice (after my review and after the code review's fixes); runtime closure OK (218 modules); 189 language modules |
| saltests | 14,576 / 0 (unchanged: no pure helper - the decisions are plug-in-local state) |
| `python tools\check_encoding.py --strict` | `TOTAL: 0` |
| Sources | UTF-8 with BOM where they had one (`mainwnd.cpp`, `checksum.cpp` have none - kept), CRLF, no control characters |
| Interface | `src/plugins/shared/` untouched; 107 |
| `PRIVACY.md` | no change: no network, storage, credential, crash-report or installer change |

## Probe (written, not run)

`probe/update_close_probe.ps1` - 20 rows (F1-F4, M1-M4, V1-V2, C1-C6, B1, X1, R1, N2), `-Expect
fixed|before`, hidden desktop only, refuses while any `tandemcommander.exe` runs, registry
exported / restored / SHA-256-compared (`-RegBaseline 9BD42518403B7EDF` reported), plug-in hot
keys set for the session (117 method), fixtures under `%TEMP%\tc118` (a sparse 4 GB file, two
40,000-line text files of one shuffled pool so the comparison cannot shortcut). Each row: fresh
instance, state reached or NOT DRIVEN, `rm_probe.ps1` as a child while the windows of the pid are
polled every 30 ms, then agree (exit 0, process ended with exit code 0, nothing shown but the
core's wait window, no crash report) or decline (exit 1 within 1 s, alive, windows kept, nothing
shown), plus a WORK row where the window's content matters (C1-C6, F4, B1). Parse-checked with
the PowerShell parser (0 errors); every static member it calls and every command it uses checked
against their declarations (098's `fix_probe_lib.ps1` and its own `Drv118`). Commands:
`quickstart.md`.

## Code-only reviews: ACCEPT pending GUI (coordinator)

First review: product code ACCEPT, S1 (a failed re-save left the window declared), S2 (one saved list
did not cover the other hash columns - the safe option taken: every calculated type must be saved),
P1/P2 (probe could not run) - all applied, plus the CDiskMap::Abort use-after-free fixed
(AbortAndSelfDelete). Re-check ACCEPT: the identity is read after "wb" empties the file (CREATE_ALWAYS
keeps the identity), the per-type record is cleared on the only mutation path, exactly one side deletes
the worker under one lock, C6's lock lets the open empty the file and makes the write fail (measured in a
scratch folder). Recorded NIT: on ReFS or shares with zero/unstable file ids the identity check can forget
too much (safe) or too little (reopens the S1 gap on such a share - edge case).

Committed with the GUI runs still owed; the build is preserved as `build\tandemcommander\Debug_x64_118`
(checksum.spl 00:29). Results follow in a separate commit.

## GUI results (2026-10-06, hidden desktop)

Runner `tools\run_on_hidden_desktop.ps1`, one run at a time, on the preserved trees
`build\tandemcommander\Debug_x64_118` (this feature, after the code-review fixes; plug-ins of
00:29) and `Debug_x64_pre118` (the 117 build, the control). Registry: the export's SHA-256 was
`1AB614304771DBE0...` (the maintainer's restored morning state) before and after every run - the
probe's own restore reported "identical" each time; no backup was imported by hand. No
`tandemcommander.exe` was running outside the probes.

**Final results** (`probe/update_close_result.txt`, `probe/update_close_result_pre118.txt`):

| Build | Rows | Result |
|---|---|---|
| `Debug_x64_118`, `-Expect fixed` | 20 | **PASS 58, FAIL 0, NOT DRIVEN 0** |
| `Debug_x64_pre118`, `-Expect before` | 20 | **PASS 67, FAIL 0, NOT DRIVEN 0** |

This build: the update goes through (Restart Manager shutdown 0 after 1.3-2.4 s, the process
ended with exit code 0, no window shown but the core's wait window, no crash report) with a
finished comparison (F1), a running comparison (F2), a finished map (M1), a scan of WinSxS still
running (M2 - File > Abort enabled at the request), the map's Log window (M3), a finished and a
running verification (V1, V2 - 4 GB sparse file), a Calculate window with all five types saved
(C3 - the five lists intact afterwards), all three together (X1) and none (R1). It is declined
(351 `ERROR_FAIL_SHUTDOWN` after 0.0 s, nothing shown, every window kept, the work still in the
window, the ordinary exit afterwards clean) with the "files are identical" box (F3), the Compare
Files dialog (F4), the Disk Map About box (M4), a running Calculate (C1), an unsaved list (C2),
a saved list with a row removed (C4), five types calculated and one saved (C5 - **S2**), a failed
re-save (C6 - **S1**: the probe's byte-range lock let the plug-in open and truncate `cs_c6.sfv`
to 0 bytes and made the write fail; the window then held the only copy and the update was
declined), the Batch Renamer (B1) and the Configuration dialog (N2).

The control: every plug-in row declines (F1, F2, M1-M3, V1, V2, C3, X1 included - their windows
were not declared), R1 agrees; C1-C6's work is kept. That is the 0.1.8 behaviour this feature
changes.

**Probe fixes made during the runs** (probe only - no product file was touched, nothing built):

1. Run 1 (this build): `-like "[SalamanderSaveBits *"` - `[` is a wildcard; every agreeing row
   ended in an ERROR after the request had succeeded. Now `StartsWith`.
2. Run 1: the END rows counted the row's own plug-in windows as stray (End-Row closes only the
   main window); End-P now closes owned dialogs, then the plug-in windows, before End-Row (as
   117's End-P).
3. Run 1: C1 - Change Directory to the file, then Ctrl+Shift+U opened nothing (not analysed
   further; Calculate works on a selection, as in C2) - C1 now selects all in its folder.
4. Runs 1-2: a posted `BM_CLICK` on Save / on the save dialog's button did nothing on the hidden
   desktop - replaced by `WM_COMMAND` to the dialog (`IDC_BUTTON_SAVE`, then `IDOK`).
5. Diagnostic runs (`-Only C3`, `-Only C3,C6`, `-Only C3,C4,C5,C6`, registry hash checked around
   each): the save dialog is the Vista-style one (no control id 1136; the name field is an
   `Edit` 1001 inside a `ComboBox` with id 0) - found by the type list's "*." items and by the
   parent class; it keeps its own name, so each Calculate row saves under the plug-in's default
   name (the folder's name) - `<folder>\<folder>.<ext>`.
6. Control run 1: once, the save dialog did not take the type selection and asked its own
   "replace?" (the list of the previous type existed) - C3 NOT DRIVEN and 140 stray boxes at the
   end (the cleanup closed one box after another). Longer settle times, the shell's question
   answered by closing it, the dialog cancelled, and up to three attempts per type
   (`Save-TypeChecked`, which also checks that `<base><ext>` exists afterwards).

Intermediate result files are kept as the record: `update_close_result_run1.txt` (26 / 19 / 4,
probe bugs 1-4), `_run2.txt` (47 / 0 / 4, the save path), `_run3.txt` (58 / 0 / 0 before fix 6),
`update_close_result_pre118_run1.txt` (63 / 1 / 1, fix 6). **No product defect was found by the
runs.**

## Proposed CLAUDE.md entry (Recent Changes)

- 118-plugin-update-close: **an update goes through with a finished comparison, map or
  verification open** (NEXT-WORK item 4 "Left", interface 107 used as is). Read the 088 contract's
  "running operation" as work whose interruption changes or loses data: a read-only computation
  whose only product is the view (comparison, disk scan, verification) holds nothing to lose, also
  while it runs (recorded in `architecture/06`). Declared: the File Comparator window (cancelled
  silently while comparing), Disk Map's map, Log window and tooltip, Checksum's Verify window, and
  a Checksum Calculate window only while EVERY hash type it calculated is saved and unchanged -
  one save writes one type, five are calculated by default (`HoldsWork` / `SavedTypes` with the
  identity of each saved file / `UpdateClosesUnattended` / `WindowsHoldingWork`; a save forgets
  the types whose file it truncates at the open and counts its own only after `ferror`/`fclose`
  succeed - code review S1/S2). Never: the Batch Renamer (masks, Undo), every
  dialog and message box. `Release()` during an unattended close: `CloseAllWindows(FALSE, 5000)`,
  `KillAll(FALSE, 5000)`, and a silent refusal (closing nothing) while a window with work is open
  (Compare Files dialog, Calculate with work, any renamer window). Fixed on the way: a comparator
  closed while comparing lost the close and showed the result's box when the worker finished at
  that moment; Disk Map freed its thread records before its threads ended (write into freed memory
  after a refused `Release`); `CDiskMap::Abort()` used a finished scan worker after handing it
  over to delete itself (`CWorkerThread::AbortAndSelfDelete`); Disk Map still loads in 103-106
  cores, so it calls the 107 services only when `SalamanderVersion >= 107`. Recorded: Disk Map's
  `Release` has no guard for a box or menu opened in between. Other plug-ins' windows
  recorded (research R6): RegEdit Find and FTP Logs / Welcome still decline. saltests 14,576
  (unchanged). Probe
  `probe/update_close_probe.ps1` (20 rows, `-Expect fixed|before`, hidden desktop): this build
  58 / 0 / 0, the build before 67 / 0 / 0 (every plug-in row declines there). Probe traps
  found on the way: `-like` with `[`, a posted `BM_CLICK` does nothing on the hidden desktop
  (send `WM_COMMAND` to the dialog), the Vista-style save dialog has no control ids and keeps its
  own file name. Owed to a person: a real update / winget upgrade. Records:
  `specs/118-plugin-update-close/fix-log.md`.
