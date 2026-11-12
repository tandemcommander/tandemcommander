# Closing report - 425-desktop-drive-item
Backlog item: ikona-na-desktop-vede-kamsi-neznamo-kam - Desktop in the drive menu opens a virtual fld: view, not the Desktop folder
Outcome: closed

## What changed

- **A core Desktop item.** The Change Drive menu (Alt+F1 / Alt+F2) and the drive bars have a *Desktop*
  item right after *Documents* (`drvtDesktop` = 21, appended to `CDriveTypeEnum`; hot key `'`; icon
  Fluent 2 `OpenDesktop` / Classic imageres 183; drive bar icon-only with the tooltip *Desktop*; no context
  menu). It opens `FOLDERID_Desktop` (`GetDesktopPathU8`: `SHGetKnownFolderPath`, `KF_FLAG_DONT_VERIFY`,
  any length, whole or refused) through `CFilesWindow::ChangePathToDesktop`: the program's check of a path
  first (`SalCheckAndRestorePath` - reconnection, login, ESC, its own error message), a path naming a file
  refused, no path -> "The Desktop folder cannot be found.", too long -> the "path too long" message; the
  panel stays where it was in every failure. Check box *Desktop* on Configuration > Change Drive Menu and
  Drive Bar, value `Change Drive Show Desktop` (absent = on).
- **Shell Folders.** The Folders plug-in's entry reads *Shell Folders* (hot key `-`), handed over as UTF-8
  (`SplLoadStrU8`).
- **Real folders inside fld: open as disk paths.** `ExecuteOnFS` asks `GetDiskPathOfShellFolder`
  (`SFGAO_FOLDER | SFGAO_FILESYSTEM | SFGAO_LINK`, `ILCombine` + `SHGetPathFromIDListEx`, the attributes of
  the path) and the pure rule `SalShellFolderOpensAsDisk` (`src/common/saldesktop.h`): a file-system folder
  whose path is an existing directory -> `ChangePanelPathToDisk`; virtual places, zip archives, folder
  shortcuts (a link without a reparse point), the Recycle Bin and its items, items without a path stay in
  `fld:`. Junctions and directory symlinks open as disk paths.
- On the way (stop-rules rule 11): `SalCheckPath`'s "path or file name is invalid" and "you have canceled
  path checking" messages hold the whole path (heap buffers; were cut at ~360 / ~400 bytes).
- Debug-only probe seams: `TC_PROBE_DESKTOP_FILE` (core), `TC_PROBE_FLD_DUMP` (plug-in; acts only on the
  picked item, never runs a file) - `contracts/probe-seams.md`.
- Manual: `configuration_chdrv.htm`, `navigating_chdrvmenu.htm`, `windows_drivebar.htm`.

### CHANGELOG entry (no `## [Unreleased]` section in `CHANGELOG.md` - the maintainer adds it)

```text
- **The drive menu's Desktop opened a strange "fld:" view instead of the Desktop folder** (feature 425, GitHub #31).
  - **Before:** Alt+F1 / Alt+F2 had an item *Desktop* that belonged to the Folders plug-in: it opened the Windows shell namespace, where the items of the desktop are mixed with This PC, Libraries, Network and Control Panel, and the path line showed only `fld:`. A real folder opened there (Documents, a drive) stayed in that view, without the usual file operations.
  - **Now:** the Change Drive menu and the drive bar have a real *Desktop* item right after *Documents* (hot key `'`): it opens your Desktop folder as an ordinary disk folder, also a redirected one (OneDrive, a network share - reconnected as a typed path is); a new check box *Desktop* on Configuration > Change Drive Menu and Drive Bar hides it. The plug-in's item is called *Shell Folders* (hot key `-`), and a real folder opened inside it switches the panel to its disk path; This PC, Control Panel, Network, the Recycle Bin and folder shortcuts stay in the shell view.
  - **Limitation:** inside the shell view the path line still shows only `fld:`.
```

## Measurements (before / after, commands)

- `probe/desktop_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`; seams
  `TC_PROBE_DRIVES_DUMP`, `TC_PROBE_DESKTOP_FILE`, `TC_PROBE_FLD_DUMP`; registry backed up and restored,
  SHA-256 identical in every run):
  - before, main 472d20a8 (`probe/result_before.txt`, the probe's first version): **2 PASS / 8 FAIL / 3 NOT DRIVEN**
    - no core Desktop item, the plug-in item `'\tDesktop`, fld: rows not drivable without the seam;
  - negative control, the fld: fix disabled (`probe/result_negative.txt`): 12 / 3 - FLD-USER, FLD-DOCS,
    FLD-DRIVE stay in `fld:`;
  - negative control, the old message (`probe/result_negative_long.txt`): ERR-LONG FAIL (cut at 359 bytes);
  - after, 1b31ec01 (`probe/result_after.txt`): **18 PASS / 0 FAIL / 0 NOT DRIVEN** - MENU-DESKTOP,
    MENU-PLUGIN, BAR-DESKTOP, SAVED, OPT-OFF, REGRESS, OPEN-MENU, OPEN-BAR, ERR-NONE, ERR-MISSING, ERR-FILE,
    ERR-LONG, FLD-CPL, FLD-USER, FLD-DOCS, FLD-DRIVE, FLD-ZIP, FLD-RB.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `python tools/brand/fluent-icons/check_iconset.py`: 0 problem(s).
- `.\build.cmd full` (Debug x64): BUILD SUCCEEDED, 189 language modules.
- `saltests`: 287,414 checks, 0 failed (`TestDesktopDrive425`).
- Translations: two-stage refresh of `salamand` (3 gaps a language) and `folders` (1 gap); DeepL 400
  characters; pins in `translations/ui-overrides.json` (`_feature_425`): the plug-in entry in all 8
  languages, the error text in cs/sk/nl/hu; `translate.slt --verify` byte-exact (298 files); no layout drift
  outside the Change Drive page's own re-layout.
- Probe: 18 / 0 / 0 (above).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD 1 (a deleted folder in the Recycle Bin opened its storage as a disk panel) and
  SHOULD 2 (the Desktop item skipped network reconnection) fixed; NOTE 1 (whitespace) and NOTE 3 (the
  backtick hot key is a dead key) fixed; NOTE 2 (off languages keep the old plug-in text) recorded.
- Review 2: no MUST. SHOULD 1 (a folder shortcut / network location opened its own folder) fixed; NOTE 1
  (code-page menu text) fixed; NOTE 4 (cut path-not-found message) fixed with probe row ERR-LONG; NOTEs 2-3
  accepted (fail-safe; not a regression).
- Review 3: no MUST. SHOULD 1 (junctions and directory symlinks stayed in fld:) fixed; NOTE 1 (the
  canceled-check message cut the path) fixed; NOTE 3 (`SplLoadStrU8`) fixed; NOTE 2 (zh-CN format, off)
  recorded. Review 3's fixes were not reviewed again (saltests and the final probe cover them).

## Owed to a person (the lines added to the release checklist)

4 lines added to `manual-checks-owed-before-the-next-release`: the Desktop item and button on a real screen
(Fluent 2 / Classic, Default / Dark); the Czech UI (*Plocha*, *Složky Windows*, the check box); a Desktop on
a network share or a disconnected mapped drive; a folder shortcut and a junction inside `fld:`.
GitHub #31: answer and close (draft in `specs/425-desktop-drive-item/reply.md`).
The CHANGELOG entry above (no `## [Unreleased]` section).

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- `SalCheckPath`'s path-not-found message cut a long path (~360 bytes), even inside a character - heap
  buffer; probe ERR-LONG FAIL -> PASS (review 2, NOTE 4).
- `SalCheckPath`'s canceled-check message, the same with ~400 bytes - heap buffer (review 3, NOTE 1; ESC
  during a slow check, not driven).

## New Inbox items (slug - title)

None.
