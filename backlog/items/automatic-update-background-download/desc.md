---
title: Automatic update: download the new installer in the background and install it
type: feature
status: open
severity: 4
area: privacy-security
source: manual
who: agent
created: 2026-11-08
updated: 2026-11-08
verified: -
effort: L
feature: -
related: [new-version-check-123-person-steps, checkver-update-channel-decision, update-close-real-installer-signout-080-088-118]
depends-on: []
reason: -
---

# Automatic update: download the new installer in the background and install it

## Problem

Since feature 123 the program tells the user that a newer version exists, but the user still has to download the installer, run it and click through it. The maintainer decided on 2026-11-08 (see *Question* / *Options* / *Recommendation* below and the *Log*) that the program downloads the new installer by itself and installs it on the user's click or automatically at exit, by a setting with three levels.

## Evidence

By reading at 91ff7c45; nothing was reproduced.

- What exists: `src/common/salupdcheck.h` `SalUpdInstallerUrl` (~194) builds `https://github.com/tandemcommander/tandemcommander/releases/download/v<ver>/tandemcommander-<ver>-x64-setup.exe` from the validated version; `src/updcheck.cpp` (~536) sends the check through WinHTTP with `WINHTTP_DISABLE_REDIRECTS`. Feature 123 in `specs/FEATURE-HISTORY.md` (`- 123-new-version-check`).
- Closing the running program for an installer through the Restart Manager works, plug-in windows included: features 080, 088, 118.
- `setup/tandemcommander.iss`: `PrivilegesRequiredOverridesAllowed=dialog` (line 41, must stay - winget, 072), `SignTool=tcsign` (51); Inno Setup accepts `/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS`. An all-users install into Program Files needs elevation, so a UAC prompt appears; only a per-user install (`/CURRENTUSER`, `%LOCALAPPDATA%\Programs`) updates silently.
- Shipped binaries and the installer are Authenticode-signed (077), so a downloaded installer can be verified before it runs.

## Expected

The decision of 2026-11-08, binding for the run:

1. **One setting on Configuration > General, three levels**: *Notify only* (today's behaviour, 123) / *Download and offer installation* / *Install automatically when the program closes*. It takes effect only while the new-version check (123) is on; with the check off nothing is downloaded.
2. **Default: Download and offer installation** - for new installs and for existing users after the update to this version.
3. **Download and offer**: after the check finds a newer version, the installer is downloaded in the background into a folder under `%LOCALAPPDATA%` and verified (point 6); the notification then offers *Install now* and *Install when I close the program*. Nothing is installed without a click.
4. **Install automatically**: the same download and verification; the installer runs **when the program closes** (never at the next start, which would delay the user when they want to work), silently (`/VERYSILENT /SUPPRESSMSGBOXES` with the Restart Manager options of 080 / 088 / 118), and the next start runs the new version.
5. **The update keeps the install mode of the existing install, chosen explicitly**: the program reads where the Uninstall entry of the AppId (`{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1`) lives - HKLM passes `/ALLUSERS`, HKCU `/CURRENTUSER` - and does not rely on Inno Setup's `UsePreviousPrivileges`. A per-user install updates with no prompt at all; an all-users install shows the **UAC prompt, which is accepted** (also at the *automatic* level); declining it leaves the downloaded installer offered as in point 3. **No elevated service or scheduled task.** No Uninstall entry (a portable copy, a build tree) -> the levels act as *Notify only*.
6. **Integrity before running** (mandatory): `WinVerifyTrust` plus a check that the signer is **our** certificate (`tools/codesign/codesign.cfg`, as `tools/winget/publish.ps1` checks it in 072), not merely any valid signature; a file that fails is deleted and never run; the version inside the installer equals the version the check announced.
7. `PRIVACY.md` updated in the same change (the download is new network communication; a file stored under `%LOCALAPPDATA%`, removed after the install or when superseded).

## Approach

- Download: the asset address from `SalUpdInstallerUrl` (`src/common/salupdcheck.h`); GitHub answers it with a redirect (to `release-assets.githubusercontent.com` - verify the host when implementing). 123 disables redirects (`WINHTTP_DISABLE_REDIRECTS`); allow a redirect only to an exact list of GitHub hosts, over HTTPS. The pure rules (host allow-list, file names, the level decision, the mode choice from the Uninstall entry) go into a header under `src/common/` with `saltests` checks.
- A partial download is resumed or deleted, never run; a metered connection (`GetConnectionCost`) does not download in the background, only after the user's click; a new version announced later replaces the old download.
- Closing for the installer goes through the existing Restart Manager route (080, 088, 118: decide at the question without side effects, act at the instruction with `UnattendedClose`).
- winget users are unaffected in their tooling: winget reads the same Uninstall entry and the installer is the same.
- Antivirus heuristics (076): a program that downloads and runs an `.exe` may be flagged more often; the signer check and the signed installer lower the risk - note it in the closing report.
- Probes: an installer probe on the hidden desktop like 080's for both modes (per-user silent end to end; all-users up to the elevation request), the integrity refusals (unsigned, foreign-signed, truncated file), the redirect allow-list. A real UAC prompt and the interactive *Install now* flow go as lines into *Manual checks owed before the next release*.
- New UI strings (the setting, the notification buttons) need the two-stage `.slt` refresh in the same run.

## Notes

The idea was recorded on 2026-11-08 and discussed with the maintainer the same day in an interactive triage; the decision is in *Expected* above and in the *Log*. `checkver-update-channel-decision` decides the update channel of the legacy checkver plug-in; the decision here is logged there too. Inno Setup's `UsePreviousPrivileges` (default `yes`) would reuse the previous install's mode by itself according to its documentation; not measured here, and the decision is not to depend on it. Measured in 072: `/VERYSILENT /CURRENTUSER` installs into `%LOCALAPPDATA%\Programs` with no elevation with this exact installer configuration (`PrivilegesRequiredOverridesAllowed=dialog`, comment at `setup/tandemcommander.iss:34`).

## Question

Should the program download the new installer by itself and install it, and if so: when (at the next start, at exit, on the user's click), how silently, and what is the default?

## Options

- **A - keep notify only (today, 123).** Nothing changes; no new network traffic, no new privacy claim.
- **B - download in the background, offer installation.** After the check finds a newer version the installer is downloaded to `%LOCALAPPDATA%` and verified; the user gets "Install now" / "Install when I close the program". Restart Manager and the restart of the program already work, so both are cheap. A UAC prompt appears for all-users installs.
- **C - install automatically (at exit or at the next start).** As B, but without asking. At the next start the user waits 10-30 s (plus UAC) just when they want to work - exit is the better moment. Truly silent for all-users installs only with an elevated service or scheduled task - a large change to the installer and `PRIVACY.md`, not recommended.

Common work for B and C (why the effort is L):

1. **Integrity (mandatory)**: before running the file, `WinVerifyTrust` plus a check that the signer is our certificate (subject / thumbprint), not just any valid signature; optionally the SHA256 `digest` the GitHub API gives for release assets. Without it the update is a path to running foreign code.
2. **Redirects**: release-asset downloads redirect to `release-assets.githubusercontent.com` (verify the host at implementation time); 123 refuses all redirects - allow only to an exact list of GitHub hosts.
3. **`PRIVACY.md`** in the same change: new network communication and a new file stored on disk (download folder, cleaned up after the install).
4. Only for installs made by the installer (Uninstall entry of the AppId); a metered connection downloads only on request (`GetConnectionCost`); partial downloads resumed or deleted; winget users are unaffected (winget reads the same Uninstall entry).
5. Antivirus heuristics (076): a program that downloads and runs an `.exe` may be flagged more often; the signature lowers the risk.
6. An installer probe on the hidden desktop like 080's; a real UAC prompt is a person step.

## Recommendation

B as the new default, with one setting on Configuration > General in three levels: notify only / download and offer installation / install automatically at exit. Not at the next start (it delays the start just when the user wants to work), and no elevated service. Agent's proposal from the conversation of 2026-11-08; the maintainer has not decided.

## Log

- 2026-11-08 — created (source manual)
- 2026-11-08 — maintainer decision 2026-11-08: one setting on Configuration > General with three levels - notify only / download and offer installation (default, new and existing users) / install automatically at exit; the update keeps the mode of the existing install, chosen explicitly from the Uninstall key (HKLM -> /ALLUSERS, HKCU -> /CURRENTUSER); a UAC prompt for all-users installs is accepted, no elevated service
- 2026-11-08 — decision converted to work
- 2026-11-08 — moved to Next position 1
