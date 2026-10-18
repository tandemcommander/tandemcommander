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
- Colours, highlighting, view templates, saved searches, ignore list added; e2e S12 green.
- UI probe (`probe/ci245_ui.ps1`, hidden desktop): U1-U3 green (24 checks). Found: the
  first-start offer never appeared - `SALAMANDER_ROOT_REG` is NULL for a fresh
  configuration; start-up now uses `currentCfgDoesNotExist`. U4/U5 (the offer) need the
  translated `.slg` (a fresh start picks the system language) - owed to T048.

## 2026-10-18 — refute-first reviews, round 1 (three independent agents)

Plugin API / FTP (9 confirmed, 6 plausible), engine (14 confirmed, 5 plausible), wizard
UI and start-up (11 confirmed, 9 plausible). Dispositions are recorded per finding below
as they are fixed (F = FTP/API, E = engine, U = UI).

**FTP / interface 108**
- F1 fixed: Replace keeps the UID of a current identical proxy, new UIDs continue after
  the current ones; a removed default proxy resets `DefaultProxySrvUID` (reported).
- F2 fixed: the three new lists are complete copies, swapped in by `ImportSwap` (no
  allocation); nothing is cleared before the copy exists.
- F3 fixed: no `__try` any more; the handler is called between `EnterPlugin`/`LeavePlugin`
  (F13) - a crash is the program's crash, never a half state that `SaveConfig` stores.
- F4 fixed: the program's master password is asked before the preview
  (`PrepareTCMasterPassword`); `DecryptSourcePassword` answers the same in both runs and
  `EncryptForStorage` never asks.
- F5 fixed: Replace reports a current item it overwrites as REPLACED (consent); a source
  duplicate is PRESENT.
- F6 fixed: server types compared by definition; Add keeps a same-name current type
  (SKIPPED with the reason), Replace replaces it in place; a source type that does not
  load is reported by its number.
- F7 fixed: the source master password is used with at most 127 bytes; `AESInit` failing
  returns FALSE (both foreign functions).
- F8 fixed: one line per item naming every reason.
- F9 fixed: the first source proxy of a UID wins; UIDs < 1 never mapped.
- F10 fixed: a bookmark's (re-mapped) proxy is part of its identity.
- F11 no change: the snapshot view's handles are heap pointers; `SalRegQueryValueEx` on
  one fails with an invalid handle and the handler reads the blobs itself.
- F12 fixed in the wizard (U4).
- F14 no change: tens of handles per run, linear search is fine.
- F15 fixed: one password per item (E before S), an empty scrambled one not counted.

**Engine**
- E1 fixed: a viewer/editor row inserted before the current catch-all is REPLACED (consent).
- E2 fixed: option + companion taken over as one unit (Recycle Bin masks, compare
  ignore masks, title prefix text, viewer text masks; hex masks validated).
- E3 fixed: the program check runs only on local fixed drives (no UNC, no mapped drive).
- E4 fixed: `PlanFailed` per group - never applied, the preview shows the reason; menu
  copies counted only when complete.
- E5 fixed: whole-plugin settings written to a side key and renamed in; a truncated source
  subtree is refused (also FTP); truncation tracked per key.
- E6 fixed: the default (unnamed) value is read.
- E7 fixed: missing highlighting colours = default; inactive focus backgrounds fall back as
  the program's loader does.
- E8 fixed: Add keeps a shortcut the user removed.
- E9 fixed: a too-long entry is left out alone (a submenu with its content), counted once.
- E10 fixed: Keep Plugins Sorted removed from the table (mirror check updated, 112 entries).
- E11 fixed: a plugin whose archive/FS is open is refused before unloading.
- E12 fixed: the whole-plugin preview lists changed values (60 lines + a count), consent.
- E13 reconciled: FR-011 note + R5 (Replace = the imported key wins a conflict).
- E14 fixed: report text cut only at whole characters (`SalCfgImpCopyText`,
  `SalCfgImpFormatText`, saltests).
- E15 fixed: the import is refused while Find or viewer windows are open.
- E16 fixed: SFTP is not offered as whole-plugin settings.
- E17 no change: the backup is the stored configuration (what `-C` restores); documented.
- E18 fixed: a blank (unused) source template is not imported.
- E19 no change: existence checks of paths would reach the network (FR-030).

**Wizard / start-up**
- U1 fixed: every translated format with numbers takes only `%s` (numbers formatted first).
- U2 fixed with E4.  U3 fixed: the offer waits (timer) while the main window is busy.
- U4/U5 fixed: an emptied field forgets the stored password; Back keeps the choices; a
  verified password is shown again when the page returns.
- U6 fixed: Esc / close = "Not now"; buttons *Import now* / *Not now*.
- U7 fixed: named columns Settings | Items | Mode.  U8: unavailable rows grey (custom
  draw); the source list marks unsupported entries in text (contract updated).
- U9 fixed: temp file + `SalReplaceWithTempW`, 32k-char path buffer, translated filter
  and name.  U10 fixed: a task-list timeout counts as another instance.
- U11 no change: loading the plug-in for the preview is not a settings change.
- U12/U13 fixed: all pages 380x270, larger text areas.  U14 fixed: labels for the text
  fields, a mnemonic for the consent.  U15 fixed: the hint only with protected passwords.
- U16 fixed: the seam reads master passwords as code-page bytes.  U17: record aligned (R13).
- U18 fixed: a failed `LB_ADDSTRING` is skipped.  U19 fixed with E14.  U20: `fromOffer`
  is used in the call-stack text; kept.
- Build green; saltests 23 489 checks, 0 failed; encoding guard TOTAL 0.
- After round 1: e2e run 2 found the default import needing consent (viewer rows before
  `*.*` are changes) -> the viewers group is unticked by default (S1v added); S2 fixture got
  the Recycle Bin masks; S13 (FTP Replace/Add against a current FTP configuration) added;
  run 4: 90/90. UI probe 29/29 (U4/U5 with translations), Release UI probe 5/5.
- Translations: DeepL ran with `formality=prefer_less` (informal du/tu/je/tú against a formal
  corpus) -> `merge.py --formality prefer_more`; the rebrand step turned "Altap Salamander"
  into "Tandem Commander" in our texts -> `translations/brand-exempt.json` (+ the rebrand
  sweep honours it). Hungarian offer pinned (DeepL dropped `\n`).

## 2026-10-18 — refute-first reviews, round 2 (two agents: fixes, documents)

- Dialog captions (no own id) were still rebranded in 8 languages -> merge maps a caption to
  its dialog's IDD; the 40 rows restored.
- Plugin-in-use check now also covers an archive the plugin handles by association.
- An interrupted key swap: a lone `<key>.tc-import-old` is renamed back, never deleted.
- A whole-plugin group with nothing to change is not applied (no unload).
- A failed FTP apply clears its lines (the result does not list removals that did not happen).
- Opening the wizard cancels a deferred first-start offer.
- The oldest FTP password format ("Password" text) is counted.
- Replace of hot paths / user menu / plugin shortcuts refused for a list not read whole (S14).
- A long submenu-end text never unbalances the menu (saltests); grey rows answer
  `CDRF_NEWFONT`; "%s entries" string reworded (DeepL read %s as a name).
- Documents: the backup is now taken after saving (it includes this session's changes);
  PRIVACY names the older `Software\Salamander` key, the backups folder and *Import now*;
  help/contracts/research/quickstart/spec/CLAUDE.md/constitution aligned (password timing,
  viewers default, refusals, Replace for shortcuts, the 60-line plugin diff, interface 108).
- Trap: `merge.py` keeps an id's machine translation when its English changes - the three
  changed rows were removed from the `.slt` files so they were translated again.
- saltests 23 491 / 0.
