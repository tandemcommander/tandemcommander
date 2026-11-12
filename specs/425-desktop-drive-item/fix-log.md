# Fix log - 425-desktop-drive-item

Backlog item `ikona-na-desktop-vede-kamsi-neznamo-kam` (GitHub #31): the drive menu's "Desktop" opens the
Folders plug-in's virtual `fld:` view instead of the Desktop folder.

## Measurement before (main 472d20a8)

- Build: `.\build.cmd` (Debug x64) at 472d20a8 -> BUILD SUCCEEDED.
- Probe `probe/desktop_probe.ps1` (hidden desktop, `TC_PROBE_DRIVES_DUMP`) -> `probe/result_before.txt`:
  PASS 2 / FAIL 8 / NOT DRIVEN 3. The Alt+F1 list: no core Desktop item (Documents idx 6, nothing of a new
  type after it), no drive-bar Desktop button; the plug-in items `'/' FTP Client | ''' Desktop | ...` - the
  Folders plug-in's `'\tDesktop`; OPT-OFF / REGRESS pass trivially; the fld: rows NOT DRIVEN (no plug-in seam).
- By reading: `CPluginInterfaceForFS::ExecuteOnFS` (`src/plugins/folders/fs1.cpp`) enters every folder with
  `AddItemToIL` + `ChangePanelPathToPluginFS(.., "?")`; `GetCurrentPath` gives an empty user part - the path
  line is `fld:` at every depth.
- Measured with Shell.Application (this Windows 11, Czech UI): the fld: root lists the user's folder,
  Documents, Music, Downloads, Pictures, Videos, Desktop, OneDrive (file-system folders), This PC, Recycle
  Bin, Control Panel (twice: the category folder and a non-folder item), Libraries, Gallery, Network, Home
  (virtual) and two zip archives (shell folders whose path is a file). This PC lists only the drives.
- Stored plug-in drive-menu texts (`FS Cmd Name`): `;` Documents (core), `,` Network, `.` As Other Panel,
  `/` FTP and SFTP, `'` Folders -> the core Desktop takes `'`, Shell Folders takes `-` (first the backtick; review 1 NOTE 3: a dead key).

## Decisions

- Classic icon: imageres.dll 183 (rendered: the Explorer Desktop folder icon; 110 = a monitor). Fluent 2:
  the existing `OpenDesktop` (light + dark).
- analyze U1 (MEDIUM): an unreadable (access denied) Desktop is left to `ChangePathToDisk`; see below.

## Implementation

- Pure rules: `src/common/saldesktop.h` (`SalDesktopFolderUsable`, `SalShellFolderOpensAsDisk`, header-only,
  used by the core and the plug-in) and `SalDesktopPathToU8` in `salmydocs.h`; `saltests` `TestDesktopDrive425`.
- Core: `drvtDesktop` (21, appended); built right after Documents under `ChangeDriveShowDesktop` (value
  `Change Drive Show Desktop`, default on, absent = on), hot key `'`, icon `OpenDesktop` / imageres 183;
  drive bar icon-only, tooltip, no context menu; `GetDesktopPathU8` (`SHGetKnownFolderPath(FOLDERID_Desktop,
  KF_FLAG_DONT_VERIFY)`, Debug seam `TC_PROBE_DESKTOP_FILE`); `CFilesWindow::ChangePathToDesktop`: no path ->
  `IDS_DESKTOPNOTFOUND`; not a directory -> `IDS_PATHERRORFORMAT` with the path (heap buffer, UTF-8 pieces);
  too long -> `IDS_TOOLONGPATH`; else `ChangePathToDisk`. Check box "Des&ktop" (6305) on the Change Drive page.
- Plug-in: `IDS_DRIVEMENUTEXT` = "-\tShell Folders"; `ExecuteOnFS` sub-folder branch asks
  `GetDiskPathOfShellFolder` (attributes on the current folder, `ILCombine` + `SHGetPathFromIDListEx` into a
  32768-unit buffer, `SplWToU8` whole into `SAL_MAX_PATH_UTF8`, `SalGetFileAttributes`) and calls
  `ChangePanelPathToDisk`; nothing of `fs` / `file` is used after it. Debug seam `TC_PROBE_FLD_DUMP` (LIST /
  EXEC lines; only the `.pick` item is acted upon, a file is never run).
- Build traps met: `small` is a Windows macro (rpcndr.h); a `goto ON_FATAL_ERROR` may not jump over an
  initialized local (the probe counters are declared at the top); `sed -i` dropped the CRs of saltests.cpp
  (restored), a Bash here-document collapsed the backslashes of the test strings (fixed with the editor).

## Measurement after

| Run | Build | Result |
|---|---|---|
| `result_before.txt` | main 472d20a8 (the probe's first version, from the scratchpad; rows FLD-DRIVE / FLD-ZIP were added after) | PASS 2 / FAIL 8 / NOT DRIVEN 3 |
| `result_negative.txt` | this branch with the fld: fix disabled (one temporary line `free(diskPath); diskPath = NULL;`, reverted) | PASS 12 / FAIL 3 - FLD-USER, FLD-DOCS, FLD-DRIVE stay `fld:` (the old behaviour); FLD-CPL, FLD-ZIP pass |
| `result_after.txt` | this branch, `build.cmd full` | PASS 15 / FAIL 0 / NOT DRIVEN 0; registry restored, identical |

- `saltests`: 287,391 checks, 0 failed (`TestDesktopDrive425` included).
- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s); `check_iconset.py`: 0 problem(s).
- analyze U1: an existing but unreadable (access denied) Desktop folder passes the directory check and goes to
  `ChangePathToDisk`, which reports the listing error as it does for a typed path and for Documents (accepted:
  the item says "the same as typing it"; not drivable on the hidden desktop).
- The plug-in's stored drive-menu text (`FS Cmd Name`) is replaced at the plug-in's next load: every new
  `plugins.ver` (installer update) loads all plug-ins once (`CPlugins::ReadPluginsVer`). The probe forces it by
  resetting `Plugins.ver Version (x64)`.

## Translations

- Step 0 entries: `salamand` new `IDS_DESKTOPDRIVE` (14163), `IDS_DESKTOPNOTFOUND` (14164), dialog control
  `IDC_CHD_SHOWDESKTOP` (6305) of `IDD_CFGPAGE_CHANGEDRIVE` (9 controls of the page moved 13 DLU, the group
  box 13 DLU taller); `folders` changed `IDS_DRIVEMENUTEXT` (`STRINGTABLE:0:1004` set to `english_fallback` in
  the 8 enabled languages' `folders.origin`). Leftover `english_fallback` rows before: 0 (enabled languages).
- Templates exported (`build_langs.cmd --export-templates --module salamand|folders`); dry runs: salamand 3
  gaps / ~50 chars per language, folders 1 gap / ~16 chars; real merges `--formality prefer_more` with budgets
  2800 / 2256: DeepL characters 392 + 8, validation failures 0.
- Read-back: the check box and the item name fine everywhere (cs/sk "Plocha", nl "Bureaublad", fr "Bureau",
  de/ro "Desktop", hu "Asztal", es "Escritorio"; accelerators unique on the page in every language).
  Pinned (`ui-overrides.json`, `_feature_425` notes): `folders` `IDS_DRIVEMENUTEXT` in all 8 languages
  (DeepL left "Shell Folders" English): cs "Složky Windows", sk "Zložky Windows", de "Windows-Ordner",
  fr "Dossiers Windows", nl "Windows-mappen", hu "Windows-mappák", ro "Foldere Windows", es "Carpetas de
  Windows"; `salamand` `IDS_DESKTOPNOTFOUND` in cs/sk/nl/hu (DeepL quoted the English "Desktop" instead of the
  item's name). Merges again: 0 failures; `translate.slt --verify`: 298 files, round-trip byte-exact.
- Layout drift: none outside the page's own re-layout (the 9 moved controls in each language).
- `build.cmd full`: BUILD SUCCEEDED, 189 language modules.

## Review

### Review 1 (refute-first agent) - no MUST, 2 SHOULD, 6 NOTE

The reviewer re-ran the probe (15 / 0, registry identical) and saltests (287,391 / 0), enumerated the
callers (build, bar inclusion, icon-only style, tooltip, context menu, ExecuteItem, the checked item,
ChangeDrive, CDriveBar::Execute) and found the Desktop type handled wherever Documents is.

- **SHOULD 1 (fixed)**: Enter on a deleted folder in fld: > Recycle Bin opened the bin's storage
  (`C:\$Recycle.Bin\<SID>\$R...`) as a disk panel - measured by the reviewer's scratch probe. Now
  `SalShellFolderOpensAsDisk` takes `inRecycleBin`: the current fld: folder is the Recycle Bin or inside
  it (`SHGetKnownFolderIDList(FOLDERID_RecycleBinFolder)` + `ILIsEqual` / `ILIsParent`), or the path has a
  `$Recycle.Bin` / `RECYCLER` / `RECYCLED` component (`SalPathHasRecycleBinPart`, saltests). New probe row
  FLD-RB (a fixture folder recycled, its `$R` / `$I` entries removed at the end): the reviewer's run
  before the fix FAIL (action=disk) -> PASS (action=fld, panel fld:).
- **SHOULD 2 (fixed)**: the Desktop item's existence check (`GetFileAttributes`) skipped the reconnection
  of a remembered network drive, the login for a share and the ESC wait. Now `ChangePathToDesktop` calls
  `SalCheckAndRestorePath(parent, path, TRUE)` first (it reports a missing or unreachable path itself and
  the panel stays); only a path that names a file is refused afterwards (`SalDesktopPathIsNotFolder`;
  unreadable attributes go on to the path change). Probe ERR-MISSING now shows the core's message ("The
  path or file name ... is invalid"), panel unchanged; new row ERR-FILE (a file at the Desktop path) PASS.
  A redirected network Desktop is not drivable here: a release-checklist line.
- NOTE 1 (fixed): a stray whitespace edit in `fs2.cpp` (`flags =SHCONTF_...`).
- NOTE 2 (fix-log only, stop-rules 11): the disabled languages (chinesesimplified, russian, ukrainian)
  keep `'\tDesktop` in `folders.slt`; enabling one is the maintainer's and would need its refresh.
- NOTE 3 (fixed): the backtick is a dead key on the cs/sk/de/fr/hu layouts - the Shell Folders hot key is
  `-` now (plug-in text, the 8 pins, the manual, the spec documents).
- NOTE 4: covered by SHOULD 2 (the core's check reports the real error).
- NOTE 5: T019 is the closing step (run step 8).
- NOTE 6: only Debug was built; the seams are `#ifdef _DEBUG`. A Release build is part of the release
  (`build.cmd full release`), not run here.

After the fixes: `build.cmd full` BUILD SUCCEEDED (189 language modules), saltests 287,408 / 0, folders
merge 0 gaps (the pins carry the new hot key), `slt --verify` byte-exact, encoding guard TOTAL: 0, probe
`result_after.txt` **17 PASS / 0 FAIL / 0 NOT DRIVEN**, registry identical, the probe's Recycle Bin item removed.

### Review 2 (refute-first agent, on 007c2ec7) - no MUST, 1 SHOULD, 4 NOTE

The reviewer could not re-run the probe (the maintainer's installed program ran at that moment; the
probe refused correctly, nothing was stopped); saltests 287,408 / 0; review 1's two fixes confirmed by
reading and against the API; callers, hot keys, encoding, the page layout checked again.

- **SHOULD 1 (fixed)**: a folder shortcut (a network location of This PC, a folder shortcut on the desktop)
  is a real directory holding `target.lnk` and `desktop.ini`; the shell reports it
  `SFGAO_FOLDER | SFGAO_FILESYSTEM` (and `SFGAO_LINK`), its path is the shortcut's own folder - the disk
  panel showed `target.lnk` instead of the target fld: had followed (measured by the reviewer with the
  plug-in's call sequence and a network location added for seconds, then removed). Now the attributes
  asked include `SFGAO_LINK` and a link stays in fld: (`SalShellFolderOpensAsDisk(.., isLink, ..)`, a
  saltests case). Not driven by the probe: fld: reaches no fixture folder (the root is the real desktop,
  which the probe never writes) - a release-checklist line.
- NOTE 1 (fixed): the plug-in's drive-menu text went through the code-page `LoadStr`; cs/sk "Složky /
  Zložky Windows" would lose `ž` on a system whose code page is not 1250. `Connect` now reads it with
  `LoadStrW` and hands it over as UTF-8 (`SplWToU8`; the core keeps valid UTF-8, contract 052), the
  code-page text only if that fails.
- NOTE 2 (accepted): `SalPathHasRecycleBinPart` also matches a user folder named `Recycled` / `RECYCLER`
  in fld: - it stays in fld:, the old behaviour; fail-safe.
- NOTE 3 (accepted, not a regression): `SalGetFileAttributes` of an unreachable share inside fld: blocks
  the main thread without ESC, as the old bind and listing did.
- NOTE 4 (fixed, a finding of severity 2 met on the way - stop-rules rule 11): `SalCheckPath`'s
  "The path or file name ... is invalid." message (`salamdr5.cpp`, the case of `ERROR_PATH_NOT_FOUND` and
  its siblings) formatted into `char text[MAX_PATH + 100]` with `_TRUNCATE` - a missing path of more than
  about 360 bytes was shown cut, even inside a character. Now a heap buffer as long as the message needs.
  New probe row ERR-LONG (a missing Desktop path of ~450 bytes through the seam; the box wraps the path,
  white space is ignored): before the fix FAIL (`probe/result_negative_long.txt`), after PASS. The
  "checking path, ESC" wait window above it still trims at a whole character (display shortening, rule
  097) and is left as it is.

After the fixes: `build.cmd full` BUILD SUCCEEDED (189 language modules), saltests 287,409 / 0, probe
`result_after.txt` **18 PASS / 0 FAIL / 0 NOT DRIVEN** (registry identical, the probe's Recycle Bin item removed).
