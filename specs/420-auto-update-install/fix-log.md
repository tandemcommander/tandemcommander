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

- 2026-11-08: branch, spec.
