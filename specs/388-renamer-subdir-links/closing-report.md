# Closing report - 388-renamer-subdir-links
Backlog item: renamer-include-subdirectories-descends-into-junctions-and - Renamer: Include subdirectories descends into junctions and folder links
Outcome: closed

## What changed

- `src/common/salreparse.h`: `SalListedDirIsLink(listedAttr, tagRead, tag)` - a directory listed
  with the reparse bit is a link when its tag could not be had, is 0, or is a name surrogate
  (junction, mount point, symbolic link, WSL link); a readable non-surrogate tag (cloud, OneDrive,
  dedup, WOF) is a plain folder. Built on feature 197's `SalDeleteAsDirLinkDecision`.
- `src/plugins/renamer/rendlg.cpp`: `LoadSubdir` never walks a directory link; the link is an item
  of its own (mask matched as a selected folder's name, the existing too-long refusal). A selected
  or focused folder that is a link (`SelectedDirIsLink`: looked up once only when the panel shows
  the reparse bit) is listed, not walked. The count line counts listed links as folders.
- `src/plugins/renamer/crenamer.{h,cpp}`: the `WIN32_FIND_DATAW` constructor of `CSourceFile` takes
  `isDir` (default FALSE): a folder item has no extension.
- `src/saltests/saltests.cpp`: `TestListedDirIsLink388` (16 checks).
- Probe `specs/388-renamer-subdir-links/probe/ren_link_probe.ps1` (new).

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\388-renamer-subdir-links\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\388-renamer-subdir-links\probe\ren_link_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

- Before (build of `c6fa9cd9`, `result_before.txt`): PASS 8, FAIL 6 - `out` listed the junction
  target's 3 files, `loop` ended in the "too long path name" box, `selected` listed the target's
  files, `symlink` the symbolic link target's file, `mask` 2 target files, `rename` wrong listing;
  `plain` (control) PASS.
- After (`result_after.txt`): PASS 14, FAIL 0, NOT DRIVEN 0 - links listed as items, nothing below
  a link, no box; the rename renamed `a.txt`, `sub\b.txt` and the junction itself (`n_out`, still a
  junction), the target's files untouched.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- `.\build.cmd` → `BUILD SUCCEEDED` (the reviewer also ran `build.cmd full` in its own worktree:
  succeeded)
- `saltests.exe` → `saltests: 30740 checks, 0 failed` (16 new); negative control: the new checks
  against the old walk-everything rule - 7 of 16 failed (every link row)
- Probe 388: 8 / 6 → 14 / 0; regression probe 209 (`ren_subdir_probe.ps1`): 8 / 0
- No UI string, menu or dialog changed: no `.slt` refresh needed.

## Reviews (findings and what was done)

Review 1 (refute-first agent): no MUST. SHOULD 2 (the mask is matched with the extension taken from
the name, not "without an extension") - wording fixed in `spec.md` and the code comment. SHOULD 1
(nested links listed and renamed while nested plain folders are not; hidden compatibility
junctions of a profile) - the item asked for this behaviour; the choice is recorded for the
maintainer as a decision item. NOTE 1 (tag 0 stricter than 197) - intended, FR-006 reworded; NOTEs
2-4 accepted (fail closed; count line by reading; cloud / dedup / share folders by saltests only).
Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `CHANGELOG.md` has no `## [Unreleased]` section (the tree is at the 0.2.0 release): add the
  entry below when the next section is opened.

```text
- **The Batch Renamer's "Include subdirectories" renamed files inside junctions and folder links** (feature 388).
  - **Before:** with "Include subdirectories" the Renamer read every folder below the selection, also a junction or a directory symbolic link: the files of the folder the link points to - possibly outside what you selected - were offered and renamed, a link pointing back up listed the same files once per level until a "too long path name" box dropped the listing, and a selected junction listed its target's files.
  - **Now:** a junction, directory symbolic link or volume mount point is never entered; it is listed as an item of its own (its name matched against the mask as a selected folder's) and a rename changes only the link's name. Plain folders, cloud (OneDrive) placeholders and deduplicated folders are read as before.
  - **Limitation:** links below the selected folder are listed and renamed by the rule while plain subfolders are not; whether they should rather be skipped is an open decision.
```

No person-step item: every probe row was driven (Developer Mode allowed `mklink /D`).

## New Inbox items (slug - title)

- `renamer-subdirectories-list-nested-folder-links-as-items-or` - Renamer subdirectories: list
  nested folder links as items or skip them (decision, review:388)
