# Research 100: "Change Directory to a CJK file name, the viewer shows `f??.txt`"

Source of the finding: `specs/098-long-path-overruns/fix-log.md` ("New finding (backlog, from the
reviewer, not re-driven here)") and `specs/NEXT-WORK.md` item 5, "Found by 098" no. 2.

Measured on 2026-10-03, system code page 1250, Debug x64 build of branch `100-cjk-focus-name`
(= `aa0d3cb8`), and the preserved pre-098 build `build\tandemcommander\Debug_x64_pre098`.

## Verdict

**The finding is not in Change Directory and not in the input. The file is focused correctly
and F3 opens and shows the right file. Only the viewer window's caption is wrong.** The Code
Viewer (the F3 viewer for `.txt`) is a window of an **ANSI window class**. `SetWindowTextW` on
an ANSI window is converted to the system code page before the text is stored, so every
character outside code page 1250 becomes `?`. That is one `?` per UTF-16 unit: `f?.txt` for
U+65E5, U+4E2D or U+0416, and `f??.txt` for an emoji (a surrogate pair). The reviewer's `f??.txt`
for U+4E2D was probably a loose transcription. The probe shows `f?.txt` for it.

The same title results however the file is focused, whether by Change Directory or by plain
navigation (Home + Down). It is the same on the build before 098.

## Evidence (driven)

`probe/cjk_focus_probe.ps1` was run on the hidden desktop, with one instance per name. The
results are in `probe/cjk_focus_result.txt` (this build) and `probe/cjk_focus_result_pre098.txt`.
Each build gave 30 PASS / 0 FAIL, identical row for row.

| Step | Observation (all 5 names: U+0159, U+65E5, U+4E2D, U+0416, U+1F600) |
|------|------|
| CD | The wide WM_SETTEXT into field 210 was read back **exactly** (the field held U+65E5 etc. before OK). No message window appeared. |
| LOC | The panel is in the folder. |
| FOCUS | The focused name, read losslessly from the *Quick Rename* dialog (its combo box is a Unicode window; read with WM_GETTEXT wide, then cancelled), is **exactly `f<X>.txt`**. |
| F3 | Window class `CodeView - WinLib Universal Window2`, `IsWindowUnicode` = **False**. The caption is `...\f?.txt [Plain Text] - Code Viewer` (`f??.txt` for the emoji). GetWindowTextW and InternalGetWindowText agree, so the *stored* caption holds the `?`. The status bar reads **"7 lines"**: the fixture gave a.txt 1 line, f<X>.txt 7 lines and z.txt 3 lines, so the viewer read the CJK file's content. |
| NAV | The same file was focused by Home + 2 x Down. FOCUS reads it exactly, and F3 gives the identical caption and "7 lines". |
| Control U+0159 | The caption is correct (the character is in code page 1250). |
| DISK / END | The files are unchanged and the program exits with code 0. No new crash reports appeared. |

`probe/caption_technique_probe.ps1` (result in `caption_technique_result.txt`, run on the
hidden desktop, no product code) isolates the mechanism with an ANSI-class window and a
Unicode-class window:

- On the ANSI class, `SetWindowTextW("f<U+65E5>.txt")` stores `f?.txt`. The emoji is stored as
  `f??.txt`, and U+0159 is stored exactly.
- On the ANSI class, `DefWindowProcW(hwnd, WM_SETTEXT, 0, text)` stores the text **exactly**.
  The caption bar, the taskbar, Alt+Tab, and GetWindowTextW from another process all read this
  stored caption. Only an in-process `GetWindowTextW` still returns `?`, because WM_GETTEXT goes
  through the ANSI window procedure.
- On the Unicode class, both calls store the text exactly.

## Cause (read)

- `src/plugins/codeview/viewer.cpp:153` creates the window with `CreateEx(..., CWINDOW_CLASSNAME2, ...)`.
  That is the ANSI winlib class: `src/common/winlib.cpp:508-513` (`RegisterClass`, `CWindowProc`)
  and `:142` (`CreateWindowEx` A).
- `src/plugins/codeview/viewer.cpp:653` `UpdateTitle` builds the caption wide from end to end
  (`SplU8ToWAlloc`) and then calls `SetWindowTextW(HWindow, title)`. The system thunks this to
  ANSI for the ANSI window procedure, and the `?` is made there.
- Change Directory itself is UTF-8 clean:
  - `fileswn3.cpp:2318-2326` uses W enumeration (`SalFindFirstFile` + `SalConvertFindDataW`) and
    takes the disk's spelling as UTF-8.
  - `:2484-2492` cuts the name off (`CSalHeapString` + `CutDirectory`) and calls
    `ChangePathToDisk(..., name, ...)`.
  - `fileswn2.cpp:1715-1719` keeps it in a `SAL_FIND_NAME_U8` backup, and `:1872` passes it to
    `CommonRefresh` (the 092 ordinal look-up).
  - No A API or code-page conversion is on this path.

## Since when

- The Code Viewer has shown the lossy caption since it shipped. Its title was reworked into
  this form in `50e39db4` (feature 070), and `v0.1.8` carries the same line (`viewer.cpp:653`).
- Before 070, F3 on `.txt` opened the internal viewer. Its caption has used `SetWindowTextW` on
  the ANSI class `CVIEWERWINDOW_CLASSNAME` since `14d384cd` (feature 004). So **every release has
  shown `?`** for these names. Before 004, the names were already `?` in the panel.

## Who is affected

Any file name with a character outside the system code page is affected: CJK, Cyrillic or Greek
on a Czech Windows, emoji, and the reverse cases on other code pages. The consequence is
**display only**. The caption, the taskbar button and Alt+Tab show `?`. Focus, opening and
content are correct. Two such files in one folder (for example `f<U+65E5>.txt` and
`f<U+4E2D>.txt`) get indistinguishable captions.

## Other entry points (question 3)

None of them shares a defective step, because the defect is in the viewer caption and not in how
the file is focused. Every route to F3 gives the same caption:

- Read: the command-line `cd` and `-L` both go to `ChangeDir`. The command line is read through
  `GetCommandLineW` (`salamdr1.cpp:3669`).
- Read: Find's "Focus file" (`finddlg1.cpp:2451`, `finddlg2.cpp:1971`) uses `WM_USER_FOCUSFILE`
  (`fileswnb.cpp:870`), then `ChangeDir`, then `NextFocusName`, all UTF-8.
- Driven: plain navigation.

## Twins (same pattern: `SetWindowTextW` on an ANSI top-level class; read, not driven)

- `src/viewer3.cpp:104`: the internal viewer.
- `src/plugins/mdview/viewer.cpp:530`: Markdown Viewer.
- `src/plugins/pictview/render1.cpp:193`
- `src/plugins/dbviewer/renmain.cpp:293`
- `src/plugins/filecomp/mainwnd.cpp:899, 2059, 2157` and `worker2.cpp:110`. The last one runs
  on a worker thread.
- `src/mainwnd1.cpp:2019`: the main window title, which shows the panel path. Feature 092
  already noted that this title goes through the code page. Its "unchanged?" test at `:1957`
  reads the title back with in-process `GetWindowTextW`.
- `SalSetWindowTextU8` (`winlib.cpp:1111`) has the same weakness whenever its target is an
  ANSI window.

## Proposed fix (smallest safe)

1. Add one helper per side, with the same body:
   - Core: next to `SalSetWindowTextU8` in `winlib`.
   - Plug-ins: header-only, in `src/plugins/shared/splunicode.h`, so no ABI change.

   The body:

   ```
   if (IsWindowUnicode(h)) SetWindowTextW(h, w); else DefWindowProcW(h, WM_SETTEXT, 0, (LPARAM)w);
   ```

2. Use the helper at the codeview site and at the twins above, and make `SalSetWindowTextU8` use
   it too.
3. In `mainwnd1.cpp`, compare against `InternalGetWindowText`, not `GetWindowTextW`. The in-process
   read-back stays `?`, so the current test would see a change on every call and reset the title
   and tray tip each time.
4. Call the helper only from the window's own thread. `filecomp/worker2.cpp:110` sets the title
   from a worker thread; check that site or route it to the window's thread.
5. Ruled out as the smallest fix: making the viewer frames Unicode windows (`CreateExW` +
   `CWINDOW_CLASSNAME2W` + `UnicodeWnd`). That changes WM_CHAR, menu and key handling in five
   plug-ins.
6. Drive afterwards: re-run `cjk_focus_probe.ps1`. F3 must then show the exact name in
   InternalGetWindowText, and the U+0159 control must stay unchanged.

## Hygiene

- Registry `HKCU\Software\Tandem Commander`: exported before each run and restored afterwards.
  The SHA-256 was identical (`1AB61430...F769`) before and after, in both runs.
- No `tandemcommander.exe` was running before or after.
- `%TEMP%\tc100_cjk` and the run logs were removed by name.
- No product source was changed, nothing was rebuilt, nothing was committed.
