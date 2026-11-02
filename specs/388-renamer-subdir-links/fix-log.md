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
