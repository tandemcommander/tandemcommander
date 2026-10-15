# Fix log: 207 - The Renamer's Undo and "Remove source path" never overrun a buffer

Found by the first review of 206 (CRITICAL, older than 206): the Renamer copies a path into
`char dir[MAX_PATH]` with `strcpy` - in `CRenamerDialog::MoveFile` (`rendlg3.cpp`, the target; on
Undo it is the source's ORIGINAL full name) and in the rename loop's "Remove source path" branch
(`rendlg2.cpp`, the source's full name). An item selected in the panel is not refused for its
length (`LoadSelection`, unlike `LoadSubdir`): a name of 90 CJK letters is 274 bytes of UTF-8 -
an ordinary path of 98 UTF-16 units.

## Measured (before)

Probe `probe/ren_long_probe.ps1` (199's driver; one file `<90 CJK letters>.txt`, new name
`a.txt`), the build at 206 (`probe/result_before.txt`, 2 / 4):
- **undo-long** (rename, then Undo - `CMD_UNDO` 621, the question answered Yes): **"Debug Assertion
  Failed! ... Buffer is too small"** - the file stayed `a.txt`;
- **rmsrc-long** ("Remove source path" on - `CMD_RMSOURCEPATH` 620 - and rename): the same
  assertion after the rename;
- short-ctl (an ordinary name, rename and Undo): fine.

Found by the review of this fix (CRITICAL, older): **long-root** - the panel IN a folder whose path
has 260+ bytes of UTF-8 (a folder of 90 CJK letters in the fixture; `probe/result_before_root.txt`,
the build with the two heap copies): `GetPanelPath(PANEL_SOURCE, Root, MAX_PATH)` in
`LoadSelection` failed unchecked, `Root` stayed empty and every item became `\tc207uniq.txt` - the
root of the current drive: the rename tried `C:\tc207uniq.txt` ("Unable to open file: (2)"). With
such an entry in `C:\` the Renamer would have renamed it, overwritten another one there, or (a
full-path pattern onto another drive) copied and deleted it. The row checks first that no such
name exists in `C:\` (NOT DRIVEN otherwise) - nothing outside the fixture was touched.

## Work

`src/plugins/renamer/rendlg3.cpp` `MoveFile` and `rendlg2.cpp` (the "Remove source path" branch):
heap copies (`SG->DupStr`, freed with `free` as the undo entries do); without memory `MoveFile`
reports through `FileError`, the empty folders of "Remove source path" simply stay.

- `src/plugins/renamer/menu.cpp`: Batch Rename is refused before its dialog opens when the panel's
  folder does not fit (`IDS_TOOLONGPATH`, "Unable to read directory because of too long path
  name" - an existing string); `rendlg.cpp` `LoadSelection` loads nothing when `GetPanelPath`
  fails meanwhile - never `\name`.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 8 / 0: undo-long - the file back under its 90-letter name; rmsrc-long -
renamed to `a.txt`, `keep.txt` kept (the folder is not empty, nothing removed); long-root - refused
("Unable to read directory because of too long path name"), the file unchanged, nothing in `C:\`;
short-ctl as before. (An earlier after-run failed undo-long on the probe itself - a closure did not
see the name; the file was back under its name all the same.) Regressions: 199's probe 6 / 0,
206's 10 / 0, 196's 8 / 0.

## Review

First refute-first review (of the two heap copies): correct - `SG->DupStr` is plain `malloc`
(shared CRT; the plug-in frees its results with `free` elsewhere); a low-memory `MoveFile` behaves
like its other failures. Found: the long panel folder (above, CRITICAL - fixed here); SHOULD-FIX
recorded, refusals not cuts: a new name is capped at 259 bytes of UTF-8 (`newName[MAX_PATH]` and
the related buffers), so the long item cannot be renamed to another long name - only Undo restores
it; an item found through "Include subdirectories" is refused at 260 bytes while a selected one is
accepted. Taken (NIT): the low-memory message names the move (`IDS_MOVEERROR`, `SkipAllMove`).
Recorded as **feature 208**: `ChangeCase` (`crenamer.cpp` ~701-760) applies the code-page
`LowerCase` / `UpperCase` byte tables to UTF-8 names (1250 / 1252: C3 -> E3 - invalid UTF-8), and
"strip diacritics" goes through `MultiByteToWideChar(CP_ACP)` - non-ASCII names mangled (not
measured). Second review (of the refusal): accept - the menu item (and its hot key) is the only
way in; `LoadSelection` runs right after it on the same thread (its branch is defensive); no valid
panel is blocked (the item is for disk panels; the limit equals `Root`'s). Taken: the box could
append a stale system error (`ErrorHelper` adds `GetLastError()`) - cleared first. Recorded as
**feature 209**: `ReloadSourceFiles` expands a renamed folder as `Root + Name` - after a full-path
run (`Root` emptied) a relative `name\*.*` against the current folder, after a relative-path rename
`a` -> `sub\a` another folder `Root\a` - its files offered for renaming when "Include
subdirectories" is ticked.
