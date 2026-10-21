# Fix log: 282 - The Renamer builds a new name of any length the file system accepts

From backlog item `renamer-long-new-name-limits` (207's review): a new name was capped at 259 bytes
of UTF-8 (`newName[MAX_PATH]` and the related buffers); an item found through "Include
subdirectories" was refused at 260 bytes while a selected one is accepted.

## Measured (before, c02b0f78)

New probe `probe/ren_longnew_probe.ps1` (the driver of 199 / 207 / 209), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\282-renamer-long-new-name\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\282-renamer-long-new-name\probe\ren_longnew_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before"
```

First run (`probe/result_before.txt`, later replaced by the final before-run below): **11 PASS / 7 FAIL** (L = 90 CJK letters, 270 bytes; M = 45):
- long-new ("L.txt" -> "Lb.txt"), long-undo, manual-long (manual mode "x.txt" -> "Lc.txt"),
  long-rel (relative mode "x.txt" -> "M\MM.txt"), long-rel-deep ("x.txt" -> 100 a \ 100 b \ 100 c
  ".txt", 300+ UTF-16 units): refused **"Expanded string is too large."**, the file unchanged;
- sub-long-file (folder "sub" holding "L.txt") and sub-long-dir (folder "L" holding "x.txt"),
  "Include subdirectories" ticked: refused on loading **"Unable to read directory because of too
  long path name"** (Cancel drops the box's tick - the probe then does not rename the folder);
- controls: over-comp (one component of 300 characters: refused, x.txt kept), short-ctl (rename
  and Undo) - PASS.

After `speckit-analyze` (C1, C2 - MEDIUM, cheap): the long rows also read the preview's New name /
Path cells (127's `lvtext_lib.ps1`, cross-process `LVM_GETITEMTEXTW`) and a row **deep-guard**
(1030 nested folders - the depth guard of research R3) was added. Final before-run (same build,
`probe/result_before.txt`): **12 PASS / 8 FAIL** - the preview showed **"<Error: Expanded string is
too large.>"** for every long new name (also over-comp: its rename stays refused, but the preview
cell failed); deep-guard and short-ctl PASS (deep-guard refused at ~100 levels by the 260 bytes).
The last character of the new name is typed (WM_CHAR) after `EM_SETSEL` to the end - without the
caret move it went to position 0 ("ta.tx").

Probe traps met: the checks are `GetNewClosure()` blocks - a script function is invisible there and
`Ls` resolved to the alias of `Get-ChildItem` (the first run's facts lacked the contents); the
helpers are `global:` now. 207's `-replace X + '{10,}', ...` never replaced (the comma binds
first). A first long-rel row with "L\L.txt" (545 bytes) was refused by the **New name field
itself** (winliblt `EditLine`, 2 * MAX_PATH = 520 bytes, the system text of error 206) - a
separate limit of the pattern, refused not cut; the rows use M (45 letters) now. Recorded as an
Inbox item at closing.

## Sites (enumerated at HEAD)

- `rendlg2.cpp` `BuildScript`: `char newName[MAX_PATH]`; `GetManualModeNewName`: `MAX_PATH - pathLen`.
- `crenamer.cpp` `CRenamer::Rename`: `char tmp[MAX_PATH]`, `Execute(..., MAX_PATH - pathLen)`,
  the substitutions' `MAX_PATH - pathLen`, the case change's `cap`.
- `preview.h/.cpp`: `NewNameCache[MAX_PATH]` (Rename and the manual line into it - the preview
  shows the error), `TextBuffer[MAX_PATH]` (the path column, `lstrcpyn` cut at a byte),
  `TextBufferW[3 * MAX_PATH]` (a longer text: empty).
- `rendlg.cpp` `ReloadSourceFiles`: `pathBuf[MAX_PATH]`, `dirLen < MAX_PATH`; `LoadSubdir`:
  `SalPathAppend(..., MAX_PATH)`, `item->NameLen < MAX_PATH`.
- `crenamer.h` `CSourceFile::NameLen : 15` - 32,767 at most: a deep found item's UTF-8 name can be
  longer (up to 3 * 32,767 bytes).
- Callers of `Rename` / `GetManualModeNewName`: only `BuildScript` and the preview
  (`CPreviewWindow::GetItemText`). Consumers of `NameLen`: `crename2.cpp` (the variables' string
  end), `preview.cpp`, `rendlg.cpp`.
- Not limits of this item: `Root[MAX_PATH]` (the panel folder - refused before the dialog, 207);
  the pattern fields `NewName` / `SearchFor` 2 * MAX_PATH, `ReplaceWith` MAX_PATH;
  `clashLongName[3 * MAX_PATH]` (a component's long name - fits).

## Work

- `crenamer.h`: `REN_MAX_NAME` = `SAL_MAX_PATH_UTF8` (3 x 32,767 + 1 bytes); `CSourceFile::NameLen`
  15 -> 29 bits (with `IsDir` / `State` still one 32-bit unit); `CRenamer::Rename(..., newNameSize, ...)`.
- `crenamer.cpp` `Rename`: the folder part copied only when it fits with a name character (else -1,
  the existing "Expanded string is too large."); every `MAX_PATH` cap is `newNameSize` / its rest
  `cap`; the substitution's `tmp` is `malloc(newNameSize)`, freed on every return.
- `rendlg2.cpp` `BuildScript`: `newName` = `malloc(REN_MAX_NAME)` (none: `IDS_LOWMEM`, nothing
  built), freed at the end; `GetManualModeNewName(..., newNameSize, ...)` with the same guard.
- `preview.h/.cpp`: `NewNameCache` on the heap (none: the column empty, the warning icon); the
  list view's wide text grows to the text (it held 780 units); the path column copies the full name
  into a growing buffer and cuts the last component - the folder whole (`lstrcpyn` cut it at 260
  bytes, inside a letter).
- `rendlg.cpp` `ReloadSourceFiles`: `pathBuf` = `malloc(REN_MAX_NAME)` (none: `IDS_LOWMEM`, an empty
  listing), `dirLen + 2 <= REN_MAX_NAME`; `LoadSubdir(path, subdir, depth)`: `SalPathAppend(...,
  REN_MAX_NAME)`, a found item up to `REN_MAX_NAME` (as a selected one), the find data and the
  converted name on the heap, deeper than `REN_MAX_DEPTH` (1024) levels the existing "too long path
  name" refusal (research R3: without the 260 bytes ~16,000 levels were possible - past the 1 MB
  stack).
- Not changed: the panel folder `Root[MAX_PATH]` (207), the pattern fields (Inbox item at closing).

T011 (refusals, by reading): `Rename` / `GetManualModeNewName` -1 -> `BuildScript`'s existing
`FileError(IDS_EXP_SMALLBUFFER)` (Skip / Skip all / Cancel; the entry skipped or the build stopped -
nothing renamed); the preview shows the same error; `LoadSubdir`'s refusal returns the box's skip
(Cancel drops the tick, as before); out of memory: `IDS_LOWMEM`, nothing built / listed.

Build: `.\build.cmd` BUILD SUCCEEDED, no warning in the renamer.

## Measured (after)

`probe/result_after.txt`: **22 PASS / 0 FAIL** - long-new, long-undo (back under "L.txt"),
manual-long, long-rel ("M\MM.txt", the folder made), long-rel-deep (300+ units), sub-long-file,
sub-long-dir: renamed, no box, the preview's New name cell is the long name and its Path cell the
folder whole; deep-guard refused at level 1025 ("too long path name", nothing renamed, no crash);
**deep-ok** (added with the fix: 1020 levels - listed and renamed at the bottom, the path column a
2,000+-character folder whole; before the fix it would be refused at ~100 levels like deep-guard -
not run on the old build); over-comp now refused **"Not valid filename."** (the name validation:
a component over 255 - the preview shows the long name, the rename is refused, x.txt kept);
short-ctl as before.

Regressions (`probe/regress_*.txt`): 199 6 / 0, 206 10 / 0, 207 8 / 0, 209 8 / 0, 210 16 / 0,
254 50 / 0. Encoding guard `TOTAL: 0 finding(s)`; `saltests: 25011 checks, 0 failed`.

## Review

**Review 1** (independent, refute-first; re-ran the probe 22 / 0 and a variant probe of its own,
`%TEMP%\rev282\rev282_probe.ps1`, 11 / 1):

- **MUST 1** - a name longer than the longest path is no longer refused (spec US3 scenario 2): the
  cap is bytes only, 98,301 ASCII letters fit; with "Include subdirectories" and relative-path mode
  the New name `$(RelativePath)$(RelativePath)$(Name)` over 100 folders of 200 letters (~40,200
  units) passed `ValidateFileName`, `MoveFile` -> `CheckAndCreateDirectory` made **63 folders of 200
  letters** in the user's tree before "Unable to create directory: (123)"; x.txt kept (no data
  lost). New with 282 - the 260 bytes refused it before anything happened. **Fixed**:
  `REN_MAX_PATH_UNITS` (32,767 - 7: the extended form's prefix `\\?\UNC\` for `\\` and the
  terminator) and `RenNameFitsPath` (`crenamer.cpp`: the UTF-16 units of the folder part the mode
  puts before the name - the item's folder, `Root\` or none - plus the name's; a 4-byte letter = 2
  units) - checked at the end of `Rename` (also the preview's build) and in `GetManualModeNewName`
  and the preview's manual branch: longer -> the existing "Expanded string is too large.", nothing
  made. Probe row **over-max** added (the reviewer's row): negative control on the build without
  the fix `probe/result_review1_before.txt` FAIL (164 folders, 101 by the fixture); after PASS (101,
  the "too large" box).
- NOTE 1 (taken): `GetEditLineU8` (`utils.cpp`) read at most 0xFFFF units - a manual line of
  65,535+ units was CUT and accepted; now refused (-1, the "too large" error).
- NOTE 2 (taken with MUST 1): the preview builds without the folder part - `RenNameFitsPath` counts
  the folder part from the mode, so the preview judges as the rename does.
- NOTE 3 (Inbox, `renamer-include-subdirectories-descends-into-junctions-and`): the listing descends
  into junctions / directory links (as before 282), a loop now up to the depth guard.
- NOTE 4: the reviewer's edge rows - depth 1024 listed and renamed, depth 1025 refused; Search /
  Replace (Boyer-Moore and regex) and upper case on long names PASS with matching preview cells.
- NOTE 5 (fixed): the before-counts in spec / tasks (11 / 7 of the first run) now 12 / 8.
- NOTE 6: closing work (CHANGELOG, FEATURE-HISTORY, the pattern-field Inbox item) - done at closing.
- NOTE 7: the depth refusal names the last folder only (the existing `FileError` with the folder's
  name, as `LoadSubdir`'s long-path refusal always did) - accepted.

After the fix: build BUILD SUCCEEDED (no warning), `probe/result_after.txt` **24 PASS / 0 FAIL**,
the regressions re-run on that build (199 6 / 0, 206 10 / 0, 207 8 / 0, 209 8 / 0, 210 16 / 0,
254 50 / 0).

**Review 2** (independent, refute-first, of the head after review 1; its variant probe and logs in
`%TEMP%\rev282b\` - `rev282b_probe.ps1`, `run1` / `run2_branch` / `run4_branch` / `run5_ctl` on the
branch build, `run3_0110.txt` on the installed 0.1.10 as the negative control; the official probe
re-run 24 / 0):

- **MUST 1 - a regular expression over a long new name crashes the program.** The text
  `RESubst` (`crenamer.cpp`) runs the expression over is no longer bounded by 259 bytes; the regex
  engine recurses once per repetition of a group (`RegMatch`, `regexp.cpp` ~1768-1830); its
  stack-overflow handler (`regexp.cpp` ~1596-1600) does not call `_resetstkoflw()` and `RESubst`'s
  `while (RegExec(...))` does not look at `GetState()` - the first overflow is swallowed (the preview
  shows the name unreplaced), the second kills the process (0xC0000005, no bug report). Reproduced:
  "top" + N nested folders of 200 "a" + x.txt, "Include subdirectories", relative-path mode, New name
  `$(OriginalName)`, regex Search `(a|\\)*x`, Replace `y`: built names of 1,014 / 3,024 / 8,049 /
  ~20,100 units - the process died; a control of 2 folders of 20 letters renamed to `topy.txt`;
  0.1.10 refused all on loading. No file lost (the crash comes before any rename), but the program
  dies. Suggested: `_resetstkoflw()` in the handler, `RESubst` -1 on an error state, possibly
  `RegExec`'s `separateThread` or a bound of the regex input; a probe row `re-deep`.
- **MUST 2 - manual mode cuts a line longer than 1,024 units and renames to the cut name.** The
  manual edit control wraps a line of 1,025+ UTF-16 units into display lines (also with
  `ES_AUTOHSCROLL`; measured 1,025 -> 2 lines, 32,000 -> 32); `Validate` (`rendlg.cpp` ~1672-1680) and
  `GetEditLineU8` (`utils.cpp`, `EM_LINEINDEX` / `EM_LINELENGTH`) count and read display lines. Since
  282 a 1,024-unit piece fits the buffer (before: "too large"). Reproduced (row man-wrap2): x.txt
  and y.txt, relative-path mode, one manual line of five 200-letter folders + 19 "c" + "tail.txt"
  (1,032 units): no box, x.txt renamed to `<B>\<B>\<B>\<B>\<B>\ccccccccccccccccccc` (cut, the
  extension lost, 5 folders made), y.txt to `tail.txt`; 0.1.10: "Expanded string is too large.",
  both kept. Breaks "a name is never cut". Also: a single 1,030-unit manual line for one file is
  refused "Number of entered lines must match" on both builds - review 1's manual checks
  (`GetManualModeNewName`'s `RenNameFitsPath`, the preview's manual branch, the 65,535 guard) are
  unreachable through this control; FR-001 and the CHANGELOG entry overclaim manual mode.
  Suggested: read real lines (split the whole text at CR LF) in `Validate`, `GetEditLineU8` and the
  preview, or at least refuse a soft break (the next line starts where this one ends).
- SHOULD: the Search / Replace rows used 90-letter names only, never a long path; no manual
  over-limit row; over-max does not read the preview cell; `RenNameFitsPath` / `RenU16Units` are pure
  rules without a `src/common` header and `saltests` checks.
- NOTE: `utils.cpp` - the `units + 1 > 0xFFFF ? 0xFFFF : ...` branch is dead after the new early
  return; the CHANGELOG's manual-mode sentence must change with MUST 2.

## Stopped

The second independent review rejected the fix with MUST findings (stop-rules §3 #3): the run
stops here, the work stays on branch `282-renamer-long-new-name` (not merged; `main` unchanged
except the backlog). State of the branch: the item's two defects are fixed and proven (probe 24 / 0,
regressions 199 / 206 / 207 / 209 / 210 / 254 green, encoding guard 0, saltests 0 failed), review 1's
MUST fixed; open are review 2's MUST 1 (regex stack overflow on long names - a crash) and MUST 2
(manual mode's wrapped display lines - a cut name renamed), its SHOULDs, and then a third review.
The CHANGELOG entry on the branch (top of `[0.1.11] — unreleased`) overclaims manual mode and must
be corrected with MUST 2. Not done: closing (FEATURE-HISTORY entry, closing report). The two Inbox
items found on the way are copied to `main`.
