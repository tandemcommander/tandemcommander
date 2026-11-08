# Tasks: Automatic update - download the new installer in the background and install it

**Input**: `specs/420-auto-update-install/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: requested by the spec (saltests for the pure rules, hidden-desktop probe, end-to-end run).

## Phase 1: Setup

- [ ] T001 Add `wintrust.lib`, `crypt32.lib`, `bcrypt.lib`, `version.lib` to the core link and `wintrust.dll`, `bcrypt.dll`, `version.dll` to the delay loads in `src/vcxproj/sal_base.props`; add `updinstall.cpp`, `updinstall.h`, `updhttp.h`, `common/salupdinstall.h` to `src/vcxproj/salamand.vcxproj` and `.filters`
- [ ] T002 [P] Write `tools/check_update_pin.py` (pin in `src/common/salupdinstall.h` == thumbprint of `tools/codesign/codesign.cfg`, `--help`, exit 1 on mismatch) and run it from `build.cmd` next to the encoding guard

## Phase 2: Foundational (blocks every story)

- [ ] T003 Extend the release record in `src/common/salupdcheck.h`: `ReadUnsigned` in the JSON reader; `SalUpdReadAsset` collects `id`, `size`, `digest`, `url` of the installer asset into `CSalUpdRelease` (`HasAsset`, `AssetId`, `AssetSize`, `HasDigest`, `Digest`), each at most once, `url` == constructed API address; 123's acceptance unchanged
- [ ] T004 Write `src/common/salupdinstall.h` (pure): limits, `SalUpdAssetApiUrl/Path`, `SalUpdParseDigest`, `SalUpdRedirectAllowed`, signer pin + compare, `SalUpdTrimResourceString` + `SalUpdInstallerVersionOk`, levels + `SalUpdLevelFromStored`, `SalUpdAfterCheck`, `SalUpdBuildInstallerArgs`, arm structure, `SalUpdArmHonoured`, `SalUpdStartupArmDecision`, `SalUpdExitDecision`, installer / part / log file names
- [ ] T005 saltests for T003 and T004 in `src/saltests/saltests.cpp` (records with / without / duplicated / malformed asset members, every allow-list case, digest forms, version strings with padding, argument strings of both kinds and modes, every row of the start-up and exit tables)
- [ ] T006 Write `src/updhttp.h` (async WinHTTP helpers: `CUpdAsync`, status callback, await with cancel event and deadline) and switch `src/updcheck.cpp` to it without behaviour change
- [ ] T007 Write `src/updinstall.h/.cpp` base: updates folder, level read / write, arm read / write / drop (`Update Check` key via updcheck's key helpers exported), installation lookup (HKLM 64-bit, HKCU, `InstallLocation` vs module folder; Debug seam `TC_UPDATE_PROBE_UNINSTALL`), metered (`INetworkCostManager`; seam `TC_UPDATE_PROBE_METERED`)
- [ ] T008 Verification in `src/updinstall.cpp` (`UpdInstall_VerifyInstaller`: handle without write / delete sharing, SHA-256, `WinVerifyTrust`, thumbprint, version resource; failure deletes the file)
- [ ] T009 Launch in `src/updinstall.cpp` (`UpdInstall_Launch(kind)`: arguments, launches + 1, `CreateProcessW`, watcher thread for *now*, seams `TC_UPDATE_PROBE_RUNLOG`, `TC_UPDATE_PROBE_NORESTART`)
- [ ] T010 Download worker in `src/updinstall.cpp` (contract D2/D3: API address, redirect allow-list, `.part`, hash, size, rename, verification, cancel at exit, `WM_USER_UPDATEDOWNLOAD_DONE`; Debug seam: loopback when `TC_UPDATECHECK_URL` is set)
- [ ] T011 Messages `WM_USER_UPDATEDOWNLOAD_DONE`, `WM_USER_UPDATEINSTALL`, `WM_USER_UPDATEINSTALL_DONE` in `src/consts.h`; strings `IDS_UPDATE_*` (levels, buttons, hints, test mode, failures) in free slots of existing bundles in `src/texts.rh2` + `src/lang/texts.rc2`

## Phase 3: User Story 1 - download and offer (P1)

- [ ] T012 [US1] Notification forms in `src/upddlg.cpp/.h` and `IDD_UPDATENOTICE` (`src/lang/lang.rc`, `lang.rh`): fourth button `IDC_UPDN_INSTALLEXIT`, run-time texts and layout of the visible buttons, hint per form, Install Now / Install When I Close / Skip behaviour, replacement of another form
- [ ] T013 [US1] `src/mainwnd3.cpp`: after a check (automatic and manual) apply `SalUpdAfterCheck`; reuse a verified installer or start the download; on `WM_USER_UPDATEDOWNLOAD_DONE` show the offer / classic form; on `WM_USER_UPDATEINSTALL_DONE` report a failed *Install Now*; shutdown cancels the download

## Phase 4: User Story 2 - automatic at exit, completed at the next start (P1)

- [ ] T014 [US2] Arm on download completion at level 2 and show the automatic form (`src/mainwnd3.cpp`)
- [ ] T015 [US2] `UpdInstall_PrepareExit` after the message loop and `UpdInstall_RunAtExit` as the last statement of `WinMainBody` in `src/salamdr1.cpp` (normal exit, last instance in the session, honoured arm, verified, launches < 3)
- [ ] T016 [US2] `UpdInstall_OnStartupComplete` in `src/salamdr1.cpp` / `src/updinstall.cpp`: leftovers cleanup, start-up decision, `WM_USER_UPDATEINSTALL` -> *Install Now* route in `src/mainwnd3.cpp`

## Phase 5: User Story 3 - the setting (P1)

- [ ] T017 [US3] `IDD_CFGPAGE_GENERAL` (`src/lang/lang.rc`, `lang.rh`): label + drop-down list; `CCfgPageGeneral` in `src/dialogs4.cpp` (`cfgdlg.h`): fill, enable with the check box, write on change, drop an automatic arm when lowered or when the check is cleared

## Phase 6: User Story 4 - never run a foreign file (P1)

- [ ] T018 [US4] Re-verification before every launch (Install Now, exit, start-up) and the deletion of failed files - covered by T008/T009/T015/T016; probe group V (T022)

## Phase 7: User Story 5 - test mode (P2)

- [ ] T019 [US5] `--updatetest` in `ParseCommandLineParameters` (`src/salamdr1.cpp`); `UpdateTestMode` in `src/updcheck.cpp/.h`: forced start-up check, no claim, no stored state, forced newer, skip ignored; trace line
- [ ] T020 [US5] Test-mode lines: notification (`IDS_UPDATE_TESTMODE`) in `src/upddlg.cpp`, About (`IDS_UPDATE_ABOUT_TESTMODE`) in `src/logo.cpp`

## Phase 8: User Story 6 - copies that cannot update (P3)

- [ ] T021 [US6] Not eligible / metered -> classic form (covered by T007 + T013); probe rows L-ineligible, L-metered

## Phase 9: Verification

- [ ] T022 Probe `specs/420-auto-update-install/probe/autoupd_probe.ps1` + fixture server `updserver420.py` (groups L, V, B, X, S, T of quickstart §2; X also measures the exit time while a slow download runs (SC-006), T also checks that the restart registration carries no `--updatetest` (FR-016)), registry backup / restore; run before (HEAD of main: no download) and after
- [ ] T023 End-to-end probe `specs/420-auto-update-install/probe/e2e_peruser.ps1` (quickstart §3): at-exit install and completion at the next start with the real published installer over a per-user test installation; uninstall afterwards
- [ ] T024 Release build string search: the Debug seams `TC_UPDATE_PROBE_*` absent from the Release `tandemcommander.exe`

## Phase 10: Polish

- [ ] T025 [P] `PRIVACY.md`: summary, *New version check* (stored values), *Checking for a new version* (download, hosts, test mode not mentioned), *Installing and uninstalling*, files under `%LOCALAPPDATA%`, *Removing your data*; validity line
- [ ] T026 [P] `help/src/hh/salamand/configuration_gener.htm`: the new option; `architecture/12-project-reference.md`: `--updatetest` and the feature's facts
- [ ] T027 Translations: two-stage `.slt` refresh of module `salamand` (stop-rules §2.13), pins, `slt --verify`, `build.cmd full`
- [ ] T028 Encoding guard, build, saltests; fix-log; review (SKILL step 7); closing (step 8)

## Dependencies

Setup -> Foundational (T003-T011) -> US1 (T012-T013) -> US2 (T014-T016) and US3 (T017) -> US5 (T019-T020) -> Verification (T022-T024) -> Polish. US4 and US6 are properties of the foundational code checked by the probe.

## Parallel opportunities

T002 with T003-T005; T025 and T026 with the probes; T005 with T006.

## Implementation strategy

One feature, one run: foundations with tests first, then the default path (US1), the automatic path with its start-up completion (US2), the setting (US3), test mode (US5), then the probes prove US1-US6 together.
