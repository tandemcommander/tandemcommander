---
title: Automatic update: download the new installer in the background and install it
type: decision
status: new
severity: 4
area: privacy-security
source: manual
who: person
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

Since feature 123 the program tells the user that a newer version exists, but the user still has to download the installer, run it and click through it. The maintainer's idea (2026-11-08): the program downloads the new installer in the background by itself and installs it, e.g. at the next start. **To be discussed with the maintainer before anything is planned** - the shape (when to install, how silent, what is the default) is a product decision.

## Evidence

By reading at 91ff7c45; nothing was reproduced.

- What exists: `src/common/salupdcheck.h` `SalUpdInstallerUrl` (~194) builds `https://github.com/tandemcommander/tandemcommander/releases/download/v<ver>/tandemcommander-<ver>-x64-setup.exe` from the validated version; `src/updcheck.cpp` (~536) sends the check through WinHTTP with `WINHTTP_DISABLE_REDIRECTS`. Feature 123 in `specs/FEATURE-HISTORY.md` (`- 123-new-version-check`).
- Closing the running program for an installer through the Restart Manager works, plug-in windows included: features 080, 088, 118.
- `setup/tandemcommander.iss`: `PrivilegesRequiredOverridesAllowed=dialog` (line 41, must stay - winget, 072), `SignTool=tcsign` (51); Inno Setup accepts `/VERYSILENT /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS`. An all-users install into Program Files needs elevation, so a UAC prompt appears; only a per-user install (`/CURRENTUSER`, `%LOCALAPPDATA%\Programs`) updates silently.
- Shipped binaries and the installer are Authenticode-signed (077), so a downloaded installer can be verified before it runs.

## Expected

The maintainer has decided whether and in which form the program updates itself. Then either this item becomes a feature (type changed, *Problem* / *Expected* rewritten for the chosen option) or it is closed as decided "notify only, as today".

## Notes

The maintainer asked to record it as an idea "to be discussed further" - do not triage it into *Next* without that discussion. `checkver-update-channel-decision` decides the update channel of the legacy checkver plug-in; whatever is chosen here should be stated there too.

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
