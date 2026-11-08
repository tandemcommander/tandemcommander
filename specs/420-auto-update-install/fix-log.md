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

## Review 1 (independent agent, refute-first, static + one saltests negative control)

| Finding | What | Done |
|---|---|---|
| MUST M1 | Two installers at once: the start-up completion (program reopened while the exit's installer still runs), an exit after Install Now before the Restart Manager closes the program, Install Now twice - nothing checked for a running setup; the `.iss` has no `SetupMutex` | `SalUpdIsInstallerProcessName` (saltests) + `UpdiInstallerRunning` (Toolhelp, same session): no start-up completion, no exit install, and Install Now answers `IDS_UPDATE_BUSY` while an installer of the product runs. The installer (`.iss`) is not changed (maintainer-owned; published installers would not have it anyway). Probe rows M1 start / exit / after / now |
| SHOULD S1 | The 3-launch cap was restarted by the next check (give-up dropped the arm, the automatic level re-armed with 0 launches) - an elevation prompt after every exit, cycle after cycle | give-up keeps the arm with its count; `SalUpdAutomaticArmUsable`: a used-up arm of the same version is offered (Install Now), not promised for the exit; probe S1 giveup / nocycle |
| SHOULD S2 | Level or check option changed during a download: still offered / armed | `ShowDownloadedUpdate` reads both again: check off -> nothing; *Notify me only* -> classic form; probe S2 notify / off |
| SHOULD S3 | `PRIVACY.md`: "Nothing from the server's answer is stored except that version number and date" - the digest is stored now | sentence corrected (and the new *Download Refused* value listed) |
| SHOULD S4 | The restart after an **all-users** update (elevated Setup, `/RESTARTAPPLICATIONS`) unverified - could the program come back elevated? | Not new: a manual update of an all-users installation runs the same elevated Setup with the same Restart Manager restart (feature 080, its check owed to a person). Added to the release checklist (a person with a real UAC prompt). |
| NOTE | verification-to-run gap: the handle was closed after `CreateProcessW` | the installer inherits the deny-write handle (`PROC_THREAD_ATTRIBUTE_HANDLE_LIST`), the file stays the verified one while it runs |
| NOTE | a portable copy sharing the registry dropped the installed copy's arm and cleaned its folder | start-up decision `susaNone` and no clean-up for a copy that is not eligible; saltests + probe PC |
| NOTE | a cancelled Install Now (or declined UAC) turned into a silent install at the next exit | an arm created by the click is dropped when its installer fails while the program runs; the message says "will be installed when you close" only when the update stays armed (`IDS_UPDATE_INSTALL_LATER`); probe IN |
| NOTE | Enter meant for Download could land on Install Now when the downloaded form replaced a focused classic one | the replacement no longer takes the keyboard by itself |
| NOTE | after a certificate rotation every daily check downloaded 8 MB again | a refused (signer / unsigned / version) download is remembered (`Download Refused`, not in test mode); probe RF |
| NOTE | metered test was a COM call on the UI thread | moved to the download worker (MTA) |
| NOTE | `PRIVACY.md` "describes 0.2.0" next to "up to 0.2.0 nothing" | reworded until the release sets the validity line |
| NOTE | saltests count in the fix-log stale | re-measured at the end |
| NOTE | negative control: removing the user-info check of the redirect rule is not caught (the exact host comparison refuses those addresses anyway) | accepted (redundant check, documented) |

## Translations (stop-rules §2.13, module `salamand`)

- Step 0, entries: new strings `IDS_UPDATE_LEVEL_NOTIFY/OFFER/AUTO`, `IDS_UPDATE_BTN_INSTALLNOW/INSTALLEXIT/OK`,
  `IDS_UPDATE_HINT_OFFER/AUTO`, `IDS_UPDATE_TESTMODE`, `IDS_UPDATE_ABOUT_TESTMODE`, `IDS_UPDATE_INSTALL_FAILED`,
  `IDS_UPDATE_ERR_RUN` (free slots 14096-14100, 14152-14154, 14156-14159 of existing bundles - no new
  bundle); dialog `IDD_CFGPAGE_GENERAL`: new `IDC_UPDATELEVEL_LABEL` + `IDC_UPDATELEVEL`;
  `IDD_UPDATENOTICE`: new button `IDC_UPDN_INSTALLEXIT` (text set at run time), geometry (330 x 193).
  No English text of an existing entry changed - no `english_fallback` keys.
- `build.cmd` -> `build_langs.cmd --export-templates --module salamand` (1/1).
- Dry run: 12 unique gaps per language, ~673 characters (12 strings minus "OK" + the label).
- Merge (`--formality prefer_more --budget 12768`): 12/12 translated, 5,808 DeepL characters; 1
  validation failure (hu `IDS_UPDATE_ERR_RUN`: one `%s` and one `\n` lost - kept English).
- Read-back: the level items became commands to the reader in all 8 languages (de "Laden Sie ...
  herunter und bieten Sie ... an", fr "Téléchargez-la et proposez", cs "Stáhněte si ji a nabídněte",
  ...); hu "Csak akkor értesíts" (informal, "only then"); the About test line became "update the
  test mode" in de/nl/ro; ro capital "(Instalarea"; button accelerators checked against the
  window's other buttons and its check box per language. Pinned in `ui-overrides.json`
  (`salamand`, note `_feature_420`): the 3 level items and the 2 install buttons in every
  language, Czech whole (as in 123), sk/de/fr/nl/ro About test line, nl test line, hu
  `IDS_UPDATE_ERR_RUN`, ro install-failed message. Label accelerators of the General page checked
  per language (all unique: cs j, de w, fr l, nl g, hu h, ro g, sk e, es s).
- Second merge: pins applied (83 DeepL characters for the re-sent hu row, the pin wins);
  `slt --verify`: 298 files, round-trip byte-exact; `build.cmd full`: `BUILD SUCCEEDED`
  (21 modules x 8 languages). Layout drift committed with the pipeline's output (the
  `IDD_UPDATENOTICE` rows follow the new English geometry).

## Probes

| Probe | Result |
|---|---|
| `probe/autoupd_probe.ps1` (Debug, fixture server `updserver420.py`, hidden desktop) | first full run 39 PASS / 11 FAIL - all 11 probe defects (V read the form after the program closed; S3 started before the killed process was gone, so the program correctly waited for "another instance"; G opened Configuration on the last-used page). Diagnosed with group `Dbg`. Final: **54 PASS, 0 FAIL, 0 NOT DRIVEN**, registry restored (SHA-256 equal) |
| `probe/e2e_peruser.ps1 -Fixture` (real published 0.1.9 installed per user, Debug build copied over it, real signed 0.2.0 installer served by the fixture, real Inno Setup) | before F2: 6 PASS but launches 2; after F2: **7 PASS, 0 FAIL** - at-exit install (installed exe = published 0.2.0 by SHA-256), completion at the next start after a kill (the installer closed the program through the Restart Manager), one installer start; per-user installation uninstalled, registry restored |
| real GitHub (`-Only Real`, `e2e_peruser.ps1` without `-Fixture`) | **not runnable on 2026-11-08**: api.github.com answered with GitHub's "Unicorn!" error page (HTML) and the download addresses with 504 - an outage at GitHub, also outside the tool sandbox. The real-endpoint run is repeated before closing or owed to a person. |
