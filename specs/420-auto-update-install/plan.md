# Implementation Plan: Automatic update - download the new installer in the background and install it

**Branch**: `420-auto-update-install` | **Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/420-auto-update-install/spec.md`

## Summary

After feature 123's check finds a newer release, the program downloads that release's installer
(GitHub API asset address, redirect only to GitHub's release download hosts), proves it is the
published file (SHA-256 of the release record), signed by the project (Authenticode + pinned
thumbprint) and of the announced version (version resource), and then - by a three-level setting
on Configuration > General - offers *Install Now* / *Install When I Close*, or arms it for the
exit. The installer runs in the install mode of the running installation (uninstall entry in HKLM
or HKCU), silently at the end of a normal exit of the last instance, or with a progress window and
the update close of 080 (*Install Now*, and the completion at the next start of an armed update the
exit did not install). `--updatetest` repeats the whole process on the installed version.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143, pure WinAPI
**Primary Dependencies**: WinHTTP (asynchronous, delay-loaded, as 123), WinTrust + Crypt32 (Authenticode, signer thumbprint), BCrypt (SHA-256), Version API (installer's version resource), Network List Manager `INetworkCostManager` (metered), Toolhelp (other instances), Shell `ShellExecuteExW` (starting the installer, elevation for all-users installs)
**Storage**: registry `HKCU\<root>\Update Check` (123's key: new values, contract `contracts/stored-state.md`); files in `%LOCALAPPDATA%\Tandem Commander\Updates`
**Testing**: `saltests` (pure rules in `src/common/salupdinstall.h` and the extended release parser of `salupdcheck.h`); hidden-desktop probe with a loopback fixture server (Debug seams); an end-to-end run with the real published installer over a per-user test installation
**Target Platform**: Windows 10/11 x64
**Project Type**: desktop application (core module `salamand`)
**Performance Goals**: exit never waits for the network longer than 123's bound (1.5 s for the workers); verification of an 8 MB installer < 1 s
**Constraints**: never run a file not proven ours; never install on a sign-out / shutdown / installer close; never close other running instances at an exit; `setup/tandemcommander.iss` unchanged; plug-in ABI unchanged
**Scale/Scope**: one installer per release (~8 MB, limit 64 MB)

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | new system libraries only (`wintrust`, `crypt32`, `bcrypt`, `version`), vendored nothing; `build.cmd` unchanged | PASS |
| II. Backward compatibility | 123's stored values unchanged; a new level value absent = default; the release parser accepts records without the new members (123 behaviour kept); restart command line unchanged | PASS |
| III. Incremental modernization | pure rules in a header with tests; Windows parts in one new file next to 123's | PASS |
| IV. Windows commitment | WinAPI only | PASS |
| V. Plugin architecture | no plug-in interface change | PASS |
| VI. UI consistency | the existing notification and General page are extended; strings translated for the enabled languages; dark theme follows the existing notice code | PASS |

Re-check after design: unchanged (PASS).

## Project Structure

### Documentation (this feature)

```text
specs/420-auto-update-install/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/ (stored-state.md, download-source.md, verification.md, installer-launch.md, ui.md)
├── fix-log.md, closing-report.md
└── probe/ (autoupd_probe.ps1, updserver420.py, e2e_peruser.ps1, results)
```

### Source Code

```text
src/common/salupdcheck.h     # release record: asset id, size, digest, API url of the installer asset
src/common/salupdinstall.h   # NEW, pure: levels, asset address, redirect allow-list, digest, thumbprint pin,
                             #   version-resource rule, installer arguments, arm / start-up / exit decisions
src/updhttp.h                # NEW: WinHTTP async helpers shared by the check and the download
src/updcheck.cpp/.h          # test mode; uses updhttp.h
src/updinstall.cpp/.h        # NEW: level + arm state, installation lookup, metered, download worker,
                             #   verification, launching, start-up completion, exit hook
src/upddlg.cpp/.h            # notification variants (classic / offer / automatic), Install buttons, test mode line
src/dialogs4.cpp             # General page: level combo box
src/logo.cpp                 # About line in test mode
src/mainwnd3.cpp             # check done -> download / offer; download done; install messages; start-up
src/salamdr1.cpp             # --updatetest; start-up completion; installer start at the end of a normal exit
src/consts.h, src/texts.rh2, src/lang/texts.rc2, src/lang/lang.rc, src/lang/lang.rh
src/vcxproj/sal_base.props, salamand.vcxproj(.filters)   # libraries, delay loads, new files
src/saltests/saltests.cpp
PRIVACY.md, CHANGELOG.md, help/src/hh/salamand/configuration_gener.htm, architecture/12-project-reference.md
translations/*/salamand.slt (+ .origin), translations/ui-overrides.json
```

**Structure Decision**: the feature lives next to feature 123 in the core; pure rules in a new
header under `src/common/` (saltests), Windows parts in one new file `updinstall.cpp`.

## Design

### Flow

1. **Check done** (`CMainWindow::OnUpdateCheckDone`, and the manual paths): result newer and not
   skipped (test mode: always newer, skip ignored) -> `SalUpdAfterCheck(level, eligible, metered,
   record has asset+digest+size<=64 MB)`:
   - `notify` -> 123's notification (classic);
   - `download` -> a verified installer of that version already in the updates folder? offer it now;
     otherwise start the download worker; a manual check also shows the classic notification at once.
2. **Download worker** (thread, WinHTTP async, cancellable like 123): GET the API asset address
   (`Accept: application/octet-stream`, no redirects followed automatically); a 3xx with `Location`
   passing `SalUpdRedirectAllowed` is followed (max 3 hops; each hop a new connection with the same
   restrictions); a 200 body is streamed into `<name>.part` (size limit = record size), hashed; on
   completion and digest match the `.part` is renamed; then full verification; result posted
   `WM_USER_UPDATEDOWNLOAD_DONE`.
3. **Download done** (main thread): ok -> level offer: notification *offer*; level automatic: arm
   (source automatic) + notification *automatic* (non-activating as 123); failed -> classic
   notification (unless already shown).
4. **Install Now** (notification button, and start-up completion): re-verify, record the launch in
   the arm state (source user, launches + 1), start the installer (`installer-launch.md`, kind *now*)
   with `ShellExecuteExW` (elevation prompt for all-users), watch the process on a thread; the 080
   update close ends the program; if the installer ends while we still run with a non-zero code ->
   message, arm stays.
5. **Install When I Close**: arm (source user).
6. **Exit**: `UpdInstall_PrepareExit()` right after the message loop decides (normal exit, last
   instance in this session, arm honoured, re-verified) and keeps the installer file open
   (read-only share) - `UpdInstall_RunAtExit()` as the last statement of `WinMainBody` starts it
   (kind *exit*) and records the launch.
7. **Start-up** (`UpdInstall_OnStartupComplete`, after 123's): delete `.part` leftovers and installers
   not newer than the running version (test mode keeps none); decide the arm
   (`SalUpdStartupArmDecision`): clean up / drop / complete now (post `WM_USER_UPDATEINSTALL`).

### Test mode

`ParseCommandLineParameters` accepts `--updatetest` (sets `UpdateTestMode`); `CCommandLineParams`
(shared between instances) is not changed. 123: start-up check forced, no claim, no stored state,
`SalUpdClassify` -> newer; notification / About show the test line; arms made in test mode carry
`Install Test` = 1 (`SalUpdStartupArmDecision` drops them outside test mode, completes only
never-launched ones in test mode).

### Debug-only seams (absent from Release, checked by string search)

`TC_UPDATECHECK_URL` (123) also redirects the asset download to the loopback fixture (plain HTTP,
redirect target must be the same loopback server); `TC_UPDATE_PROBE_UNINSTALL` = a key under HKCU
read instead of the uninstall keys (`ALLUSERS:` / `CURRENTUSER:` prefix selects the mode the
probe pretends); `TC_UPDATE_PROBE_RUNLOG` = a file that receives the installer path + arguments
instead of starting it; `TC_UPDATE_PROBE_NORESTART` = `/NORESTARTAPPLICATIONS` instead of
`/RESTARTAPPLICATIONS` (end-to-end probe on the hidden desktop: a restart would appear on the
visible desktop); `TC_UPDATE_PROBE_METERED` = 1 pretends a metered connection.

## Complexity Tracking

None.
