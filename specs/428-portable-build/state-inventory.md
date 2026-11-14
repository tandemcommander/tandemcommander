# State inventory: what the program stores outside its own folder

Measured on `main` at `ce4bab86` (2026-11-14) by a read-only sweep of `src/` and `src/plugins/`.
This is the input to the clarify and plan phases of feature 428 (portable build), not a design.
Each row says what is stored, where (file:line at the time of the sweep), and whether a portable
build has to redirect it (**R**), skip it (**S**), or may leave it (**OK**: read-only or transient).

## 1. Registry

### Core configuration root

| What | Where | Portable |
|------|-------|----------|
| Root `HKCU\Software\Tandem Commander\Settings` (`SalamanderConfigurationRoots[0]`), `SALCFG_LEGACY_ROOT` (`…\0.1`), `SALAMANDER_ROOT_REG` | `mainwnd2.cpp:163`, `:174`, `:176`; set `salamdr1.cpp:4485`, `:4828` | R |
| Start-up chain: `MigrateConfigurationRoot` (343), `GetUpgradeInfo` / `AutoImportConfig`, `FindLatestConfiguration`, `DeleteOldConfigurations` | `salamdr1.cpp:4214`; `mainwnd2.cpp:1204`, `:702`, `:1418`, `:1633` | S |
| Early readers before the main load: language key, `CheckOnlyOneInstance` | `salamdr1.cpp:4239`, `:4412`; `salamdr2.cpp:2201` | R |
| Save / load of the configuration (~70 literal `HKEY_CURRENT_USER` sites in the core; most in `mainwnd2.cpp`, `plugins1.cpp`, `mainwnd3.cpp`) | `mainwnd2.cpp:1755-1781`, `:2963` | R |
| Crash-time backup key `<root>.backup.63A7CD13` (sibling of `Settings`), written at a critical end of session, restored at start | `mainwnd3.cpp:7573-7605`; `mainwnd2.cpp:1444` | R |
| Icon-overlay crash handler writes configuration values | `callstk.cpp:623` | R |
| Update state `<root>\Update Check` (123, 420-422) | `updcheck.cpp:19`, `:45-75`; `updinstall.cpp:105-206` | R (or S, depending on the update decision) |
| Password manager: master-password verifier in the root; no DPAPI / Credential Manager anywhere | `pwdmngr.cpp:960-990` | R (portable across machines as is) |

### Plug-in configuration

- Interface `CSalamanderRegistryAbstract` (`plugins/shared/spl_base.h:204`), `LoadConfiguration` /
  `SaveConfiguration(HWND, HKEY regKey, registry)` (`:535` / `:542`). The core implementation is a
  thin wrapper of the real registry (`plugins1.cpp:1574-1626`); keys are
  `<root>\Plugins Configuration\<RegKeyName>` (`plugins1.cpp:2461`, `2941-2968`, `3051-3110`).
- **Plug-ins receive real `HKEY` handles** and some use them with other functions (FTP
  `ftp/ftp.cpp:1469`, nethood via `SalRegQueryValueEx`; automation, off, `RegSetValueExW`
  directly in `automation/persistence.cpp:312`). The plug-in ABI is append-only (constitution V,
  CLAUDE.md), so the portable store must keep handing plug-ins something they can use exactly as
  today — a constraint for the plan.
- `reglib` already has an in-memory registry (`reglib/src/reginmem.cpp:1171`), the system one
  (`registry.cpp:464`), a `.reg` parser and dumper — used today by export / import.

### Plug-ins that open other keys

| Plug-in (default on unless noted) | What | Portable |
|-----------------------------------|------|----------|
| mdview | reads `HKCU\…\Themes\Personalize` (`mdview/viewer.cpp:477`) | OK |
| pictview *Set as wallpaper* | writes `HKCU\Control Panel\Desktop` `Wallpaper*` (the user's explicit request) and its own `PrevWallpaper*` backup values (`pictview/render2.cpp:545`, `581-612`) | the backup values: R; the wallpaper itself: a decision |
| regedt | a registry editor — touching the registry is its purpose; its own settings go through its plug-in key | OK (user's own actions) |
| sftp | bookmarks and the trust-on-first-use host-key store in its plug-in key (`sftp/hostkeys.h:7`, `sftp/sftp.cpp:577`, `612`, `661`) | R (follows the root) |
| nethood (off), automation (off), zip SFX stub (runs on the target machine of an SFX, not in the program) | read HKLM / HKCR; RunOnce in the SFX | OK |

### Core writes outside the root

| What | Where | Portable |
|------|-------|----------|
| **Shell extension registration at every start** when `utils\salext*.dll` exists: HKCR `CLSID\{…}` + `InProcServer32` (fallback `HKCU\Software\Classes`), `directory\shellex\CopyHookHandlers\TandemCommanderVer…`, HKLM `Shell Extensions\Approved` | `salamdr1.cpp:4636-4662` → `shexreg.c:451`, `:520-560`, `:562`, `:573` | S (or opt-in) |
| Icon-cache refresh: temporarily changes `HKCU\Control Panel\Desktop\WindowMetrics\Shell Icon Size` and restores it | `mainwnd3.cpp:1615` | a decision (transient write) |
| Restart Manager `RegisterApplicationRestart` (held by the OS; command line `-t` / `-i`) | `mainwnd3.cpp:604-625`, `salcloseapp.h:108` | OK (OS-held) |
| Jump list (`ICustomDestinationList`; the shell stores it in `%APPDATA%\Microsoft\Windows\Recent\CustomDestinations`) | `jumplist.cpp:295` | a decision (OS-managed) |
| Read-only probes: HKCR FileExts, network / OneDrive / WSL, policies, HKLM probes | `icncache.cpp:1173-1345`, `drivelst.cpp:156-2370`, `salamdr5.cpp:1491`, … | OK |
| Not present: file associations, "Open with", autorun, App Paths, WER, uninstall writes (the installer has no `[Registry]` section) | — | — |

## 2. Files outside the program folder

| What | Where | Path today | Portable |
|------|-------|------------|----------|
| WebView2 user data folder (codeview, mdview; binding contract `architecture/11`) | `common/webhost/webhost.cpp:124-136`; `codeview/viewer.cpp:1166`, `mdview/viewer.cpp:1112`, `webkeeper.cpp:211` | `%LOCALAPPDATA%\Tandem Commander\WebView2` | R |
| Clean-up of the old mdview folder | `mdview/webglue.cpp:216` | `…\mdview.WebView2` | S |
| Bug reports (text; no minidumps) | `callstk.cpp:805-850` | `%LOCALAPPDATA%\Tandem Commander\*.TXT` | R |
| Update downloads and run log | `updinstall.cpp:360-380`, `:758` | `%LOCALAPPDATA%\Tandem Commander\Updates` | S (if no self-update) |
| PictView wallpaper bitmap | `pictview/render2.cpp:483-499` | `%LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp` | R (or a decision) |
| `config.reg` fallback and the default folder of *Export Configuration* | `salamdr5.cpp:1992-2025`; `salamdr1.cpp:3825`; `mainwnd3.cpp:3661` | `%APPDATA%\Tandem Commander` | R |
| Backups before a settings import (245) | `cfgimport.cpp:1027-1045` | `%APPDATA%\Tandem Commander\Settings backups\before-import-*.reg` | R |
| Disk cache (archive / plug-in FS extraction), list files, 7za temp | `cache.cpp:1198-1235`, `:1519-1551`; `pack1.cpp:447`, `pack2.cpp:243`, `:649`, `zip/common.cpp:116`, `undelete/fs2.cpp:1529` | `%TEMP%` | OK (transient) |
| Debug trace (`TRACE_TO_FILE` only) | `common/trace.cpp:441` | `%TEMP%\altap_traces*` | Debug only |

History, hot paths, FTP / SFTP bookmarks and the plug-in icon cache (`plugins2.cpp:146`) all live
in the registry root. `plugins.ver` is next to the exe (`plugins2.cpp:2899`). No thumbnail disk
cache.

## 3. Shell extension (`src/shellext/`)

A copy-hook COM DLL. **Dragging or copying to the clipboard from archives and plug-in file systems
to Explorer requires it** (`SalShExtRegistered`; without it the action silently does nothing,
`shellsup.cpp:1350-1372`, `1414`, `1723`). Drops and pastes *into* the program and ordinary disk
drag and drop do not depend on it. To check in the plan: whether the current Release tree ships
`utils\salext*.dll` at all (the local `build\…\Release_x64\utils` had none at the sweep).

## 4. Existing configuration files

- **Upstream semi-portable start-up import**: `ConfigurationName` defaults to `<exe>\config.reg`,
  else `%APPDATA%\Tandem Commander\config.reg` (`salamdr1.cpp:3821-3830`); imported at every
  start (`salamdr1.cpp:4461`, body `salamdr2.cpp:3083`), limited to keys under the root, 0.1 keys
  mapped (`common/salregroot.h`, 263). Command-line `-c <file>` picks that file
  (`salamdr1.cpp:3912-3937`). It *imports into the registry*; it is not a registry-free mode.
- *Export Configuration* (`CM_EXPORTCONFIG`, `mainwnd3.cpp:3634+`, default `config_.reg`) →
  `ExportConfiguration` (`salamdr2.cpp:3039`, reglib `CopyBranch` + `DumpToBuffer`).
- Feature 245 import from Altap / Open Salamander reads their keys read-only
  (`common/salcfgimport.h:372+`) and writes into the root (`cfgimport.cpp:3203-3211`); offered once
  on a fresh configuration (`salamdr1.cpp:4917`, `mainwnd3.cpp:2673`) and in the menu
  (`mainwnd3.cpp:3721`).

## 5. New-version check and self-update (123, 420-422)

- Check: one HTTPS GET to `api.github.com/repos/tandemcommander/tandemcommander/releases/latest`
  (`common/salupdcheck.h:43`, `updcheck.cpp:450-591`); the release page opens in the browser
  (`upddlg.cpp:89`). The answer must name the installer asset
  `tandemcommander-<ver>-x64-setup.exe`, otherwise the release is not offered.
- Download and install only when `UpdInstall_IsEligible` (`updinstall.cpp:280-326`): the
  uninstall entry `{35C0B0DC-…}_is1` whose `InstallLocation` is the program's folder. **A copy
  without that entry is already notify-only** (420: "portable copy, build tree"), and 421's window
  says it cannot update itself.

## 6. Identity surfaces

- Main window title: `CMainWindow::SetWindowTitle` (`mainwnd1.cpp:1962`) — `[prefix - ][path - ]`
  + `MAINWINDOW_NAME` + `" " VERSINFO_VERSION` + `" (Administrator)"` (`~2006-2009`); the tray tip
  reuses it.
- About and splash: `SALAMANDER_TEXT_VERSION` (`mainwnd1.cpp:28`), `CAboutDialog::DialogProc`
  (`logo.cpp:596-608`), splash `logo.cpp:252`; artwork `IDB_ABOUT_GRAD` (`res\gradabt.svg`,
  `res\logo.png`).
- Icon `IDI_SALAMANDER` → `res\salamand.ico` (`salamand.rc2:19`), one variant in `MainWindowIcons`
  (`dialogs5.cpp:2786`). Brand assets: `tools/brand/README.md`.

## 7. Build and release facts

- Output tree `%OPENSAL_BUILD_DIR%tandemcommander\<Config>_x64`; the installer packages
  `Release_x64\*` without `*.pdb,*.lib,*.exp` (`setup/tandemcommander.iss:106-110`).
- The Visual C++ runtime is already copied next to the program in Release (077) — a portable copy
  needs no redistributable.
- `build.cmd` arguments are order-independent flags (`rebuild`, `release`, `full`, `sign`,
  `setup`); `sign` and `setup` require `release`.
- A release publishes one asset (the installer); winget uses it (`tools/winget/`).
