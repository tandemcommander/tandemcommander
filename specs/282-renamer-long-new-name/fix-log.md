# Fix log: 282 - The Renamer builds a new name of any length the file system accepts

From backlog item `renamer-long-new-name-limits` (207's review): a new name was capped at 259 bytes
of UTF-8 (`newName[MAX_PATH]` and the related buffers); an item found through "Include
subdirectories" was refused at 260 bytes while a selected one is accepted.

## Measured (before, c02b0f78)

New probe `probe/ren_longnew_probe.ps1` (the driver of 199 / 207 / 209), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\282-renamer-long-new-name\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\282-renamer-long-new-name\probe\ren_longnew_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before"
```

`probe/result_before.txt`: **11 PASS / 7 FAIL** (L = 90 CJK letters, 270 bytes; M = 45):
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
