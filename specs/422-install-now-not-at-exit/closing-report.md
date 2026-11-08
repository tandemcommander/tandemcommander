# Closing report - 422-install-now-not-at-exit
Backlog item: update-install-right-away-never-at-exit - Updates install right away with a restart, never when Tandem Commander closes
Outcome: closed

## What changed

- The automatic level installs right away after the background check at start-up (close, progress
  window, start again) - no idle wait; it waits only while something can be lost (`DecideCloseApp`,
  command-line text, Quick Rename, an open Find window, another instance, a running installer).
- Nothing is installed at the exit: 420's exit route, *Install When I Close*, the question "install it
  when you close?" and their strings are removed. A plan not installed while running is completed at the
  next start.
- A check the user starts (Help > Check for New Version, the About box's *Check now*, a level chosen in
  the notification) always shows the window with *Install Now* (maintainer requirement during the run).
- The maintainer's lock-out trap: an installer that closed the program and was cancelled, or a declined
  UAC prompt, never starts again on its own (launch count verified before the start;
  `SalUpdArmAfterInstallerFailed` keeps a failed click's plan offered).
- Manual, `PRIVACY.md`, notes in the 420 / 421 UI contracts, translations (3 rows removed per language).

## Measurements (before / after, commands)

- Before (95dc740e): probe 421 rows A2 / L2 / R1 - the exit installs (`exit|... /VERYSILENT`); the
  maintainer's setup log of 19:48 with the exit command line.
- After: `specs/422-install-now-not-at-exit/probe/install422_probe.ps1` - **61 PASS / 0 FAIL / 0 NOT
  DRIVEN**, registry restored identical; X1: no exit started an installer.

## Checks (encoding guard, build, saltests, probes - with numbers)

- Encoding guard `TOTAL: 0 finding(s)`; `build.cmd full` and `build.cmd` BUILD SUCCEEDED; saltests
  `287236 checks, 0 failed`; `translate.slt --verify` byte-exact; probe 61 PASS.

## Reviews (findings and what was done)

- Review 1: M1 (a failed click install re-planned silently) fixed + probe T4; NOTE 3 (count verified)
  fixed; NOTE 7 comments; others accepted (fix-log).
- Review 2: no MUST; S1 (an open Find window closed by the installer) fixed + probe F4; X1 made
  meaningful; comments.

## Owed to a person (the lines added to the release checklist)

Four lines (feature 422) in `manual-checks-owed-before-the-next-release`: the real UAC accept and the
restart; the lock-out trap on the real desktop; Help / About check shows the window; command line /
Find hold it. They supersede the "install at close" parts of the feature 421 lines.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The launch count could in theory fail to be stored before a launch - now verified, the installer is
  not started otherwise (review 1 NOTE 3).

## New Inbox items (slug - title)

- (none)

## CHANGELOG entry (the tree has no `## [Unreleased]` section - owed to the maintainer)

- **Updates are installed right away, never when you close Tandem Commander** (feature 422). With the
  setting *Install it automatically as soon as it is downloaded*, the update found by the check at
  start-up is installed at once: Tandem Commander closes, the update is installed with a progress
  window, and the program starts again. It waits only while something could be lost (a copy or search
  running, a Find window or a dialog open, text typed in the command line, another running copy).
  Nothing is installed when you close the program any more - *Install When I Close* is gone; an update
  not installed while the program ran is installed at its next start. *Help > Check for New Version*
  always shows the window with *Install Now*. If you cancel an installation (or decline the
  administrator's permission), it is never started on its own again - only offered.
