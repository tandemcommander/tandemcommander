# Research: 305

## R1 - Is the core's reader cut? (measured at 31239f48)

`probe/measure_core.cpp` (built with `cl /EHsc /std:c++latest /utf-8 /I src\common`, minimal
stand-ins for the core's UTF-8 conversions): plain `.lnk` files and a folder shortcut whose item
list (built folder by folder, `SetIDList`) names targets of 250 / 259 / 260 / 261 / 300 / 400
units.

- D:\Build\tcm_core305 (no 8.3 names): 250 / 259 whole. 260+: `SalShellLinkGetPathU8`
  (`SLGP_UNCPRIORITY`) NOERROR, 259 units, `\\?\D:\Build\tcm_core305\...` cut mid-name, does not
  exist; `SLGP_RAWPATH` the same; `SalFolderShortcutTargetU8` NOERROR with the cut path.
- %TEMP% (C:, 8.3 names): 260+ answered in the 8.3 form (87-109 units), exists - not cut.

Decision: the defect is real for every consumer; the fix belongs in the reader.

## R2 - Share the plug-ins' rule or keep a core twin?

- Decision: a core twin in `salshelllink.h` (`SalShellLinkWholeTargetW`, `SalPlainPathAllocW`),
  the same rule as `SplFileDlgDetail::WholeFolderShortcutTargetW` (feature 304).
- Rationale: the item names the core; changing `splfiledlg.h` (compiled into plug-ins, tested by
  304) is outside the item. The pair `SalIsFolderShortcutIni` / `IsFolderShortcutIni` already
  follows this pattern. saltests checks both twins with the same table.
- Alternative: one header in `src/common/` included by `splfiledlg.h` - rejected for this item
  (touches three plug-ins for no user-visible change); can be a later cleanup.

## R3 - What does a refusal return?

- Decision: `HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)` - a failure (`!= NOERROR`) for every
  caller; `SalFolderShortcutTargetU8` already returns exactly this code as its "too long" result,
  so it passes the refusal on and Browse For Folder keeps feature 286's refusal (instead of
  `S_FALSE`, which would silently pick the shortcut folder itself).
- The existing "does not fit the caller's buffer" failure stays `E_FAIL` (tests of 128 check
  `FAILED`).

## R4 - The raw-path question

`SLGP_RAWPATH` answers the text stored in the link (environment strings not expanded); the item
list's file-system name is not comparable. Callers (`FocusShortcutTarget`, `Execute`) ask it only
to find a link to a server (`\\server`), then fall back to the item list's own name. Decision: a
raw answer of 259+ units fails (`ERROR_FILENAME_EXCED_RANGE`) without reading the item list -
fail closed (item *Approach*).

## R5 - Caller routes after a refusal (read at 31239f48)

| Caller | Route on failure (unchanged) |
|---|---|
| `CFilesWindow::Execute` (`fileswn2.cpp`, Enter) | after Resolve, the server test (raw path, then item list name into MAX_PATH); not a server → not dir / not file → the `.lnk` opened through its association |
| `CFilesWindow::FocusShortcutTarget` (`fileswn0.cpp`, Go to Shortcut Target, 838) | the server test; otherwise `IDS_SHORTCUT_WRONG_PATH` message |
| `GetCurrentDir` (`shellsup.cpp`, drop) | not a dir / file → archive test of the `.lnk` → the shell's drop target of the `.lnk` if any |
| `SalFolderShortcutTargetU8` → `ResolveNetHoodPath` / `GetTargetDirectory` (`shellib.cpp`) | `ERROR_FILENAME_EXCED_RANGE` → refused as too long (feature 286) |

With a proven whole name the callers get a long plain path: `Execute` / `FocusShortcutTarget`
check it with `CheckPath` and change the panel (long-path capable, features 004 / 181);
`GetCurrentDir` copies it into `DropPath[SAL_MAX_PATH_UTF8]`; `GetTargetDirectory` refuses it as
too long for its `MAX_PATH` buffer (feature 286's rule).

## R6 - Probe fixture volume

The defect exists only on a volume without 8.3 names; `%TEMP%` is on C: (8.3 names). Decision:
the probe's fixture lives in the build folder (`<build>\tc305`, E:, no 8.3 names - the same place
saltests 304 uses), every typed path starts with that root. The `.lnk` is written by
`probe/mklnk305.cpp` (item list built folder by folder - `IShellLinkW::SetPath` and
`WScript.Shell` refuse 260+ unit targets).
