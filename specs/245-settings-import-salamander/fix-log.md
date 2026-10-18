# Fix log — feature 245 (import settings from Altap Salamander / Open Salamander)

## 2026-10-18 — specify

- Branch `245-settings-import-salamander` created from `main` at `869d9690`.
- Read-only analysis (three parallel research passes + own checks) recorded in
  `analysis.md`: core configuration inventory, plugin configuration and
  passwords, shortcuts / toolbars / associations / identity documents.
- Measured on the maintainer's machine (read-only): Altap Salamander 4.0
  (config 103) is the only genuine foreign source; `Open Salamander\5.0`
  (105) and `Newt Commander\0.1` (105) were written by fork development
  builds.
- Verified by hand: the Keyboard page states that TC command shortcuts are
  fixed (`src/lang/lang.rc:1217`); the startup `config.reg` import writes
  every key of a foreign `.reg` after one question (`src/salamdr2.cpp:3017-3060`).
- Prior work found: feature 057's standalone script and its research; this
  feature reuses its decisions and adds an in-app, translated wizard with an
  *Add* mode.
- `spec.md` written; 2 clarification questions open (FR-002, FR-032).

## 2026-10-18 — clarify

- Q1 → B: Options menu + a one-time offer at the first start of a fresh
  configuration (existence check only) — FR-002, FR-005, FR-031, edge cases,
  constitution note.
- Q2 → A: the 057 script and its tests are retired — FR-032.
- Q3 → A: append-only plugin import call, interface 108, FTP merges its own
  connections — FR-021a, FR-021b, Assumptions.

## 2026-10-18 — implement (phase 1-3, first e2e)

- Baseline before any change: Debug build green, `saltests` 23 037 checks / 0 failed.
- `src/common/salcfgimport.h` + `TestCfgImport245` (436 checks): all green after four
  wrong expectations in the test itself were corrected (character-boundary fit, the
  default-dir length limit, a hot path that does fit).
- Engine `src/cfgimport.cpp`, wizard `src/cfgimpdlg.cpp`, interface 108 (`spl_base.h`,
  `spl_vers.h`, entry object in `plugins.h`/`plugins1.cpp`), FTP handler
  `src/plugins/ftp/ftpimport.cpp`; the `WM_USER_CONFIGURATION` refresh factored into
  `CMainWindow::RefreshAfterConfiguration` (behaviour unchanged).
- Found while building: the FTP loader validates a bookmark's proxy UID against the CURRENT
  proxy list and `LoadPassword` reads the registry directly (not through the registry
  object) - the handler therefore reads the raw proxy UID and the password blobs itself.
- e2e matrix (`probe/ci245_e2e.ps1`, Debug seam) - defects it found and that were fixed:
  1. Add mode replaced a plug-in command's DEFAULT shortcut (it only kept user-assigned
     ones) -> a default import needed consent, against FR-010c. Add now never changes a
     current shortcut.
  2. `CPasswordManager::AskForMasterPassword` always shows its dialog, even when the master
     password is entered: the import asked again. It now asks only when not entered.
  3. Probe library: `reg import` writes its success text to stderr (PS 5.1 then throws) -
     both reg calls go through `cmd /c`. The registry had been restored correctly anyway
     (export compared byte for byte).
- Run 1 of the full matrix: 61 checks, 0 failed (`probe/result_e2e_run1.txt`).
