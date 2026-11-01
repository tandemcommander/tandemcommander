# Tasks: The Change Drive menu and the drive bar offer the WSL distributions

**Input**: `specs/374-wsl-drive-item/` (plan.md, spec.md, research.md, data-model.md, contracts/probe-seam.md, quickstart.md)

## Phase 1: Setup

- [X] T001 Record the before-state in specs/374-wsl-drive-item/fix-log.md (done at the start: measurement at 30268b7c)

## Phase 2: Foundational

- [X] T002 Create the pure rules header src/common/salwsl.h: `SalWslDistroUsableW`, `SalWslDistroPathU8`, `SalWslPathOnDistroU8`, `SalWslFingerprintAdd` / `SalWslFingerprintFold`, constants `SAL_WSL_NAME_MAX`, `SAL_WSL_SERVER_U8` (UTF-8-BOM, English comments)
- [X] T003 Add saltests checks for salwsl.h in src/saltests/saltests.cpp (usable names incl. reserved characters, control characters, `.`/`..`, over-long, a non-ASCII name kept whole; path built / refused when it does not fit; path-on-distro for `\\wsl.localhost\`, `\\wsl$\`, case, deeper folder, prefix-of-name negative, other server negative; fingerprint order-sensitive and stable)
- [X] T004 Append `drvtWSL`, `drvtWSLMenu` at the end of `CDriveTypeEnum` and add the `WslDistros` list member + `GetWslDistributions` declaration in src/drivelst.h
- [X] T005 Implement `GetWslDistributions` (registry read, State filter, UTF-8, sort, duplicates, Debug seam `TC_PROBE_WSL_LXSS`) in src/drivelst.cpp

## Phase 3: User Story 1 - the Change Drive menu (P1)

**Independent test**: Alt+F1 lists one `Linux - <name>` item per distribution; choosing one opens it.

- [X] T006 [US1] `BuildData`: add the WSL items after the cloud storages (icon from System32\wsl.exe, fallback Network icon; fingerprint into `CachedCloudStoragesMask`; probe lines `WSL` and `TIME`) in src/drivelst.cpp
- [X] T007 [US1] `ExecuteItem`: `drvtWSL` hands out a copy of the name in src/drivelst.cpp
- [X] T008 [US1] `CFilesWindow::ChangeDrive`: `drvtWSL` -> `SalWslDistroPathU8` + `ChangePathToDisk`, free the param; `drvtWSLMenu` unexpected in src/fileswn3.cpp
- [X] T009 [US1] Focus: a panel path on a distribution makes its item the `FocusIndex` (before the Network fallback) in src/drivelst.cpp `BuildData`
- [X] T010 [US1] `OnContextMenu`: no context menu for the two new types in src/drivelst.cpp

## Phase 4: User Story 2 - the drive bar (P2)

**Independent test**: the bar holds one WSL button; tooltip and action match the count.

- [X] T011 [US2] `BuildData` for the bar: one `drvtWSLMenu` item for several distributions in src/drivelst.cpp
- [X] T012 [US2] `ExecuteItem` `drvtWSLMenu`: re-read, track the drop-down menu, hand out the chosen name; nothing left -> `WM_USER_DRIVES_CHANGE` in src/drivelst.cpp
- [X] T013 [US2] `IncludeDriveInDriveBar`, `FillDriveBar` (no text; drop-down style), `GetDriveBarToolTip` (`Linux - <name>` / `Linux`), `FindPanelPathIndex` (WSL button for a WSL path) in src/drivelst.cpp
- [X] T014 [US2] `CDriveBar::Execute`: `drvtWSL` -> path change in the bar's panel; a single button when several exist posts the drive-bar refresh in src/toolbar6.cpp

## Phase 5: User Story 3 - the option and no WSL (P2)

**Independent test**: option off -> no item and no registry access; restart keeps it.

- [X] T015 [P] [US3] `ChangeDriveShowWSL` in src/cfgdlg.h, default TRUE in src/dialogs4.cpp, transfer in src/dialogs5.cpp
- [X] T016 [US3] Registry value `Change Drive Show WSL` saved and loaded in src/mainwnd2.cpp
- [X] T017 [US3] Checkbox `IDC_CHD_SHOWWSL` "&Linux Distributions (WSL)" on IDD_CFGPAGE_CHANGEDRIVE in src/lang/lang.rc (group box +13, controls below moved) and its id in src/lang/lang.rh
- [X] T018 [US3] String `IDS_WSLLINUX` 14169 "Linux" in src/texts.rh2 and src/lang/texts.rc2

## Phase 6: Polish & cross-cutting

- [X] T019 Build (`build.cmd`), saltests, encoding guard; fix findings
- [X] T020 Probe specs/374-wsl-drive-item/probe/wsl374_probe.ps1 (registry backup/restore; rows of quickstart.md) - run before (main build: no WSL rows) and after; a regression row: every existing item's type and text identical with the option on and off (FR-010)
- [X] T021 Two-stage `.slt` refresh of module `salamand` (stop-rules §2.13), `build.cmd full`
- [X] T022 Manual: mention the option / items on the Change Drive page of help/ if such a page exists
- [X] T023 fix-log.md complete (before/after, commands, translations)

## Dependencies

T002-T005 before all stories; US1 before US2 (shared BuildData code); US3 independent of US1/US2 except T006 reads the option (T015). T019-T023 last.

## Parallel examples

T015 and T017/T018 touch different files and can be done in parallel with T006-T010.

## Implementation strategy

MVP = US1 (menu items). Then the bar (US2) and the option (US3), then translations and the probe.
