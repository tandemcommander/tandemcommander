---
title: Closing for a real update: elevated installer, sign-out, open plug-in windows
type: person-step
status: open
severity: 6
area: plugin-api
source: leftover:080
who: person
created: 2026-09-20
updated: 2026-10-26
verified: -
effort: M
feature: -
related: [new-version-check-123-person-steps, ftp-real-server-checks-090-116-121]
depends-on: []
reason: -
---

# Closing for a real update: elevated installer, sign-out, open plug-in windows

## Problem

Closing the program for an installer's update (080 Restart Manager, 088 plug-in interface 107, 118 plug-in windows) was verified per-user and through probes; real updates need an elevation prompt answered, a real sign-out, a published newer version or a real mouse, and are owed to a person.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'Environment or hardware' ('the elevated machine-wide update with the program open, a real winget upgrade, real sign-out/shutdown and a servicing restart (080/REMAINING-WORK.md P1)') and §B 'The features' own quickstart.md person steps' ('088 (...)', '118 (...)') (at 7993914c). Steps: specs/080-restart-manager-upgrade/REMAINING-WORK.md 'P1 - Owed to a person' 1-5 and specs/080-restart-manager-upgrade/quickstart.md §5; specs/088-plugin-interface-107/quickstart.md 'Owed to a person' 1-4; specs/118-plugin-update-close/quickstart.md 'Owed to a person (not automatable here)'.

## Expected

Each step behaves as its source says; the restarted program after an elevated update is not elevated; results in 080's, 088's and 118's records.

## Notes

080 P1 step 2 (a real winget upgrade) needed the package in the winget catalogue and a newer published version: both hold since 2026-10-25 (the catalogue holds 0.1.7, 0.1.9, 0.1.10 and 0.2.0; microsoft/winget-pkgs#426090 merged 2026-10-08), so the step can be run from 0.1.10 to 0.2.0 or at the next release. 121's FTP welcome-message update row is in ftp-real-server-checks-090-116-121; 123's installer update with the notification open in new-version-check-123-person-steps.

## Steps

- [ ] 080 P1 step 1: install into C:\Program Files, start non-elevated, run the installer elevated and silent over it - exit 0, the program starts again and is NOT elevated (Task Manager, Elevated column)
- [ ] 080 P1 step 2: a real winget upgrade with the program open (e.g. 0.1.10 installed by winget, then winget upgrade tandemcommander to 0.2.0) - exit 0, the program closes, is updated and starts again
- [ ] 080 P1 step 3: the interactive installer over a running program - Preparing to Install offers to close it; both choices behave ('do not close' ends in Setup's own file-in-use handling)
- [ ] 080 P1 step 4: real sign-out, shutdown and forced shutdown, idle and with a file operation running - Exiting dialog, block reason, configuration backup of a critical shutdown as in 0.1.7
- [ ] 080 P1 step 5: a servicing restart (Update and restart) with the program open - the configuration intact afterwards
- [ ] 088 steps 1-3: a real update with a Code Viewer window open (closes, updates, starts again); Alt+F4 with a viewer open (No keeps the program); sign-out / shutdown with a viewer open
- [ ] 088: PictView with a pasted (unsaved) image - the program declines the update; step 4: PictView and the Database Viewer on a deep folder, Space / Backspace step through; viewers_probe.ps1 once more on the visible desktop
- [ ] 118: a real update with a finished File Comparator / Disk Map / Verify window open (closes and restarts); with an unsaved Calculate list or a Batch Renamer dialog open the installer reports it could not close and the window keeps its content
- [ ] 118: Disk Map's file tooltip shown (mouse over the map) during the request - agrees

## Log

- 2026-09-20 — microsoft/winget-pkgs#426090 still open - a real winget upgrade not possible yet
- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — migration review N2: dangling reference replaced by winget-submit-release-after-pr-426090
- 2026-10-26 — 080 P1 step 2 no longer blocked: the catalogue holds 0.2.0 (#426090 merged 2026-10-08); step and Notes reworded
