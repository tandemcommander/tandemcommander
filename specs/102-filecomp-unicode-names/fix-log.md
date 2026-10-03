# Fix log: feature 102 - File Comparator names

Branch `102-filecomp-unicode-names`, from `101-small-leftovers`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T003 - S1: the dialog, the comparator window, the texts, the buffers

All in `src/plugins/filecomp` unless said otherwise. No plug-in interface change (107), no new
string, no registry format change.

### The Compare Files dialog (`dialogs.cpp`, `dialogs.h`)

| Site | Before | Now |
|---|---|---|
| path combos' subclass (`DragDropEditProc`, `WM_INITDIALOG`) | `SetWindowLongPtr` A + `CallWindowProc` A: the combo became a code-page window (measured, research 1b #7), every text set into it or read from it lost characters outside the code page; messages after the dialog object was detached were swallowed (`return NULL`) | `GetWindowLongPtrW`/`SetWindowLongPtrW` + `CallWindowProcW`; the original procedure is a window property (`TandemFcOldPathProc`), restored at `WM_NCDESTROY`; the combo stays Unicode (probe: `combo unicode True`) |
| field transfer (`Transfer`, `Validate`) | winliblt `EditLine` (UTF-8 through `MAX_PATH`; a lone surrogate or an overflow fell back to the code-page read) | own UTF-16 transfer: `GetWindowTextW` -> `SplWToU8Alloc` (WTF-8), `SplU8ToWAlloc` -> `SetWindowTextW`; buffers `FC_NAME_SIZE`. winliblt's `EditLine` is **not** changed (the dialog no longer needs it) |
| history fill | `CB_ADDSTRING` A with the UTF-8 history: every non-ASCII name garbled (U+0159 shown as U+0139 U+2122), a picked entry "did not exist" | `CB_ADDSTRING` W from the UTF-8 history (`AddHistoryItemW`; code-page text of an older source converted with `CP_ACP`) |
| `WM_USER_CLEARHISTORY` | `WM_GETTEXT`/`WM_SETTEXT` A, `MAX_PATH` | W, the text's real length |
| drop onto a field | `DragQueryFile` A (best fit: `voil<U+00E0>` -> `voila`, measured), `MAX_PATH` | `DragQueryFileW` with the real length, `SetWindowTextW` |
| Browse | `GetDlgItemText` A, `CB_GETLBTEXT` A into an uninitialized buffer when the history was empty, `SG->SafeGetOpenFileName` (code page only) | `BrowseForFileW`: `GetOpenFileNameW` in the plug-in (a W service would be interface 108), 32,768-unit buffer, the folder of the first history item as initial folder (only when there is one), the core's retry mirrored (`FNERR_INVALIDFILENAME` -> Documents, else Desktop, empty name), `SetWindowTextW` |
| "does not exist" message | `wsprintf` into `char[560]` (a long name overflowed it), code-page template + UTF-8 name | `SprintfAlloc(LoadStrU8(IDS_FILEDOESNOTEXIST), name)` |
| `FileExists` | every error but not-found/path-not-found counted as "exists", also `ERROR_INVALID_NAME` - the `?` names passed the dialog | also `ERROR_INVALID_NAME`, `ERROR_BAD_PATHNAME`, `ERROR_INVALID_DRIVE` mean "does not exist". Why it was written that way: a file whose attributes cannot be read (sharing violation on `pagefile.sys`, access denied on a share) must still be accepted - kept |
| `CBHistory` | `char[20][MAX_PATH]` | `char[20][FC_NAME_SIZE]` (zero-filled .bss, pages used only as far as the names go); `AddToHistory` refuses a name that does not fit (cannot happen); `SRWLOCK HistoryLock` (`CHistoryLock`) around every use: `AddToHistory`, the dialog fill, `LoadConfiguration`, `SaveConfiguration`, `ClearHistory` |

### The comparator thread and window (`filecomp.cpp`, `filecomp.h`, `mainwnd.cpp`, `mainwnd.h`, `controls.*`, `viewwnd*.{h,cpp}`)

| Site | Change |
|---|---|
| `CFilecompThread::Body` loop | `GetMessageW`/`IsDialogMessageW`/`TranslateAcceleratorW`/`DispatchMessageW` (093 rule: a code-page loop turns typed characters outside the code page into `?` - measured, probe TYPE). The comparator window is a code-page winliblt window and gets its characters converted by `DispatchMessageW` exactly as before; its menu is a standard menu; the accelerator table (`filecomp.rc`) is all `VIRTKEY` |
| the two drain loops (`SpawnWorker`, `WM_DESTROY`) | `PeekMessageW`/`TranslateAcceleratorW`/`DispatchMessageW` (the key-discard loops that only remove `WM_KEY*` stay) |
| `CFilecompThread::Path1/Path2` | heap `FC_NAME_SIZE` (= `SAL_MAX_PATH_UTF8`, 98,302 bytes; `NULL` -> "Insufficient memory") |
| `ExecuteMenuItem` | `CSalMaxPathBuffer` for both names; `GetPanelPath`/`SalPathAppend` with `FC_NAME_SIZE`, the append checked (a name that does not fit leaves the field empty, so the dialog asks - it cannot happen with these sizes). Before: a panel path over 259 bytes (86 CJK characters) made the command do nothing (probe `long ON/OFF` before: NOTHING) |
| differences list (`IDC_DIFFLIST`) | created with `CreateWindowExW` and attached with the new opt-in `CWindow::AttachToWindowKeepKind` (combo and its edit stay Unicode); items composed from `LoadStrU8` templates and UTF-8 names (`SprintfAlloc`, exact size - two names of 255 CJK characters overflowed the 780-byte buffer) and added with `CB_ADDSTRING` W. Before: every non-ASCII name garbled in the list, every language (probe "list-garbled") |
| titles (`SpawnWorker`, `WN_SET_PROGRESS`, the final title, `worker2.cpp`) | `LoadStrU8` templates + UTF-8 names + UTF-8 encoding labels (`LabelToU8`: a conversion table name from `convert.cfg` is code-page text), exact-size buffers, `SetWindowTitleU8` (`SplSetWindowTitleW`); the 068 F-P5-09 narrow fallback no longer fires (the whole text is UTF-8) - the Czech title was garbled for every non-ASCII name before (probe `cz CZ` before: `PetrĹŻ`) |
| messages (`WM_USER_WORKERNOTIFIES`) | all `LoadStrU8`; a `WN_ERROR` text of any length gets a heap buffer; the "close?" question appended with `_snprintf_s(_TRUNCATE)` |
| worker errors (`CFilecompWorker::CException::Raise`) | `VSprintfAlloc(LoadStrU8(...))` + `AppendSystemErrorU8` (`FormatMessageW` -> UTF-8); before `vsprintf` into `char[1024]` (overflowed by a name over ~980 bytes) and `FormatMessage` A appended (code-page system text mixed with a UTF-8 name) |
| `CWorkerFileData::Name` | `_strdup` (was `TCHAR[MAX_PATH]`), `NULL` -> "Insufficient memory" |
| header bars (`CFileHeaderWindow::Text`) | heap `FC_NAME_SIZE`; drawn with `SplU8ToWAlloc`; `PathCompactPathW` (MAX_PATH contract) below `MAX_PATH` units, `DT_PATH_ELLIPSIS` above |
| hex view `Path` | heap `FC_NAME_SIZE` for the window's life (a posted `WM_USER_HANDLEFILEERROR` carries the pointer); the open error through `ErrorU8` |
| comparator-window drop (`WM_DROPFILES`) | `DropNameToU8` (the real length, then `SplWToU8` into `FC_NAME_SIZE`); `CM_COMPARE` and the drop use `CSalMaxPathBuffer` for the dialog |

### Helpers (`filecomp.cpp`, declared in `filecomp.h`)

`LoadStrU8` (from `SG->LoadStrW`, cached per id in a map under an `SRWLOCK`, freed at plug-in
release), `VSprintfAlloc`/`SprintfAlloc`, `AppendSystemErrorU8`, `CopyU8Truncated` (never cuts a
character), `LabelToU8`, `ErrorU8` (lukas `Error` for a template with one UTF-8 name - lukas'
`ErrorHelper` is shared with pictview, renamer and zip and is not touched), `SetWindowTitleU8`.

### winliblt (`src/plugins/shared/winliblt.{h,cpp}`) - opt-in, no change for other plug-ins

New `CWindow::AttachToWindowKeepKind` and member `UnicodeWnd` (initialised `FALSE` in every
constructor, reset by `AttachToWindow`): for a Unicode window the subclass is read and installed
with the W entry points and `CWindow::WindowProc`'s default forwards with `CallWindowProcW`;
`DetachWindow` and the `WM_DESTROY` restore in `CWindowProc` use the W entry points only when
`UnicodeWnd`. A code-page window is attached exactly as by `AttachToWindow`. The only caller is
the File Comparator's differences combo and its edit. All 20 enabled plug-ins rebuilt; the 093,
095-101 probes below drive pictview, zip, 7zip, codeview, mdview, dbviewer, diskmap.

### Found and fixed on the way

- **Insert lines named the files the other way round**: `IDS_ADD1/IDS_ADD2` say "from right
  file (%s) after line %d in left file (%s)" and got the left name first (`mainwnd.cpp`
  `ResetComboBox`); the Czech text has the same order. Driven by the probe's INS row (two
  different names, one inserted line): `1: Insert line 4 from right file (b<U+65E5>.txt) after
  line 3 in left file (a<U+0416>.txt)` (`probe/filecomp_result_ins.txt`, PASS). On the build
  before, these names never reach the list (`a?.txt` - "cannot open",
  `probe/filecomp_result_ins_pre102.txt`), so there the swap is shown by reading only.
- **The second dropped item was tested as the first** (`WM_DROPFILES`: `SalGetFileAttributes(path1)`
  for `path2`), so a folder dropped second was taken for a file.
- **`worker2.cpp` built a "low memory" exception and dropped it** (`CException(...)` without
  `throw`): the binary comparison went on with a file cache whose buffer was not allocated.
- **The fcremote receiver ran before the configuration was loaded**: `CreateRemoteComparator`
  was called in the entry point, the core calls `LoadConfiguration` after it, so a message that
  arrived at once (fcremote starts the program and sends as soon as the receiver runs) started a
  comparison that read the history, the options and `Configuration` while `LoadConfiguration`
  was writing them. The receiver now starts at the end of `LoadConfiguration` (once; `Created`).
  **Observed once, not reproduced, not proven to be this**: in one full probe run (fixed 3) the
  START route (program started by fcremote, plug-in loaded on start, 20 long history entries in
  the registry) hit a Debug CRT assertion "Buffer is too small" (`corecrt_internal_string_templates.h`
  81 - a `strcpy` into a fixed array, which `_CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES` turns into
  `strcpy_s`) in the program before the comparator window showed. 40 targeted repetitions of
  `START` alone (10 of them with 20 history entries of 400 CJK characters) did not reproduce
  it, and no stack
  was captured (no debugger on this machine; the probe now presses Retry on such a box to get
  the bug report). The race above is the one start-up-specific shared state on that route and
  is closed; the history lock covers the comparator threads among themselves. The three later
  full runs (one before this change, two after it) passed the START row.
- **One run (fixed 1) left the program running 30 s after WM_CLOSE** (the cjk instance, after
  ON/HIST/NOFILE/BROWSE/REM/REMW). Not reproduced in 5 targeted runs of the same routes nor in
  the 4 later full runs; the probe now records the process's windows and threads when it
  happens. Unexplained, recorded.

## T004 - S2: fcremote.exe and the channel

### Protocol (channel version 2)

| | Version 1 (up to 0.1.8) | Version 2 (feature 102) |
|---|---|---|
| `CMessageCenter::Version` / shared buffer | "1", `RemoteComparator - Buffer v1`, 4,094 bytes | "2", `RemoteComparator - Buffer v2`, 135,168 bytes (`messages.h`; two names of 32,767 units fit: 131,116 bytes) |
| message | `CRCMessage : CMessage` = `CurrentDirectory[260]`, `Path1[260]`, `Path2[260]`, `ReleaseEvent[20]` (808 bytes, code page of fcremote) | `CRCMessage { CMessage Header; DWORD Magic = 'FCR2'; char ReleaseEvent[20]; DWORD Path1Len, Path2Len; WCHAR Names[] }`, `#pragma pack(4)`, `Size` = 44 + (len1 + 1 + len2 + 1) * 2 |
| names | as typed (relative names resolved by the plug-in against the sent directory, lukas `SalGetFullName`, `MAX_PATH`); code-page bytes read by the plug-in as UTF-8 | full names, resolved by fcremote (`GetFullPathNameW`), UTF-16; the plug-in converts with `SplWToU8Alloc` (WTF-8) and gives an `\\?\` name its display form (`FcDisplayFormU8`) |
| receiver check | `Size == 808`, else silently ignored | magic, size, both lengths, both terminators exactly where the lengths say (`FcCheckNames`, no overflow in the sum); a malformed message with a readable event name is answered (the event set) so `-w` ends |
| mismatch | - | the version names the buffer, so the sides never exchange a message: a version-2 fcremote that finds the version-1 buffer reports "Cannot send message to File Comparator plugin." without starting the program; a version-1 fcremote (an old copy) cannot open the version-2 buffer, starts its own `..\..\tandemcommander.exe` (it did so before when the plug-in was not loaded) and then reports "Ensure 'Load plugin on Tandem Commander start'..." - a clear error either way, no hang (probe MISM on both builds) |

### fcremote.exe (`fcremote/fcremote.cpp`, `fcproto.h`)

- `GetCommandLineW` + `FcSplitArgsW` (`fcproto.h`, header-only): the rules of version 1's
  `MakeArgv` kept - arguments separated by runs of spaces and tabs; a `"` opens a quoted part up
  to the next `"` (or the end of the line) in which spaces and tabs belong to the argument;
  every `"` is removed; no escape character (`"C:\dir\"` is `C:\dir\`); argument 0 is the
  program; more than 4 arguments is an error. Fixed: an unterminated quote read past the end of
  the command line; arguments were cut to 259 bytes.
- `FullPathW`: an `\\?\` argument as it is; otherwise `GetFullPathNameW` - and the trailing dots
  and spaces of the last component it drops are appended again (`FcTrailingDotsW`,
  `FcRestoreTrailingDotsW`): the file layer opens `\\?\` names literally, so `a.` would have
  named the file `a`. Relative names resolve against fcremote's current directory as before;
  `C:a.txt` (drive-relative) now resolves instead of failing.
- start of the program: `GetModuleFileNameW` (32,768 units) + `CreateProcessW` (an
  installation folder outside the code page, e.g. a per-user installation under such a user
  name, failed with "Unable to launch").
- `-w`: waits for the release event **or** the receiver process (`OpenProcess(SYNCHRONIZE)` of
  `GetRecieverPid`); returns -1 when the program ended first. Before: `WaitForSingleObject(INFINITE)`
  on the event only - also after a failed send (the message never arrived).
- Still no C runtime: Release imports only kernel32 (`GetCommandLineW`, `GetFullPathNameW`,
  `CreateProcessW`, `GetModuleFileNameW`, `HeapAlloc`, `lstr*W`, ...) and user32 (`MessageBoxA`,
  `wsprintfA`, `AllowSetForegroundWindow`) - checked with `dumpbin /imports`. The English
  messages are the existing ones (no new string).

## T005 - probe `probe/filecomp_probe.ps1`

Hidden desktop, registry key exported / restored / SHA-256 identical after every run
(`1AB61430...F769`), fixtures under `%TEMP%\tc102_fc` removed, nothing left running. Cases,
routes and the verdict rule are in the script's header; `-Expect before` = PASS when the outcome
is the one research section 2 predicted for the build before (the control).

**This build** (`probe/filecomp_result.txt`): **88 PASS / 0 FAIL / 0 not driven.**
**Before** (`Debug_x64_pre102`, `probe/filecomp_result_pre102.txt`): **86 PASS / 0 FAIL** - every
predicted defect seen.

| Case | ON (dialog) | HIST | TYPE / NOFILE / BROWSE | REM / REMW (fcremote) | OFF (no dialog) | CZ / CZREM |
|---|---|---|---|---|---|---|
| cz `Petr<U+016F>` | EXACT / before: EXACT, list garbled | exact / garbled | - | EXACT / **ERROR** (every non-ASCII name, since 004) | EXACT / list garbled | EXACT / **title garbled** (`Petr<U+0139><U+017B>`), REM ERROR |
| cyr | EXACT / **ERROR** (`????.txt`) | exact / garbled | TYPE exact / lossy (`?`) | EXACT / ERROR | EXACT / list garbled | EXACT / ERROR |
| cjk | EXACT / ERROR | exact / garbled | NOFILE named, dialog stays / accepted, comparator error; BROWSE exact / `???` | EXACT / ERROR | EXACT / list garbled | - |
| emo | EXACT / ERROR | exact / garbled | TYPE exact / lossy | EXACT / ERROR | EXACT / list garbled | - |
| lone | EXACT / ERROR ("does not exist", WTF-8 bytes read as cp1250) | exact / garbled | TYPE exact / lossy | EXACT / ERROR | EXACT / list garbled | - |
| same (identical) | EXACT ("identical") / ERROR | exact / garbled | - | EXACT / ERROR | EXACT / EXACT | - |
| long (206 units, 508 bytes) | EXACT / **NOTHING** (silent) | exact / - | - | EXACT / ERROR | EXACT / NOTHING | - |
| voila | EXACT / **DECOY** (`voila.txt`, 4 differences) | exact / garbled | - | EXACT / **DECOY** | EXACT / list garbled | EXACT / DECOY, DECOY |
| fwab | EXACT / **DECOY** (`AB.txt`) | exact / garbled | - | EXACT / **DECOY** | EXACT / list garbled | - |
| abrev | EXACT / EXACT, list garbled | exact / garbled | - | EXACT / **DECOY** (`<U+00E9>.txt`) | EXACT / list garbled | - |
| fri `f<U+65E5>` | EXACT / ERROR (`f?.txt`, no wildcard match) | exact / garbled | - | EXACT / ERROR | EXACT / list garbled | - |

(cell = this build / before.) Further rows, both builds as predicted: HISTREG (the saved
`History n` values hold the 5 checked names exactly; before: 0 of 5, 12 values with `?`),
START (fcremote -w starts the program with the plug-in loaded on start: EXACT, -w returns 0 /
before: ERROR), MISM (the other build's fcremote: a clear error from fcremote, exit -1, no
comparator, no hang - both directions), DISK (no fixture file lost), END rows (every instance
exits with 0, no bug report).

**Not drivable, recorded**: dropping files onto a dialog field or onto the comparator window -
`WM_DROPFILES` carries an `HDROP` that must be allocated in the target process; the code is the
same `DragQueryFileW` pattern the comparator window has used since 004 and the best-fit loss of
the A call was measured in research (scratch `drop.cpp`).

Probe runs, honestly: fixed 1 = 87/1 (the unexplained exit hang above), fixed 2 = probe defect
(my own END handling; fixed), fixed 3 = 86/2 (the START assertion above), fixed 4, 5 and the
final build's run = 88/0; before = 86/0 twice.

## Gates so far (T007 runs them again)

- Debug x64 build exit 0, Release x64 (`build.cmd release`) exit 0; no compiler warning in the
  touched code.
- saltests **13,317 checks, 0 failed** (13,278 + 39 in `TestFcRemote102`: the argument split
  incl. CJK, a lone surrogate and a fullwidth quote, the trailing-dot tail with the real
  `GetFullPathNameW`, the message check incl. a wrapping length sum, the `\\?\` display form).
- `tools/check_encoding.py --strict` TOTAL 0; draft TOTAL 0.
- BOM / no BOM as at HEAD, CRLF in the working tree for every touched file; the new `fcproto.h`
  BOM + CRLF like the other 2026 headers. Incident: `mainwnd.cpp` was found all-LF after the
  edits (a Git Bash `sed -i` over it is the likely cause) and was converted back; checked with a
  byte count per file.

## Regression (this build, `probe/regress_*_102.txt`)

Run one after another through `tools/run_on_hidden_desktop.ps1` on the Debug build of this
feature; registry SHA-256 identical after every run (`1AB61430...F769`), nothing left running,
fixtures removed. Every result equals the 101 baseline.

| Probe | Result | Baseline (101) |
|---|---|---|
| 093 `dialogs_probe` | 139 PASS / 0 LOSSY / 0 FAIL / 1 not driven | same |
| 093 `cmdline_probe` | 63 PASS / 0 FAIL / 1 INFO | same |
| 095 `longarc_probe` | 60 PASS / 0 FAIL, Debug handle notes 4 | same |
| 096 `archedit_probe` | 17 of 17 UPDATED, 0 retries | same |
| 097 `arcpath_probe -Stage S2` | 55 PASS / 0 FAIL | same |
| 097 `arcwork_probe` | 390 PASS / 0 FAIL / 21 n/a | same |
| 098 `fix_probe` | 107 PASS / 0 FAIL / 3 not driven / 1 INFO | same |
| 099 `linkmove_probe` | 24 PASS / 0 FAIL | same |
| 100 `cjk_focus_probe -Expect fixed` | 77 PASS / 0 FAIL (Code Viewer, internal viewer, Markdown Viewer, PictView, Database Viewer, DiskMap titles) | same |
| 101 `leftovers_probe -Expect fixed` | 20 PASS / 0 FAIL / 4 not driven (clipboard) | same |

## Recorded, not changed

- `ClearHistory` empties the history strings but keeps `CBHistoryEntries`: until the next
  comparison the dialog lists empty items, and the empty values are what `SaveConfiguration`
  writes (which is how the clear reaches the registry - setting the count to 0 would leave the
  old values there). Pre-existing, harmless.
- The hex view's retry dialog (`WM_USER_HANDLEFILEERROR`) builds its text from the code-page
  `IDS_ACCESFILE2` and the code-page `FormatMessage` - consistent code-page text without a name
  (the name goes separately to `DialogError`), shown correctly; left as it is.
- An old (0.1.8) `fcremote.exe` copied elsewhere starts its own `..\..\tandemcommander.exe`
  before it reports the error (probe MISM: the pre-102 program, ended by the probe) - its own
  code, unchanged by design.
- `fcremote -w` still waits for ever if the plug-in is unloaded by force while the comparison
  window is open and the program keeps running (the event is set at the end of the comparator
  thread, which a forced unload kills).
- Other plug-ins with the same shape (research section 5): pictview's `salpvenv.exe`, the ZIP
  SFX tools, code-page subclasses in ftp/zip/7zip, `CreateFileA` fallbacks in checksum,
  peviewer, renamer - backlog.

## T006 - independent review: ACCEPT, two SHOULD-FIX and three NITs, all applied

### The one-time "Buffer is too small" assertion - explained by the reviewer

`corecrt_internal_string_templates.h` line 81 is `common_tcscpy_s`. In the build where it
happened the fcremote receiver still started in the entry point, so the comparator thread's
`AddToHistory` ran while `LoadConfiguration` was still filling `CBHistory`. In Debug every
`strcpy_s` into a 98,302-byte history row fills the rest of the row with 0xFE; two concurrent
writers left rows unterminated (the reviewer's scratch harness: 4,191 of 30,000), and the next
shift of the history (`dialogs.cpp`, `AddToHistory` ~60, `_tcscpy` = the template `strcpy_s`)
asserts with exactly that text and line. Closed by the receiver starting at the end of
`LoadConfiguration` plus `HistoryLock` (T003); the reviewer's 30 START runs on the current build:
0 assertions.

The exit hang (fixed 1) was not reproduced by the reviewer either (30 START runs + 6 x the cjk
routes). Found on the way: closing the program within about 1 s after fcremote started it shows
"File Comparator plugin has rejected to unload. Force?" (the 0.1.8 build too; the cause was
not traced) - recorded, not changed.
The probe's END row now tells such a box from a hang: every window that appears while closing
is recorded once (class + text, any class but the program's wait window `SalamanderSaveBits`),
a box is answered OK/Yes after half a second, and the close request is repeated at 10 s and
20 s; the row prints the number of close requests.

### SHOULD-FIX 1 - long names froze the comparator window (`controls.cpp`)

`CFileHeaderWindow` drew names of `MAX_PATH` units and longer with
`DrawTextW(..., DT_PATH_ELLIPSIS)`, whose cost grows with the square of the length (reviewer:
300 units 16 ms, 2,000 140 ms, 8,000 1.9 s, 16,000 8.4 s, 30,000 28.5 s per call, on every
repaint) - new in 102, such names failed before. Now `HeaderDisplayText` first shortens the
name to its root (`C:\` or `\server\share\`, when not over 60 units) + `...\` + its end
(starting after a backslash when there is one, never at the low half of a surrogate pair) in a
`MAX_PATH` buffer, then `PathCompactPathW` fits it to the width as for short names: the cost is
the same for every length. Other places that draw or measure names: the titles and the
differences list carry file names only (at most 255 units), the split-bar tooltip shows a
percentage - nothing else draws the full name.

Probe rows LONG8K (7,789 units both sides) and LONG30K (29,789 / 59 units): the result after
1.1 / 1.0 s, the slowest `WM_NULL` round trip after a full repaint (`RedrawWindow`) 0 ms (PASS).
On the build before, the names fail at once (0.1.8's fcremote cut arguments at 259 bytes:
"Unable to open file", INFO).

### SHOULD-FIX 2 - fcremote could still compare a different file (`fcproto.h`, `fcremote.cpp`)

`GetFullPathNameW` removes a trailing dot or space of INTERMEDIATE folders too
(`C:\t\dir.\b.txt` -> `C:\t\dir\b.txt`); the tail restore covered only the last component. The
reviewer measured `dotdir\L.\f.txt` / `dotdir\R.\f.txt` comparing the decoys `L\f.txt` /
`R\f.txt` without a word (0.1.8 opened such ASCII names as typed). Now `FcAbsoluteNameW`
(header-only, CRT-free, under saltests) makes the name absolute without letting Windows
normalise any component: `\?\` names as they are; `C:\x` and `\server\share\x` absolute; `\x`
on the root of the current directory; `C:x` on that drive's current directory (asked from
Windows with `GetFullPathNameW(L"C:")` - only the directory, never the typed name); anything
else on the current directory (`GetCurrentDirectoryW`, also in the `\?\` form); `/` becomes `\`;
empty and `.` components are dropped, `..` removes the component before it (never the root);
every other component is kept exactly, with trailing dots and spaces. The plug-in opens every
absolute name with the `\?\` prefix (`SplU8ToWExtAlloc`: prefix only, no normalisation; the
core's `SalPathToWExtAlloc`, used by the dialog's check, canonicalises only `.` and `..`), so
such a component reaches the file system as typed. `FcTrailingDotsW` / `FcRestoreTrailingDotsW`
are gone. Probe rows DOT (`L.\`, `R.\`) and SPACE (`L \`, `R \`) with the decoys beside them:
2 differences = the named files (PASS, also on the build before).

### NITs

1. `messages.cpp` `RecieveMessages` (older code) walked the shared buffer with `Size` read
   again and again and no bounds: now `WritePos` is clamped to `BufferSize`, every message must
   be at least a `CMessage` and lie within the written part, `Size` is read once and passed to
   the listener (`CMessageListener::RecieveMessage(message, size)` - only the File Comparator
   implements it). `remote.cpp` copies the message out of the shared memory once (`malloc` +
   `memcpy` of the checked size) and checks and uses only the copy.
2. `ReleaseLoadStrU8` runs after `ThreadQueue.KillAll(force)`: it now uses
   `TryAcquireSRWLockExclusive` and leaves the cache to the process when the lock is held (a
   killed thread), instead of waiting for ever at exit.
3. `fcremote -w` opens the program's process (`OpenProcess(SYNCHRONIZE)`) BEFORE it sends the
   message, so an exit right after the send cannot be missed.

### After the review

- Debug build exit 0, no warning in the touched code; saltests **13,326 checks, 0 failed**
  (13,278 + 48 in `TestFcRemote102`; the trailing-dot cases replaced by 23 `FcAbsoluteNameW`
  cases: intermediate dots and spaces, `..` never above the root, `...` as a name, root- and
  drive-relative, UNC, a `\?\` current directory, CJK + lone surrogate); strict guard 0.
- `filecomp_probe.ps1` whole, this build (`probe/filecomp_result.txt`): **95 PASS / 0 FAIL / 0
  not driven** (88 + DOT, SPACE, LONG8K, LONG30K, their END, INS + END); every END: one close
  request, no window while closing. The new rows on the build before
  (`probe/filecomp_result_paths_pre102.txt`): DOT and SPACE exact, LONG8K/LONG30K "Unable to open
  file" (INFO).
- Incident, again: a Git Bash `sed -i` turned `remote.h` to LF (this is how `mainwnd.cpp` lost
  its CRLF earlier); converted back, every touched file re-checked byte by byte; no more `sed`
  on sources.
- Regression after the review (Debug, this build): 100 `cjk_focus` 77 PASS / 0 FAIL, 101
  `leftovers` 20 PASS / 0 FAIL / 4 not driven (both as baseline). 093 `dialogs`: the first run
  127 PASS / **8 FAIL** - all 8 rows "Find menu by Alt+M/E/V/O" (the core's Find window menu bar,
  posted `WM_SYSCHAR`/`WM_SYSKEYDOWN`: no menu opened; `probe/regress_093dialogs_102_flaky.txt`);
  the immediate re-run 139 PASS / 0 FAIL / 1 not driven (`probe/regress_093dialogs_102.txt`).
  The core executable is not changed by feature 102 (no file outside `src/plugins` and
  `src/saltests`), and the same build passed all 139 in the first regression round - recorded
  as a flaky row of that probe, not investigated further. The other probes (095-099) were not
  re-run: no shared code they use changed in the review round (`winliblt` untouched, `lukas/messages`
  is used only by the File Comparator and fcremote).
- Full Release build (`build.cmd full release`): exit 0, BUILD SUCCEEDED, 189 language modules,
  no error or warning line; Release `fcremote.exe` (14,848 bytes) imports `KERNEL32.dll` and
  `USER32.dll` only.

## The 093 dialogs probe's flaky Find-menu rows (coordinator's check)

After the review fixes the 093 dialogs probe failed 8 rows ("Find menu by
Alt+M/E/V/O", posted and key, "no menu") in one of two runs on this build.
The same probe on `Debug_x64_pre102`, three runs: 127/8, 139/0, 139/0 - the
same 8 rows in one run of three. So it is not caused by 102 (which does not
touch the core); it is the hidden-desktop menu behaviour recorded by 097
(a popup closed by an activation change) appearing in a different row set.
Recorded in NEXT-WORK; the probe rows stay as they are.

