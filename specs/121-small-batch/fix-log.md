# Fix log: feature 121 - the small batch

Branch `121-small-batch`, on top of `120-pictview-leftovers` (a75b3d8e; the branch has since
received the GUI-verification commits of 115 and 116 from other sessions - no file of this feature
is in them). Decisions by the author (the maintainer asked for autonomy): `spec.md`
*Clarifications*. Measurements behind every decision: `research.md` R1-R11. Pre-change build:
`build\tandemcommander\Debug_x64_pre121`; this build preserved for the GUI runs:
`build\tandemcommander\Debug_x64_121` (both without `Intermediate`). Not committed (the coordinator
commits). **No GUI was run** (other agents drive the hidden desktop at night, the maintainer uses
the installed program by day): the probe is written, its runs are owed (`quickstart.md`).

## Per item

| # | Item (recorded by) | Measured | Result |
|---|---|---|---|
| 1 | Find *Look in* cut at 259 bytes (101) | wider: cut inside a character; a typed path cut too; `CSearchForData::Dir` unbounded `strcpy` behind it | fixed (R1) |
| 2 | message box breaks inside words (101) | every paragraph wider than the box was cut at its edge once one long word was in the text | fixed (R2) |
| 3 | clipboard copy commands silent (101) | also the echo variant returned before its message | fixed (R3), no new string |
| 4 | "name already used" code page in a UTF-8 field (103) | narrower: drawn right while the code page matches; letters lost when it does not; 8 sites of the class | fixed (R4) |
| 5 | Disk Map log garbled (104) | code-page list view; UTF-8 paths, code-page texts | fixed (R5) |
| 6 | plug-in folder picker: NetHood, ENABLEOK (104 NIT 3) | as recorded; the core's class-id test is a prefix match | fixed (R6) |
| 7 | "rejected to unload" after fcremote (102) | the thread registers its window after creating it; `Release` found an empty queue | fixed (R7) |
| 8 | Romanian `IDS_CANTMULTIVOL` lower case (119) | as recorded | fixed + pinned (R8) |
| 9 | Checksum Save silent on write errors (118) | small lists fail at `fclose` | fixed (R9), no new string |
| 10 | FTP: typed password cut, command not wiped, torn log texts (116) | wider: user name and host cut too (another account / server) | fixed (R10) |
| 11 | RegEdit Find, FTP Logs / Welcome block an update (118) | as recorded | fixed (R11) |
| 12 | plug-in Save dialogs open another program's folder (117 GUI run; added by the coordinator) | Windows' per-program first-folder rule (measured, "Item 12") | implemented, measured ineffective, **reverted**; recorded |

## T003 - UTF-8 error fields (`worker.cpp`, `safefile.cpp`)

`LoadStrU8` for `IDS_NAMEALREADYUSED` (`DoCreateDir`, dialog case 0), `IDS_COMPRNOTSUPPORTED` /
`IDS_ENCRYPNOTSUPPORTED` (case 5) and the six `DialogError` error texts of `safefile.cpp`
(`IDS_NAMEALREADYUSED[FORDIR]`, `IDS_ERRORCREATINGROOTDIR`). Titles stay `LoadStr` (the dialog sets
its caption through the code page).

## T004 - clipboard (`salamdr4.cpp`, `consts.h`, the callers)

- `CopyHTextToClipboardW` / `CopyHTextToClipboard`, `CopyTextToClipboardW` / `CopyTextToClipboard`
  end with `SetLastError(err)`; the two allocating functions no longer `return FALSE` before their
  echo when the clipboard could not be opened; `CopyTextToClipboardU8` keeps the reason over its
  `free()` (`ERROR_NOT_ENOUGH_MEMORY` when nothing was attempted).
- New core-only `ShowClipboardCopyError(parent, err)` (the system's text, titled with
  `IDS_COPYTOCLIPBOARD` without its accelerator - `SalMenuLabelToTitle`; the echo's error box uses
  it too, it showed "&Copy To Clipboard"), `CopyTextToClipboardU8Report`, `CopyTextToClipboardWReport`.
- Converted: panel Copy Full Name / Name / Full Path (`MainWindow`), Copy UNC Name and the Find
  window's UNC copy (the message parent; a refusal inside a SUBST chain is remembered,
  `UNCCopyReport`, so the outer level does not add "cannot be converted to UNC"), the Find window's
  three copies, Save Selection to the clipboard, the directory line's and the status line's copy
  (no flash after a failure), the file-list copy (`mainwnd4.cpp`), the viewer's copy (both
  routes), Ctrl+C in a message box, the directory line's component copy (`stswnd.cpp`).
- Unchanged: the plug-in services (`showEcho` decides; FTP shows its own message for FALSE).
  After the review: the block of a failed copy is freed unless the clipboard took it.

## T005 - message box (`src/common/salmsgwrap.h` new, `msgbox.cpp`)

`SalMsgWrapBreaks` (template, `char` / `WCHAR`): breaks only inside a run of non-white-space units
wider than the limit; after the last `\` or `/` that keeps the piece within the limit when the piece
is at least a third of it, else before the first unit that does not fit; never inside a surrogate
pair; a unit wider than the limit alone. `DuplicateStrAndInsertEOLs(W)` share `InsertEOLsAux`
(per-unit advances from `GetTextExtentExPoint`, then one copy with the breaks). The caller's flow
(`DrawText` -> wider than the limit -> insert -> measure again) is unchanged.

## T006 - Find *Look in* (`src/common/salfindtext.h` new, `find.h`, `find.cpp`, `finddlg1.cpp`)

- `LOOKIN_TEXT_LEN` = `SAL_MAX_PATH_UTF8`, `LOOKIN_TEXT_CHARS` = `SAL_MAX_PATH_W` (the combo's
  `CB_LIMITTEXT`, set after `HistoryComboBox` in `Transfer`).
- Constructor: `SalFindLookInFromPath` (`;` doubled; FALSE and empty when it does not fit).
- `Validate`: the Look in backup with `DupStr`; `BuildSerchForData`: the copy with `DupStr`, freed on
  both exits; `CSearchForData::Dir` with `DupStr` (destructor frees; an item whose copy failed is
  dropped); the search thread skips a NULL `Dir`.
- Browse: the field read whole (`GetWindowTextLengthW`, heap); its result buffer
  `2 * MAX_PATH + 8` (every `;` of a MAX_PATH path doubled + "; " on both sides; was
  `MAX_PATH + 200`).
- `BuildItemName`: `SalFindComposeItemName` (bounded to `ITEMNAME_TEXT_LEN`, cut at a whole
  character only when it had to be cut), "in" through `LoadStrU8`.
- Size: `CFindOptionsItem` is about 100 KB now (heap everywhere except `CFindOptionsItem def` in
  `Save`, main thread, 3 MB stack).

## T007 - Disk Map log (`GUI.LogWindow.h`, `splunicode.h`)

The frame answers `WM_NOTIFYFORMAT` with `NFR_UNICODE` and sends `NF_REQUERY` to the list after
creating it; `LVN_GETDISPINFOW` copies into the list's buffer (`cchTextMax`), converting with the new
`SplDisplayTextToWAlloc` (UTF-8 / WTF-8; a torn last character dropped; else the code page). The
column headers stay `LVM_INSERTCOLUMNA` (valid on any list). New in `splunicode.h` as well:
`SplU8TrimTornTail`, `SplU8CopyTrunc` (used by FTP).

## T008 - folder picker (`splfiledlg.h`)

`BrowseCallback`: `BFFM_SELCHANGED` -> `BFFM_ENABLEOK` with `SHGetPathFromIDListW` (the core's
`DirectoryBrowse` rule). `SplFileDlgDetail::IsFolderShortcutIni` (the whole class id between the
braces; the core accepted a prefix) and `ResolveNetHoodFolderW` (local fixed drive only;
desktop.ini of at most 1,000 bytes naming the class; target.lnk exists and is a file;
`IShellLinkW::GetPath(SLGP_UNCPRIORITY)` without `Resolve`, as the core). `SplBrowseForFolderU8`
converts the target (or the picked folder) and refuses a result that does not fit as before.
Callers unchanged (PictView, CAB, Undelete x3). saltests resolve a real folder shortcut made in
`%TEMP%` (an accented shortcut folder and target).

## T009 - File Comparator `Release` (`filecomp.cpp`)

Not forced: after the first close of the queue, `KillAll(FALSE, slice <= 100 ms)` in a loop within
the old budget (1 s, 5 s unattended); a window that registered meanwhile is closed
(`CloseAllWindows`, failure = refusal as before) and its thread gets a fresh budget; an unattended
close refuses when a Compare Files dialog appeared (`CompareDialogsOpen`, 118's rule). Bounded: the
receiver is terminated before, the menu runs on the main thread (in `Release`), a thread registers
at most a dialog and then a window. Forced: `KillAll(TRUE)` as before.

## T010 - Romanian (`translations/romanian/zip.slt`, `translations/ui-overrides.json`)

Row 1060 "Arhiva cu acelasi nume ..." (capital A; wording and the corpus' missing diacritics kept);
pin `zip/romanian/IDS_CANTMULTIVOL` with `_feature_121` note. The row was already `human` in
`zip.origin`. The full Release build regenerated `romanian.slg` of the ZIP plug-in.

## T011 - Checksum Save (`checksum/dialogs.cpp`)

`_doserrno = 0` after the open; after the writes `ferror` takes `_doserrno`, a failing `fclose`
(the buffered tail) takes its own; a failure shows `Error(..., IDS_SAVE_TITLE,
IDS_ERRORCREATINGFILE)` (+ the system's text, `ERROR_WRITE_FAULT` if the CRT kept no code). 118's
bookkeeping (`SavedTypes`) unchanged.

## T012 - FTP (`salftpsecret.h`, `fs2.cpp`, `fs5.cpp`, `ctrlcon1.cpp`, `operats2.cpp`)

- `SalFtpTypedLoginTooLong(userPart, 610, user, 101, host, 201, password, 301)` after the host
  check in `ChangePath` (`fs2.cpp`) and the upload target (`fs5.cpp`): refused with the plug-in's
  `IDS_TOOLONGPATH` (the user part is part of the path), the copy wiped, nothing set.
- `StartControlConnection`: `SecureZeroMemory` of `proxySendCmdBuf` and `proxyScriptParams` before
  its only `return`.
- `tmpCmdBuf` (wait window) and the worker's log copy through `SplU8CopyTrunc`;
  `connectingToAs[200 + HOST_MAX_SIZE + USER_MAX_SIZE]`.

## T013 - update close (`regedt/finddlg2.cpp`, `ftp/dialogs2.cpp`)

RegEdit `CFindDialog`: declared at `WM_INITDIALOG`, withdrawn where `SearchInProgress = TRUE`,
declared again at `WM_USER_SEARCH_FINISHED` (the only places the flag changes). FTP `CWelcomeMsgDlg`
(welcome message, server reply, raw listing) and `CLogsDlg`: declared at `WM_INITDIALOG`. Both
plug-ins require interface 107 to load - no version guard.

## T014a - Save dialogs (item 12) - reverted, see "Item 12" below

## Gates

| Gate | Result |
|---|---|
| saltests | **17,498 checks, 0 failed** (17,423 + 75 in `TestSmallBatch121`; the item-12 helper tests left with the revert) |
| strict guard (`tools\check_encoding.py --strict`) | TOTAL 0 |
| Debug build (`build.cmd`) | exit 0; only pre-existing warnings (C4267 / C4005 / C4018 / C4244 in untouched lines of plug-ins and `salamdr2.cpp` / `zip.cpp` - surfaced because `splunicode.h` recompiled every plug-in) |
| full Release build (`build.cmd full release`) | exit 0, BUILD SUCCEEDED; 20 plug-ins registered, 189 language modules, runtime closure OK (218 modules); the same pre-existing warnings, none in a changed line |
| probe | `probe/batch121_probe.ps1` written: PowerShell parser 0 errors, its C# compiled with `Add-Type`; **not run** |
| encodings | sources BOM + CRLF kept per file (checked with Python); new headers BOM + CRLF; probe pure ASCII CRLF; specs LF without BOM |

## Recorded, not changed

- Find: a Look in path near the program's maximum that `CSalPathBuf` cannot take (it adds a
  backslash) stops the search with a trace only (`find.cpp`, coordinator review NIT 4).
- FTP `ChangePath` (`fs2.cpp`) with a connection already open was not examined for the cut user
  name (the upload target `fs5.cpp` was - fixed).
- A truncated checksum list stays on disk after the write error (the message says so; deleting it
  was not asked for).
- FTP: a typed server path is still cut at `FTP_MAX_PATH` when stored (the user part over 609 bytes
  is refused now); a custom proxy-script line over 1,000 bytes is cut without CRLF (116 record).
- Not driven by the probe: the folder picker in the GUI (a tree-view pick), FTP's welcome-message
  window (needs a server), the FTP wipes and display cuts (memory / display only), the Find window's
  copy commands (the same helper as C1-C3).
- `PRIVACY.md` not changed: no stored value, no transmitted value and no protection of a stored
  credential changes - the refusal only stops a cut login from being sent, and the wipe is memory
  hygiene of a copy (116 judged its shared wipes the same way).

## Review

Code-only independent review (a separate agent, read-only, the whole diff): **ACCEPT**, no
blocker, no SHOULD-FIX. It verified the heap ownership of the Find changes (and found the two
stack instances of the ~100 KB `CFindOptionsItem`: `find.cpp` `def`, `finddlg2.cpp` `tmp` on the
Find thread - 3 MB stacks), the break helper's bounds, the last-error chain, that FTP's FALSE
messages are not doubled, the `Release` loop's termination, the FTP refusal's arithmetic, and the
RegEdit declaration on every path. Its NITs:

1. `SplDisplayTextToWAlloc` dropped the last letter of code-page text ending in one byte >= 0xC0
   ("Fichier utilisé" in CP1252) - **fixed**: a torn tail is trimmed only with evidence the text is
   UTF-8 (the cut sequence had a continuation byte, or the rest has a non-ASCII character); tests.
2. The Options Manager's list copies `ItemName` into 260 bytes (`finddlg2.cpp`) - with longer Look
   in texts a cut more often tears a character - **fixed** (`SalU8TrimIncompleteTail` after it).
3. RegEdit Find: the search thread started before the declaration was withdrawn - **fixed**
   (withdrawn before `Create`, restored if it fails).
4. The global block leaked when the clipboard was not opened - **fixed** in `CopyTextToClipboardW`
   and `CopyTextToClipboard` (`...Ex(..., &taken)`: freed unless `SetClipboardData` took it). It
   also noted that `viewer3.cpp` freed its block after any failure, also when only the second
   format failed and the clipboard owned the block (a double free, pre-existing) - resolved by the
   coordinator review's NIT 2 below (such a copy is a success now).
5. Disk Map's `LogError` logged an uninitialised buffer when `FormatMessage` failed (119-byte
   buffer) - **fixed** (512 units, checked, `IGNORE_INSERTS`, "Error <code>" fallback;
   `TreeMap.FileData.CZRoot.h`).
6. A 610-byte user part whose parts each fit is refused now where one path byte was cut -
   recorded (the corner the rule names).

Then item 12 was added (coordinator) and built.

### Coordinator's code-only review: ACCEPT pending GUI

(saltests, guard, a 300,000-text fuzz of `SalMsgWrapBreaks` with 0 violations.) Fixed:

- **SF1** - with the proposed name put into the folder, a folder that is gone (PictView's remembered
  save folder, FTP's remembered folders after a USB stick is removed) or a whole that is too long
  makes the dialog refuse (FNERR_INVALIDFILENAME), and the old retry cleared the name AND the
  folder - "Clipboard1" / "ftp.log" lost (before 121 Windows ignored the bad folder and kept the
  name). Now `NameIntoInitialDir` returns the prefix length and `BareNameBack` restores the bare
  name for a first retry with the initial folder (the pre-121 call), then the old retry with
  neither - in `SplGetFileNameU8`, PictView's `SaveAsDialogU8` and Checksum's Save (first round
  only; later rounds hold the user's full path). Tests.
- NIT 1 - Disk Map's log: the copy into `cchTextMax` no longer ends in a lone high surrogate.
- NIT 2 - a copy whose primary format was stored is a success even if the derived second format
  failed (Windows derives it); so a FALSE always means the caller still owns the block - which
  also resolves the viewer's double free recorded by the first review (it frees only after FALSE).
- NIT 3 - the upload target (`fs5.cpp`): a typed user name over 100 bytes was cut and compared
  with the open connection's user - a longer name with the same first 100 bytes uploaded into the
  current account (before 121). Such a path is now never "this connection" (it then reaches the
  new-connection refusal).
- NIT 5 - the CHANGELOG names each dialog's folder (PictView: the picture's or its last save
  folder).
- NIT 4 recorded below.

## Independent code-only review (coordinator): ACCEPT pending GUI

saltests 17,507/0; guard 0; SalMsgWrapBreaks fuzzed on 300,000 random UTF-16 texts (0 violations:
breaks ascend, never on white space, never split a surrogate pair); FTP refusals come before any
connection field is set; Find heap buffers; clipboard semantics; File Comparator KillAll loop
bounded; declarations withdrawn during searches; Romanian row structure verified. SHOULD-FIX (Save
dialogs lost the proposed name when the folder vanished or the combined path was too long) and NITs
1, 2, 3, 5 applied by the author; NIT 4 recorded. saltests after the fixes 17,513/0.

Committed with the GUI runs still owed; the build is preserved as
`build\tandemcommander\Debug_x64_121`. Results follow in a separate commit.

## GUI results (2026-10-06, hidden desktop, one run at a time)

Builds: `Debug_x64_121` (this feature) and `Debug_x64_pre121` (the control). Registry export
`1AB614304771DBE0` before and after every run (each probe also restores and verifies the key
itself - identical every time); no instance left running, fixtures removed. ACP 1250, Czech
Windows; the session cannot open the clipboard (rows C1-C3 rely on that).

### Probe fixes made during the runs (probe only, `probe/batch121_probe.ps1`)

- Run 1: the Find fixture paths were 258 / 277 bytes (did not reach the old cut) - components made
  longer (438 / 435 bytes); `Close-Boxes` closed the Find window itself (a `#32770`) after F2 - it
  now keeps it; `-like "[...` is a wildcard error in PowerShell (R1 / L1) - `-match` with an escaped
  class name; D1's map and log windows are closed before its END row.
- Run 2: the core refuses a typed Change Directory path over 259 bytes ("The path specified is too
  long") and the F5 target field too - a password over 300 bytes cannot reach the FTP plug-in
  through either route (the plug-in's password check is defensive); P2 dropped, P3 shortened (220
  bytes), P4 / P5 added on the F5 target; a row whose plug-in starts connecting ends its instance
  (the FTP wait window ignores a posted Esc).
- Runs 3-4: K1 drives the save dialog as 117's probe does (type the folder + OK, then the name + OK -
  the common item dialog ignores `WM_SETTEXT`); new row K0 reads the folder the dialog opened in
  through UI Automation.

### This build (`batch121_result.txt`, + `batch121_result_k1.txt` for K1)

29 PASS, 1 FAIL, 1 NOT DRIVEN in the full run; K1 then PASS in its own run (the full run predates
the K1 driving fix). Rows: F1 PASS (Look in 439 bytes = the panel path, `;` doubled), F2 PASS (1
found), F3 PASS (typed 435 bytes, 1 found), M1 PASS (single line breaks 1, all inside the name; the
template sentences whole), C1-C3 PASS (one box "Copy To Clipboard", "(5) Přístup byl odepřen."),
N1 PASS (French text exact on CP1250), K1 PASS ("Error creating file." + the lock's reason, in its
own run), D1 PASS (the junction `j\u0159\u00ED\u017E` named exactly), P1 / P5 PASS (the plug-in's
"too long path"), P3 PASS (no refusal, connecting), P4 PASS (refused by the core), R1 / L1 PASS
(the installer's request agreed in 1.3 s, exit 0), S1 PASS (6 of 6 rounds: no box, exit 0), every
END row PASS. **K0 FAIL** - see the product finding below.

### The build before (`batch121_result_pre121.txt`, `batch121_result_k1_pre121.txt`)

The old behaviour on every row: F1 Look in 259 bytes (cut), F2 / F3 0 found (INFO), M1 a break
inside the template, C1-C3 silent, N1 "déja" (best fit), K1 silent, D1 mojibake, P1 / P5 connecting
with the cut user name, R1 / L1 declined in 0.0 s, **S1 "rejected to unload. Force?" in 6 of 6
rounds**, K0 the same wrong folder. Its 2 FAIL rows are the END rows of P1 / P5 (the old build
connects and keeps retrying 127.0.0.1:1 - the probe ends only the expected-connecting rows).

### Regressions on this build

| Probe | Result |
|---|---|
| 101 `leftovers_probe` (`leftovers101_on121.txt`) | 20 PASS / 0 FAIL / 4 NOT DRIVEN (the paste rows: no clipboard - as in 101) |
| 102 `filecomp_probe` (`filecomp102_on121.txt`) | 94 PASS / 0 FAIL / 1 NOT DRIVEN (`mism`: no `-OtherFcremote`) |
| 117 `csumlist_probe` (`csumlist117_on121.txt`) | 82 PASS / 0 FAIL / 0 NOT DRIVEN (its Save rows type the folder first) |
| 118 `update_close_probe` (`update_close118_on121.txt`) | 43 PASS / 4 FAIL / 4 NOT DRIVEN - C3-C6 (Checksum saves) not reached, their END rows FAIL; control `update_close118_C3_on_pre121.txt`: C3 PASS on the build before |

### Product finding of the first GUI session (resolved by the revert below)

**Item 12 does not work, and it breaks 118's probe C3-C6.** Row K0: Checksum's Save dialog opens in
`C:\Program Files\Notepad++` on BOTH builds, although 121 puts the panel folder into `lpstrFile`.
The documented order (`OPENFILENAME::lpstrInitialDir`, Windows 7 and later) explains it: (1) if
`lpstrInitialDir` has the value passed the first time the program used the dialog, the most
recently used folder wins; (2) only otherwise a path in `lpstrFile`; (3) then
`lpstrInitialDir`. Rule 1 comes BEFORE the path in `lpstrFile`. Side effect on 118's probe: it sets
the whole path into the name field with `WM_SETTEXT`; with a bare proposed name (before) the dialog
took it, with the full proposed path (121) the dialog keeps its own name and saves into its folder
("cs_c3" into Notepad++ - "no permission, save into pavel?"), C3-C6 not reached. A person typing is
not affected (the same folder and name as before 121). Proposed fix (next feature): pass
`lpstrInitialDir = NULL` when the folder is in `lpstrFile` (rule 2 then applies), restore it for
the bare-name retry - in `SplGetFileNameU8`, PictView's `SaveAsDialogU8` and Checksum; then re-run
K0 and 118 C3-C6. Until then CHANGELOG's line about the Save dialogs is not true.

## Item 12 - measured, reverted (2026-10-06, after the GUI runs)

The coordinator asked to pass `lpstrInitialDir = NULL` when the folder is in `lpstrFile` and to
measure. Done, built, probe row K0 on `Debug_x64_121`: **still `C:\Program Files\Notepad++`**.

Measured with a harness (`scratchpad`, a C# program NAMED `tandemcommander.exe` - the remembered
folder is keyed by the file name; hidden desktop; each dialog read through its address bar and
cancelled), panel folder F, in this order in one process:

| Variant | Opened in |
|---|---|
| A `lpstrInitialDir` = F, `lpstrFile` = bare name (before 121), the process's first dialog | F |
| B `lpstrInitialDir` = NULL, `lpstrFile` = F\name (121 after the coordinator's change) | Notepad++ |
| C `lpstrInitialDir` = F, `lpstrFile` = F\name (121 as committed) | Notepad++ |
| F `IFileSaveDialog::SetDefaultFolder(F)` | Notepad++ |
| G `IFileSaveDialog::SetFolder(F)` | F |
| A again | Notepad++ |

And the registry (read only): `HKCU\...\Explorer\ComDlg32\FirstFolder` holds, per program PATH
(every build tree has its own entry), the first initial folder that program ever passed; the
last-used folder (`LastVisitedPidlMRU`) is keyed by the file name and is shared by every copy of
`tandemcommander.exe` - for all of them it is `C:\Program Files\Notepad++`. So: a dialog asked for
the folder that is that program's recorded first folder opens in the last-used folder instead
(Windows' rule 1, by design - "the program always asks for the same folder, so honour the user's
choice"); any other folder opens as asked. 117's observation and this probe's K0 came from fixture
folders that were the same in every run, so they had become the recorded first folder. Putting
the folder into `lpstrFile` changes nothing of that; only `IFileDialog::SetFolder` opens a given
folder every time - a change of API (Checksum's dialog and `SplGetFileNameU8` could move,
PictView's hooked Save As could not), not a fix for this batch.

Decision: **reverted to the behaviour before 121** (`lpstrInitialDir` = the folder, the bare
proposed name; the old invalid-name retry) in `SplGetFileNameU8`, PictView's `SaveAsDialogU8` and
Checksum's Save; `NameIntoInitialDir` / `BareNameBack` and their tests removed; the CHANGELOG line
removed; the measured rule recorded at the three call sites and in NEXT-WORK (an `IFileDialog`
feature if wanted). The review's SF1 (a lost name) is moot with the revert.

After the revert (`Debug_x64_121` re-copied; registry `1AB614304771DBE0` before and after each run):
- `batch121_probe.ps1 -Only K1` (`batch121_result_k1.txt`): K1 PASS ("Error creating file." +
  the lock's reason); K0 INFO - opened in the panel's folder `...\tc121\cs` (this program path's
  recorded first folder is now another one).
- 118 `update_close_probe -Expect fixed` (`update_close118_on121.txt`): **58 PASS / 0 FAIL / 0
  NOT DRIVEN** - C3-C6 pass again.
- Note: the harness and every probe run add `FirstFolder` entries for the program paths they run
  (Windows writes them; outside the program's key - not restored by the probes).

## CLAUDE.md "Recent Changes" entry (proposed)

- 121-small-batch: **eleven small defects of the backlog, measured first** (`research.md`; no GUI
  run allowed). Find's *Look in* holds any path the program can (`SAL_MAX_PATH_UTF8`, limit
  `SAL_MAX_PATH_W` units; a panel path that does not fit is left out, never cut - it was cut at 259
  bytes, inside a character too; heap copies behind it, `CSearchForData::Dir` was an unbounded
  `strcpy`; `src/common/salfindtext.h`). The message box breaks lines only inside a word wider than
  the box, after a path separator when it can (`SalMsgWrapBreaks`, `src/common/salmsgwrap.h`) - it
  cut every paragraph at its edge. Every core copy command reports a failed copy with the system's
  reason under "Copy To Clipboard" (`CopyTextToClipboardU8Report` / `WReport` /
  `ShowClipboardCopyError`; the copy functions leave the reason in `GetLastError`; the echo variant
  was silent too); the plug-in services unchanged. UTF-8 error fields get `LoadStrU8` (8 sites;
  only a code page lacking the language's letters showed it). Disk Map's log list view is Unicode
  (`NFR_UNICODE`, `SplDisplayTextToWAlloc`). `SplBrowseForFolderU8` enables OK only for a
  file-system item and resolves NetHood folder shortcuts (whole class id). The File Comparator's
  `Release` closes windows that register while it waits (the fcremote "rejected to unload" race).
  Checksum reports a failed save. FTP refuses a typed user name / host / password that does not fit
  (`SalFtpTypedLoginTooLong`, "too long path" - a cut was another account or server), wipes the panel
  login's last command and secret copies, cuts display texts at a whole character
  (`SplU8CopyTrunc`). RegEdit's Find (while idle) and FTP's Logs / message windows are declared for
  an update (interface 107). Item 12 (Save dialogs opening another folder, found by 117's GUI run)
  measured and reverted: Windows records each program path's first initial folder
  (`ComDlg32\FirstFolder`) and opens the last-used folder when asked for that one again; only
  `IFileDialog::SetFolder` overrides it. Romanian `IDS_CANTMULTIVOL`
  capitalised and pinned. Code-only review ACCEPT (its NITs fixed: a code-page tail kept, the
  clipboard block freed, the RegEdit declaration withdrawn before the thread, Disk Map's
  `FormatMessage` buffer). No new string, interface 107, no registry change. saltests 17,423 ->
  17,498. Probe `probe/batch121_probe.ps1` (`-Expect fixed|before`): this build every row PASS (K0
  reported), the build before shows every old behaviour (S1 "rejected to unload" 6/6); regressions
  101, 102, 117 clean, 118 58/0 after the item 12 revert. Records: `specs/121-small-batch/fix-log.md`.
