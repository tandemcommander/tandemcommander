# Fix log - 388-renamer-subdir-links

Backlog item `renamer-include-subdirectories-descends-into-junctions-and` - the Renamer's
"Include subdirectories" descends into junctions and directory links.

## Measure first (main at c6fa9cd9)

- Feature 282 (`282-renamer-long-new-name`) was stopped and never merged - only
  `origin/282-renamer-long-new-name` exists; `git merge-base --is-ancestor` says not merged. On
  `main` `LoadSubdir` still works in `char[MAX_PATH]`, so a loop ends at the 260-byte path (not
  at 282's 1024-level guard) - the descent into links itself is the same.
- Sites (by name): `CRenamerDialog::LoadSubdir` (`rendlg.cpp`) - `if (fd.dwFileAttributes &
  FILE_ATTRIBUTE_DIRECTORY)` recurses with no look at `FILE_ATTRIBUTE_REPARSE_POINT`;
  `CRenamerDialog::ReloadSourceFiles` - `if (subdirs && item->IsDir)` calls `LoadSubdir` also for
  a selected item that is a junction.
- Reachable: panel → select a folder → Ctrl+Shift+R (Batch Rename) → tick "Include
  subdirectories" (`IDC_SUBDIRS`) → `ReloadSourceFiles`. Default configuration.
- Probe written: `probe/ren_link_probe.ps1` (style of 209's `ren_subdir_probe.ps1`; the preview's
  cells read with 127's `lvtext_lib.ps1`, full-path mode `CMD_FULLPATH` 609). Links are created
  with `mklink /J` / `mklink /D` inside `%TEMP%\tc388_ren`, removed with `rmdir` before the
  fixture is deleted.

Command (PowerShell, repository root):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\388-renamer-subdir-links\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\388-renamer-subdir-links\probe\ren_link_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Result before (`probe/result_before.txt`, build of c6fa9cd9): **PASS 8, FAIL 6**.

| Row | Before |
|---|---|
| out | FAIL - 5 rows: `sel\out\o1.txt`, `o2.txt`, `o3.txt` (the junction's target) listed |
| loop | FAIL - box "Unable to read directory because of too long path name", subdirectories unticked again |
| selected | FAIL - a selected junction lists its target's `o1.txt`, `o2.txt` |
| symlink | FAIL - `sel\sl\o1.txt` (directory symbolic link target) listed (mklink /D worked: Developer Mode) |
| mask | FAIL - 4 rows, `sel\out\o1.txt`, `o2.txt` |
| plain | PASS - control: plain folders walked (`a.txt`, `x\y\z.txt`) |
| rename | FAIL - listing wrong (5 rows), so not renamed |

Registry restored, identical (SHA-256 equal); fixture removed; no process left.

## Decisions

- List the link as an item, never walk it (item *Expected* first option, *Notes*, core 213) -
  spec *Clarifications*.
- The rule `SalListedDirIsLink` in `src/common/salreparse.h`: the listed tag (`dwReserved0`);
  fail closed (no tag / unreadable / surrogate = link), a readable non-surrogate tag = plain.
- A selected item is looked up only when its panel attributes carry the reparse bit.

## Analyze

- speckit-analyze: 0 CRITICAL, 0 HIGH. LOW A1 (T003 wording) fixed. MEDIUM U1 accepted: cloud /
  dedup / WOF reparse folders are covered by saltests rows only - the probe cannot create a cloud
  placeholder; the rule is pure and the listing hands it the tag unchanged. LOW C1 (file symbolic
  link, no change intended) no task.

## Implementation

- `src/common/salreparse.h`: `SalListedDirIsLink(listedAttr, tagRead, tag)` - no reparse bit →
  plain; tag unread or 0 → link (fail closed); else 197's `SalDeleteAsDirLinkDecision(FALSE, TRUE,
  tag)` (name surrogate = link; cloud / OneDrive / dedup / WOF = plain).
- `src/plugins/renamer/rendlg.cpp`:
  - `LoadSubdir`: a found directory that the rule calls a link (`fd.dwReserved0` = the listed tag)
    is never passed to `LoadSubdir`; when `AgreeMasks(name, NULL)` it is added as a folder item
    (`CSourceFile(fd, …, TRUE)`), with the same `NameLen < MAX_PATH` refusal (`IDS_TOOLONGPATH`,
    Skip / Skip All / Cancel) as a file - never cut.
  - `SelectedDirIsLink` (new, static): a selected / focused folder whose panel `Attr` has the
    reparse bit is looked up once (`FindFirstFileW(SplU8ToWExtAlloc(FullName))` → its own entry
    and tag); a failed look-up is a link. Without the bit: no call, walked as before.
  - `ReloadSourceFiles`: `subdirs && item->IsDir && !SelectedDirIsLink(item)` → walk; a link goes
    the existing non-recursive branch (mask, added as a folder item). The folders count of the
    count line is taken from the listed items after the listing (links added by `LoadSubdir`).
- `src/plugins/renamer/crenamer.{h,cpp}`: the `WIN32_FIND_DATAW` constructor got `BOOL isDir =
  FALSE`: a folder has no extension (`Ext` at the end, as the `CFileData` constructor) and
  `IsDir = 1`. The other caller (files) unchanged.
- T009 (by reading): a directory without the reparse bit, or with a readable non-surrogate tag,
  takes `else if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)` → `LoadSubdir` exactly as before;
  a selected folder without the bit returns from `SelectedDirIsLink` before any call.
- A renamed link item after the rename (209's reload from `RenamedFiles`): `CSourceFile(orig,
  newName)` keeps `Attr` (with the reparse bit) → looked up under its new name → listed, not walked.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` | `BUILD SUCCEEDED` |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 30740 checks, 0 failed` (16 new) |
| clang-format | `clang-format --dry-run` on the changed files | 0 new findings (the one in `salreparse.h` line 33 is old code) |
| negative control (saltests) | the 16 new checks compiled in a scratch copy (`%TEMP%\…\scratchpad\neg388`) against a `SalListedDirIsLink` that returns FALSE (the walk before the change) | `16 checks, 7 failed` - every link row fails, the plain / cloud rows pass |
| negative control (probe) | the probe on the build of c6fa9cd9 (`result_before.txt`) | 6 FAIL |
| probe after | `ren_link_probe.ps1` (`result_after.txt`) | **PASS 14, FAIL 0, NOT DRIVEN 0**; registry restored identical; fixture removed |

Probe note: the first after-run had `rename` FAIL "Not valid full path." - the probe's own error
(it left the preview in full-path mode, `CMD_FULLPATH`, where a plain new name is no full path).
The probe now posts `CMD_FILENAMES` (607) before renaming; re-run 14 / 0. The before-run did not
reach the rename (its listing was already wrong), so its result stands.

After the change, row by row: `out` 3 rows (`a.txt`, `out`, `sub\b.txt`); `loop` 2 rows (`a.txt`,
`loop`), no box; `selected` 1 row (`jsel`); `symlink` 2 rows (`a.txt`, `sl`); `mask` 2 rows;
`plain` 2 rows (control unchanged); `rename` → `n_a.txt`, `sub\n_b.txt`, junction `n_out`, the
target still `o1.txt,o2.txt,o3.txt`.
