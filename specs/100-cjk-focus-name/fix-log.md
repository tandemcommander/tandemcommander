# Fix log: feature 100 - Unicode window titles

Branch `100-cjk-focus-name`, from `099-move-into-archive-links`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T003 - the helper and the call sites

### The helper and its rule

`SalSetWindowTitleW(HWND, const WCHAR*)` in the core (`src/common/winlib.{h,cpp}`, next to
`SalSetWindowTextU8`), and its header-only twin `SplSetWindowTitleW` in
`src/plugins/shared/splunicode.h` (the same body; no plug-in interface change):

1. `SetWindowTextW(hWnd, text)` as always - every window procedure, subclass and hook sees
   WM_SETTEXT exactly as before; nothing is bypassed.
2. Only when the window is **top-level** (`WS_CHILD` clear) and **owned by the calling
   thread**: the stored title is read with
   `InternalGetWindowText` and compared with the text. When it differs (the text crossed a
   code-page window procedure and every character outside the code page became `?`),
   `DefWindowProcW(hWnd, WM_SETTEXT, 0, text)` stores the UTF-16 text itself.
3. Everything else - child windows and controls, another thread's window, a title that was
   stored exactly - is exactly `SetWindowTextW`.

Review (NIT 2, applied): the first version also required `WS_CAPTION`; that skipped PictView
in full screen (style `0x94080000` = WS_POPUP | WS_VISIBLE | WS_CLIPSIBLINGS | WS_SYSMENU, no
caption), where the next file stored `p?.png` until full screen was left. The test is gone
from both helpers; for a popup whose stored text is exact (tooltip, drop-down list) the
comparison makes the helper a plain `SetWindowTextW`.

`SalSetWindowTextU8` uses the helper, so its top-level callers (message box titles, the Find
window's titles, `dialogs3.cpp` 475/985, `dialogs5.cpp` 1252) keep their names too; its many
control callers are untouched by rule 3 (one extra `GetWindowLongPtr`).

**Why "verify, then correct", not "IsWindowUnicode, else DefWindowProcW"** (the first version
of the helper, built and probed): the internal viewer reports `IsWindowUnicode` = TRUE and
still stored `f?.txt` - its window registers a tooltip tool with `TTF_SUBCLASS`
(`viewer3.cpp` ~611), comctl32 subclasses the window with a Unicode procedure, and the chain
still ends in the code-page `CWindowProc` + `DefWindowProcA`. The first probe run on the fixed
build showed exactly this (T-INT 4 FAIL, every other title PASS); the verify-then-correct rule
fixed it and has the second advantage that no WM_SETTEXT handler is ever bypassed (the
coordinator's concern).

### WM_SETTEXT handlers and caption drawing (checked)

- `grep WM_SETTEXT` over `src/` (core and plug-ins): handlers only in **child controls** -
  `gui.cpp` `CStaticText::WindowProc` (1098) and `CButton::WindowProc` (2109),
  `filecomp/controls.cpp` `CToolTipWindow` (469), `zip/dialogs.cpp` `CBEditCtrlProc` (163, an
  edit subclass). None in a top-level window's procedure: not in core `CWindow`/`CMainWindow`/
  `CViewerWindow`, not in winliblt's `CWindow`, not in the codeview/mdview/pictview/dbviewer/
  filecomp frames, not in the dialogs the changed sites address.
- Comctl32 subclasses in `themes.cpp` (`SetWindowSubclass` x9) are on child controls and the
  property-sheet frame; none handles WM_SETTEXT. The dark title bar is
  `DwmSetWindowAttribute(DWMWA_USE_IMMERSIVE_DARK_MODE)` (`themes.cpp` 234) - DWM draws the
  caption from the stored text; no caption-drawing hook exists.
- `menu1.cpp`'s WH_CALLWNDPROC hook watches only WM_CANCELMODE/ACTIVATE*/KILLFOCUS.
- With the final rule every handler would still see the message first anyway.

### Changed sites

| Site | Window | Change |
|------|--------|--------|
| `codeview/viewer.cpp` 653 | Code Viewer frame (winliblt ANSI class) | `SplSetWindowTitleW` |
| `viewer3.cpp` 104 | internal viewer (ANSI class + comctl32 W subclass) | `SalSetWindowTitleW` |
| `mdview/viewer.cpp` 530 | Markdown Viewer frame | `SplSetWindowTitleW` |
| `pictview/render1.cpp` 193 | PictView frame (set by the renderer, same thread) | `SplSetWindowTitleW` |
| `dbviewer/renmain.cpp` 293 | Database Viewer frame (`GetParent`, same thread) | `SplSetWindowTitleW` |
| `filecomp/mainwnd.cpp` 899, 2059, 2157 | File Comparator frame (own thread) | `SplSetWindowTitleW` |
| `filecomp/worker2.cpp` 110 | the same frame, **from the combo-box worker thread** | routed, see below |
| `mainwnd1.cpp` 1957 / 2019 | main window | "unchanged?" reads `InternalGetWindowText`; set with `SalSetWindowTitleW` |
| `dialogs3.cpp` 1399 | Drive Information dialog title (volume path) | `SalSetWindowTitleW` |
| `ftp/dialogs2.cpp` 90 | FTP server-reply dialog title (the command, may hold a path) | `SplSetWindowTitleW` |
| `ftp/dialogs5.cpp` 297-305 | FTP operation dialog title (names) | "changed?" reads `InternalGetWindowText`; `SplSetWindowTitleW` |
| `zip/dialogs3.cpp` 196 | ZIP comment dialog title (archive name) | `SplSetWindowTitleW` |
| `diskmap/DiskMap/Utils.CZString.h` 81 `ZSetWindowText` | DiskMap window (A-registered top-level; its only caller is `GUI.MainWindow.h` 500, the "DiskMap - <path>" title) | `SplSetWindowTitleW` inside the wrapper (review SHOULD-FIX 1: missed because the first sweep covered `*.cpp` only; `splunicode.h` comes with `DiskMapPlugin/precomp.h`, which every DiskMap `.cpp` includes) |
| `winlib.cpp` `SalSetWindowTextU8` | all its callers | helper (rule 3 keeps controls as they were) |
| `tools/check_encoding.py` | `WIDE_ATTEMPT` | knows `Sal/SplSetWindowTitleW` as a wide attempt (the A fallbacks after it stay accepted) |

**Main window "unchanged?" check**: it read the title back with `GetWindowTextW`, which on a
code-page window returns `?` - so for a folder outside the code page the comparison found a
change on **every** call and re-set the title and the tray tip each time. Measured on the build
before: 5 refreshes of an unchanged CJK folder = 5 name-change events; on this build 0. The FTP
operation dialog had the same shape (its "changed" also re-flashes the taskbar button) and
got the same correction.

**Worker-thread decision (`worker2.cpp`)**: the binary comparison's combo-box worker set the
frame's title with `SetWindowTextW` from its own thread - a synchronous send of WM_SETTEXT to
the frame's thread, through its code-page procedure. `DefWindowProcW` must not act on another
thread's window, so the helper would only have done `SetWindowTextW` there. The worker now
**sends** a private message `WM_USER_SETTITLEW` (`WM_APP + 14`, `filecomp/dlg_com.h`) with the
UTF-16 title; the frame's `WindowProc` calls `SplSetWindowTitleW` on its own thread. Same
blocking behaviour as before (`SetWindowTextW` to another thread's window is a synchronous
send too; the worker already sends `CB_ADDSTRING` to the same thread just above), the buffer is
freed after the send returns. Only `CMainWindow` receives the worker's messages (checked).

### Other title setters (grep of `SetWindowText*` on top-level windows, core + enabled plug-ins)

Re-swept after the review over `*.h` too, and over every `WM_SETTEXT` send in the core and the
enabled plug-ins: in headers only `ZSetWindowText` (fixed above) and `automation/inputbox.h`
103 (the Automation plug-in is disabled in `plugins.cfg`); every `WM_SETTEXT` send targets a
control (dialog items, combo boxes, edits).

Left unchanged, with the reason:

- Localized strings only (no file name): `viewer2.cpp` IDS_VIEWERTITLE x7, `finddlg1.cpp` 2237/3088,
  `dialogs.cpp` 568/1557/1727, `dialogs6.cpp` 2158, `dialogs2.cpp` 1252, `filecomp/mainwnd.cpp`
  1304/1444/2243, ftp dialogs1/4/7/8 titles, checksum, sftp, uncab, undelete, zip `dialogs.cpp`
  382-2038, `zip.cpp` 394, `shellib.cpp` 2499, `pictview/render1.cpp` 4211 (IDS_CAPTURING, a
  localized W string), `pictview` print/wiawrap dialogs.
- `dialogs.cpp` 526 (progress dialog in its own thread: "(n %) caption", compared through
  `GetWindowText` A) and `dialogs2.cpp` 1069 (plug-in name, UTF-8 by contract 052, through the A
  call): narrow-call encoding shapes of the 068 clusters (B-1), not this defect - recorded, not
  touched.
- `zip/selfextr/*`: the SFX stub, a separate code-page program.
- `regedt/finddlg2.cpp` 255: commented out.
- The `mainwnd1.cpp` title is only ever set from the main thread (`dialogs.cpp` 537/540 run in the
  `!RunningInOwnThread` branch).

Not reachable with a name outside the code page, recorded: the File Comparator's *Compare Files*
dialog (winliblt code-page dialog: its path fields turn such a name into `?`) and `fcremote.exe`
(an ANSI program, `GetCommandLine`) - the comparator cannot be started on such files at all
(cluster B-1); its title fix is effective for names it can open.

### Recorded, not changed (review)

- NIT 3: for a name outside the code page a title set now produces **two** name-change events
  and two caption redraws (the `SetWindowTextW` that stores the `?` form, then the correction);
  a screen reader may announce the `?` form first. Measured: T-MAIN, Change Directory = 2
  events (1 for U+0159).
- NIT 4 (pre-existing, backlog): `CMainWindow::SetTrayIconText` (`mainwnd1.cpp` 1758-1773)
  copies the UTF-8 title into the ANSI `NOTIFYICONDATA::szTip` with `lstrcpyn`, so any non-ASCII
  name in the tray tip is garbled (UTF-8 bytes read as code page 1250) and can be cut in the
  middle of a character (`szTip` is 128 bytes). Found, not changed.

### Build

Debug x64 (`build.cmd`): exit 0, no error. Warnings: C4267/C4005 in **untouched** files of
plug-ins that include `splunicode.h` (recompiled because the header changed), e.g.
`folders/fs2.cpp` 211 `file.NameLen = strlen(file.Name)` - pre-existing lines.
`saltests`: 13,119 checks, 0 failed (no new unit test: the helper needs a window; the probe
covers it - the technique itself is in `probe/caption_technique_probe.ps1`). Strict guard
TOTAL 0; draft 131 findings, the same list as at HEAD (compared line by line).

## T004 - probe

`probe/cjk_focus_probe.ps1` extended (the T001 rows kept): per name X in {U+0159 (in code
page 1250), U+65E5, U+4E2D, U+0416, U+1F600}, the stored title (`InternalGetWindowText`) of
F3 / Code Viewer, Alt+F3 / internal viewer, the Markdown Viewer, PictView (4x4 PNG), the
Database Viewer (CSV), the main window in folder `d<X>` with name-change events
(`EVENT_OBJECT_NAMECHANGE`, out-of-context WinEvent hook) for the change and for five refreshes,
the File Comparator (binary files with U+0159 names, hot key Ctrl+Shift+C through
`AttachThreadInput` + `SetKeyboardState` of the probe's own thread), and after the review
PictView in full screen moving to the next file (T-PFS: o.png -> p<X>.png, `CMD_FULLSCREEN`
129 and `CMD_FILE_NEXT` 147 posted to the viewer) and DiskMap (T-DM: Ctrl+Shift+D on the
panel folder d<X>).
Results: `probe/cjk_title_result.txt` (this build, `-Expect fixed`, all rows, after the
review fixes), `probe/cjk_title_result_pre100.txt` (`Debug_x64_pre100`, `-Expect before`, the
rows before the review) and `probe/cjk_title_result_pre100_newrows.txt` (`Debug_x64_pre100`,
`-Only newrows`: T-PFS and T-DM).

| Row | this build | before 100 |
|-----|-----------|------------|
| F3 / NAVF3 Code Viewer | exact, 5 names | `?` for the 4 outside the code page |
| T-INT internal viewer | exact, 5 names | `?` x4 |
| T-MD Markdown Viewer | exact, 5 names | `?` x4 |
| T-PNG PictView | exact, 5 names | `?` x4 |
| T-CSV Database Viewer | exact, 5 names | `?` x4 |
| T-MAIN main window | exact, 5 names; name-change events: change 1 (U+0159) / 2 (the 4 others: SetWindowTextW + the correction); 5 refreshes **0** | `?` x4; 5 refreshes **5** events for the 4 (re-set every time), 0 for U+0159 |
| T-PFS PictView full screen, next file | exact, 5 names (style `0x94080000`, no caption) | `?` x4 |
| T-DM DiskMap | `DiskMap - ...\d<X>` exact, 5 names | `?` x4 |
| FC File Comparator (U+0159) | `b1ř.bin : b2ř.bin - File Comparator - 2 Differences`, responsive | identical |
| CD / LOC / FOCUS / NAV / DISK / END | PASS | PASS |
| Total | **77 PASS / 0 FAIL** | **67 PASS / 0 FAIL** + new rows **20 PASS / 0 FAIL** (verdicts per `-Expect before`) |

Every U+0159 row and the FC row (T-PFS and T-DM against the `newrows` file) are byte-identical
between the result files (titles of
names inside the code page unchanged, FR-002). Registry SHA-256 identical after each run
(`1AB61430...F769`), nothing left running, scratch removed.

Not driven: the dark theme (the caption is DWM-drawn from the stored text; no code path of the
change touches theming); FTP dialogs and the ZIP comment dialog titles (read only - same helper,
own thread); a real screen.

## Regression (this build, results in `probe/regress_*_100*.txt`)

Run sequentially through `tools/run_on_hidden_desktop.ps1`; registry SHA-256 identical after
every run (`1AB61430...F769`), nothing left running, every fixture removed.

| Probe | Result | Baseline |
|-------|--------|----------|
| 093 `dialogs_probe` | 139 PASS / 0 LOSSY / 0 FAIL / 1 not driven | same (093, 097) |
| 093 `cmdline_probe` | 63 PASS / 0 FAIL / 1 INFO | same |
| 095 `longarc_probe` | 60 PASS / 0 FAIL, Debug handle notes 4 | same (099) |
| 096 `archedit_probe` | first run 15 of 17 UPDATED - `subacc` and `L77` showed "temporary copy: none" (the posted F4 was ignored: the flake 097 and 099 record); re-run of the two: both UPDATED (`regress_archedit_100_rerun_*.txt`) -> 17 of 17 | 17 of 17 (099, after its own re-run) |
| 097 `arcpath_probe -Stage S2` | 55 PASS / 0 FAIL | same |
| 098 `fix_probe` | 107 PASS / 0 FAIL / 3 not driven / 1 INFO | same (099) |
| 099 `linkmove_probe` | 24 PASS / 0 FAIL | same |

After the review fixes (DiskMap, no `WS_CAPTION` test): Debug build exit 0; saltests 13,119 / 0;
strict guard TOTAL 0; 093 `dialogs_probe` re-run (`regress_093dialogs_100_review.txt`): 139 PASS /
0 LOSSY / 0 FAIL / 1 not driven, registry identical.
Full Release build (`build.cmd full release`): exit 0, 0 errors, BUILD SUCCEEDED; 20 plug-ins
registered, runtime closure OK (218 modules). 23 compiler warnings, all in files this feature did
not touch (recompiled because `winlib.h` / `splunicode.h` changed): C4267 in folders/ftp/regedt/
tar/undelete/uniso, C4005 `dbviewer/dbflib/dbflib.cpp` 29, C4018 `salamdr2.cpp` 1036/1044,
C4244 `zip.cpp` 5913 (the one 098 recorded).

## Independent review - ACCEPT (2026-10-03)

Verified by the reviewer: every branch of the helper (NULL, failures, other
threads, long titles - one extra set at most, never a loop; a literal `?`
compared in UTF-16; emoji exact), `DefWindowProcW` on a dialog safe, no
affected window keeps its own copy of the title, controls unchanged (every
path of `SalSetWindowTextU8`), the File Comparator's message id unique and
its waits pump sent messages (no new deadlock), main-window title correct
over six panel and six tab switches, 0 events over 5 refreshes and 4 s idle,
also in the dark theme; the author's probe reproduced row for row.

Done after it: DiskMap's title (missed - its setter is in a header;
re-swept `*.h`); the `WS_CAPTION` condition dropped (PictView full screen).
Recorded: two name-change events per title set outside the code page; the
tray tip garbles non-ASCII names (found, not changed).

## Gates

Debug and full Release builds (exit 0; the 23 warnings are in untouched
files recompiled because of the shared headers); saltests 13,119 / 0; strict
guard 0; `cjk_focus_probe` 77 / 0 (the new rows on the build before: `?` for
the four names outside the code page); regression probes of 093, 095, 096,
097, 098, 099 as their baselines (096: the known F4 timing flake, re-run
17 / 17).

