# Fix log: 343 - version-free configuration root (Settings) and SemVer releases

Running log of the implementation (2026-10-25). Newest at the bottom.

## Measured before the change (T002)

- `python tools/release/release.py status 0.2.0` at 52668440 (feature branch, sources = `main`
  72a02f2b):
  `refused: line-change: 0.1.10 -> 0.2.0 changes MAJOR.MINORA; the configuration root
  (HKCU\Software\Tandem Commander\0.1) follows it - decide the migration first`.
  (`dirty-tree` too, because `tasks.md` was not committed yet - irrelevant.)

## Implementation (T003-T021)

- Pure rules: `src/common/salcfgmigrate.h` (decision), `SalRegMapLegacyRoot` in `salregroot.h`;
  saltests `TestCfgRoot343` + dotted crash report names: **28,846 checks, 0 failed**.
- Root `Settings` in `mainwnd2.cpp`, `SALCFG_LEGACY_ROOT`; `MigrateConfigurationRoot()` (RegCopyTreeW
  into `Settings.migrating.63A7CD13`, recursive compare, `RegRenameKey`; the old backup copied to
  `Settings.backup.63A7CD13`); called right after `LoadSaveToRegistryMutex.Init()` in `WinMainBody`.
  On failure the session runs on `0.1` (`SalamanderConfigurationRoots[0]` re-pointed) and
  `WM_USER_CFGMIGRATE_FAILED` shows `IDS_CFGMIGRATE_FAILED` (13753, free slot of the bundle of
  `IDS_CORRUPTEDCONFIGFOUND`) when the main window is free (timer `IDT_CFGMIGRATE_FAILED` 954).
- Import: `Parse(..., legacyRoot)` maps key lines of the 0.1 root; `ImportConfiguration` passes it
  unless the session itself runs on the old root.
- Probe fixtures are made at run time (deviation from T005): the pre-change build (copy of the Debug
  build at 52668440 in the session scratchpad) starts on an empty registry and saves; its `0.1` key is
  exported to `%TEMP%\tc343`. No fixture with the maintainer's paths is committed.
- Probe trip-ups fixed in the probe (not in the product): `reg import` writes to stderr (PS 5.1 +
  `Stop` = terminating) -> `cmd /c ... >nul 2>&1`; `Start-Windows` argument order; IMP-FOREIGN's refusal
  comes before the main window exists (wait for it); a row run alone on an empty registry meets the
  first-start import offer of 245 and End-Row answered Yes - the wizard imported Open Salamander
  settings into the probe's key (restored identical); the row now seeds a configuration first.
- **result_after.txt: PASS 28, FAIL 0** (BASIC, AGAIN, BOTH, FRESH, KILL x2, FAIL-copy/compare/rename
  x2 each, CORRUPT, IMP-LEGACY, IMP-FOREIGN + END rows); registry restored identical.
  The whole 0.1 tree (1,994 dump lines incl. Password Manager) equals Settings value by value; no
  window at the first start after the move (no import offer - FR-012).
- **result_before.txt (negative control, pre-change build): BASIC MOVE FAIL, IMP-LEGACY FAIL** -
  the old build makes no Settings and imports under 0.1, as expected.
- Deviation from T009: the feature-263 checks keep their literal `0.1` root - they test the rule
  with a root given as an argument, and `0.1` is still a real root (the mapping source); the new
  root is covered by `TestCfgRoot343`.
