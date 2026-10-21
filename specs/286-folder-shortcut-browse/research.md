# Research - feature 286

## R1 Follow a long target, or refuse it

- Decision: refuse with `IDS_TOOLONGPATH`; `GetTargetDirectory` returns FALSE.
- Rationale: every caller holds the result in `MAX_PATH` bytes; the plug-in interface promises
  only "min. MAX_PATH" and plug-ins receive a code-page copy (`CSalamanderGeneral::GetTargetDirectory`,
  frozen by feature 069). Widening is the maintainer's (plug-in interface).
- Alternatives: a second, heap-returning routine for core callers - every core caller then
  hands the path to `MAX_PATH` consumers (`ChangePathToDisk` is long-path capable, but the
  dialog fields and `CFileTimeStamps` are not); larger than the item.

## R2 The code-page fallback of `SalSHGetPathFromIDListU8`

- Decision: remove it. `SHGetPathFromIDListW` failing means no file-system path (the `A` twin
  fails then too); `SalWToU8` failing means "does not fit" - reported as too long.
- Rationale: the `A` form uses best-fit / `?` (measured: `pick-long` got `????...`), another
  folder; CLAUDE.md "never pass names to an `A` API".
- Consequence for the other user, `GetMyDocumentsOrDesktopPath` (buffer `2 * MAX_PATH`): a
  Documents path that does not fit now falls to the Desktop path (or FALSE) instead of a
  code-page path. Same rule, no new behaviour beyond dropping a wrong path.

## R3 Where the folder-shortcut rule lives

- Decision: header-only `src/common/salshelllink.h` (already the home of the shortcut-target rule,
  features 128 / 181): `SalIsFolderShortcutIni` (pure) and `SalFolderShortcutTargetU8` (reads
  `desktop.ini` and `target.lnk` through wide, `\\?\`-capable names; target through
  `SalShellLinkGetPathU8` into a heap buffer of `SAL_MAX_PATH_UTF8`, then compared with the
  caller's size).
- Rationale: testable by `saltests` against real folder shortcuts; distinguishes "too long"
  from "not a folder shortcut / unreadable" without the ambiguous `E_FAIL` of
  `SalShellLinkGetPathU8`.
- Alternatives: reuse the plug-in twin `SplFileDlgDetail::IsFolderShortcutIni` /
  `ResolveNetHoodFolderW` (`src/plugins/shared/splfiledlg.h`, feature 121) - a plug-in helper
  header with its own dependencies (`SplU8ToW`), and its target read is `WCHAR[MAX_PATH]`; not
  included by the core. The class-id comparison is the same rule (whole id).

## R4 The Browse tree and folder shortcuts (probe route)

- Measured: the Browse For Folder tree (old style, `BIF_RETURNONLYFSDIRS`) does not list a folder
  shortcut lying inside an ordinary folder, and `BFFM_SETSELECTION` to its path leaves OK disabled.
  Folder shortcuts reach the routine as network locations (*Network Shortcuts*, under This PC /
  Network). The probe does not write into the user's profile: the GUI row is owed to a person;
  the rule is proven by `saltests`.
- The tree hides hidden folders when Explorer does, so the probe's fixture is in a visible
  disposable folder (`-FixtureBase build\probe286`).

## R5 Message and its owner

- Decision: `SalMessageBox(parent, LoadStr(IDS_TOOLONGPATH), LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION)`
  in `GetTargetDirectory`, after the Browse dialog closed - the pattern of other refusals
  (`dialogs5.cpp`, `execute.cpp`). Works from a plug-in's thread like the Browse dialog itself.
