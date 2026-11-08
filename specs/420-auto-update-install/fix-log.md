# Fix log - 420-auto-update-install

Backlog item `automatic-update-background-download` - *Automatic update: download the new installer
in the background and install it*. Run of `/tandem-backlog-implement`, started 2026-11-08 at
`main` = `824e8f58`.

## Maintainer requirements of the run (2026-11-08)

Given with the invocation, in addition to the item: implement in detail, analyse, design the best
solution and test it; a place in the settings to change the behaviour later (off / full automatic);
**check and prove that an update planned for the exit that was not performed at the exit is
completed at the next start**. Logged in the item's *Log*.

## Measurements before (at 824e8f58)

| # | What | Command / source | Result |
|---|---|---|---|
| M1 | Does anything download or run an installer? | read `src/upddlg.cpp` (IDOK = `UpdateCheck_OpenUrl` of the installer address), grep `WinVerifyTrust`, `BCrypt*`, `INetworkCostManager` in `src/` | no: the gap exists; no trust / hash / cost API used anywhere |
| M2 | Release record of v0.2.0 | `curl` of `api.github.com/.../releases/latest` | asset `tandemcommander-0.2.0-x64-setup.exe`, `state` uploaded, `size` 8,329,336, `digest` `sha256:3c56de19...e2b2`, `url` `.../releases/assets/675680428` |
| M3 | Digest = file? | `Get-FileHash setup/output/tandemcommander-0.2.0-x64-setup.exe` | `3C56DE19...E2B2` - equal |
| M4 | `browser_download_url` | curl, `Invoke-WebRequest`, `HttpClient` without redirects (also outside the sandbox), also for v0.1.9 | **HTTP 504** every time |
| M5 | API asset address | `HttpClient`, `Accept: application/octet-stream`, no auto redirect | **302** to `release-assets.githubusercontent.com` (947-character signed address); that address **200**, 8,329,336 bytes, `application/octet-stream` |
| M6 | Signature of the published installer | `Get-AuthenticodeSignature` | Valid; thumbprint `A3D05CCF5CA13EAFF49CC7F64D1832F0E6EF6733` = `tools/codesign/codesign.cfg`; `CN=Open Source Developer Pavel Stupka`, issuer `Certum Code Signing 2021 CA`, valid to 2027-03-08, timestamped |
| M7 | Version resource of the installer | `FileVersionInfo` | fixed file / product version **0.0.0.0**; strings: ProductVersion `0.2.0` and ProductName `Tandem Commander`, both **padded with spaces** (Inno Setup); 0.1.9 the same shape |
| M8 | Installations on this machine | uninstall keys of the AppId | HKLM (64-bit): `C:\Program Files\Tandem Commander\`, 0.2.0, Inno Setup 7.0.2; HKCU: none |
| M9 | Inno Setup semantics | `ISetup.chm` of Inno Setup 7 (extracted with 7-Zip) | silent setup closes **and restarts** applications unless `/NORESTARTAPPLICATIONS`; `/ALLUSERS`/`/CURRENTUSER` given => Setup does not ask; exit codes 0 ok, 5 abort, 7/8 preparing failed; 080 measured: a declined Restart Manager close => exit 5 with rollback, nothing replaced (080 fix-log V14) |
| M10 | Exit timing | `WinMainBody` tail (`salamdr1.cpp`) | after the main window is destroyed the process still waits for windows (up to 1 s steps) and `Sleep(1000)` - an installer started at the main window's destruction would meet a living process; the at-exit start belongs at the very end of `WinMainBody` |

## Decisions

(see spec.md *Assumptions* and plan.md)

## Progress

- 2026-11-08: branch, spec, clarify (5 autonomous answers), plan, tasks, analyze (3 small fixes).
- Implementation: `src/common/salupdinstall.h` (pure rules), `salupdcheck.h` (asset id / size /
  digest / API url), `src/updhttp.h` (async WinHTTP helpers shared with 123), `src/updinstall.*`,
  notification forms (`upddlg.cpp`, `IDD_UPDATENOTICE`), General page level list, About test line,
  `--updatetest`, start-up completion and exit hook (`salamdr1.cpp`), `tools/check_update_pin.py`
  run by `build.cmd`. First build: `BUILD SUCCEEDED`; saltests `287127 checks, 0 failed`.

## Findings fixed on the way (found by this run's own tests)

| # | Finding | Severity | How found | Fix |
|---|---|---|---|---|
| F1 | A second instance started while the first held an automatic arm would "complete" the update at its start - the installer would close the first instance's windows | 5 | writing probe group X (design review of the start-up decision) | completion at start-up only when no other instance of the executable runs in the session (`UpdiLastInstance`); probe X1 |
| F2 | **An installer's close (Restart Manager, feature 080) started a second installer at the end of the exit**: `UnattendedClose` is set only for the time of `WM_ENDSESSION`, `PrepareExit` read it after it was reset | 5 (would have run two installers at once after every Install Now / start-up completion) | end-to-end run E2 with the real installer: `Install Launches` 2 after one completion (negative control, `probe/result_e2e.txt` first run) | the exit kind is recorded in the main window's `WM_DESTROY` (`UpdInstall_Shutdown`), where the flag is still set; E2 `once`: 1 installer start, launches 1 |

## Probes

| Probe | Result |
|---|---|
| `probe/autoupd_probe.ps1` (Debug, fixture server `updserver420.py`, hidden desktop) | first full run 39 PASS / 11 FAIL - all 11 probe defects (V read the form after the program closed; S3 started before the killed process was gone, so the program correctly waited for "another instance"; G opened Configuration on the last-used page). Diagnosed with group `Dbg`. Final: **54 PASS, 0 FAIL, 0 NOT DRIVEN**, registry restored (SHA-256 equal) |
| `probe/e2e_peruser.ps1 -Fixture` (real published 0.1.9 installed per user, Debug build copied over it, real signed 0.2.0 installer served by the fixture, real Inno Setup) | before F2: 6 PASS but launches 2; after F2: **7 PASS, 0 FAIL** - at-exit install (installed exe = published 0.2.0 by SHA-256), completion at the next start after a kill (the installer closed the program through the Restart Manager), one installer start; per-user installation uninstalled, registry restored |
| real GitHub (`-Only Real`, `e2e_peruser.ps1` without `-Fixture`) | **not runnable on 2026-11-08**: api.github.com answered with GitHub's "Unicorn!" error page (HTML) and the download addresses with 504 - an outage at GitHub, also outside the tool sandbox. The real-endpoint run is repeated before closing or owed to a person. |
