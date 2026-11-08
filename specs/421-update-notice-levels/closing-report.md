# Closing report - 421-update-notice-levels
Backlog item: update-level-and-download-install-in-notification - Update notification: level choice, Download & Install, silent automatic install
Outcome: closed

## What changed

- **Level choice in the notification**: *When a new version is found* (the three levels of
  Configuration > General) under the check box; stored at once; enabled only for a copy installed by
  the installer while the check is on; a change acts on the open window (`SalUpdNoticeLevelChange`:
  notify-only form + offer/automatic → download, then the offer form or the silent install; offer +
  notify-only → the notify-only form; offer + automatic → planned, window closed).
- **Download & Install** on the notify-only (classic) form of an installed copy (default button):
  420's download and verification (also on a metered connection - a click), progress in the hint line,
  *Cancel Download*; then the installer as *Install Now*; a failure is reported and the browser
  *Download* stays. Not offered without a verifiable asset or for a refused installer (test mode
  ignores the refusal).
- **A copy not installed by the installer** says so in the hint; no Download & Install; level choice
  disabled.
- **The automatic level** has no window any more: the downloaded, verified update is planned (420's
  automatic arm) and installed as *Install Now* as soon as nothing can be lost (`DecideCloseApp`
  agrees, the last instance, no installer running, 30 s without input unless the user asked for the
  check; once per session); 420's exit / next-start install stays the fall-back. The automatic form
  (OK / Install Now / Skip) and its texts are removed; the level reads *Install it automatically as
  soon as it is downloaded*.

## Measurements (before / after, commands)

- Before (1a25a164, by reading): no level control in the notification; the classic form only
  *Download* (browser); the automatic level showed the automatic form and installed only at exit.
- After: `specs/421-update-notice-levels/probe/notice421_probe.ps1` on the hidden desktop -
  **46 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical (`probe/notice421_result.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `build.cmd full` → `BUILD SUCCEEDED`.
- `saltests` → `287240 checks, 0 failed` (+50, group `TestUpdateNotice421`).
- Probe 421: 46 PASS.
- 420's probe as a regression check: see fix-log *Regression of 420*.

## Reviews (findings and what was done)

See fix-log *Review*.

## Owed to a person (the lines added to the release checklist)

See the release checklist lines added at closing (feature 421).

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The silent install never ran: `DecideCloseApp()` called from a timer always saw the program busy
  (`SalamanderBusy` is TRUE while any message is dispatched) - the decision moved to the idle part of
  the main loop (probe rows A1/A3/A4/A7/L3 before: FAIL, after: PASS).
- A silent install cancelled by lowering the level on the General page left the downloaded update
  unannounced until the next check a day later - now offered (probe row L6).

## New Inbox items (slug - title)

- (none so far)

## CHANGELOG entry (the tree has no `## [Unreleased]` section - owed to the maintainer)

- **The new-version window lets you choose how updates are handled, and installs with one click**
  (feature 421). The window shows *When a new version is found* (the setting of Configuration >
  General) and changes it at once. With *Notify me only* it offers **Download & Install**: Tandem
  Commander downloads the installer itself, shows the progress, checks it (published checksum,
  project signature, version) and installs the update; *Download* still opens it in the browser. The
  third setting is now *Install it automatically as soon as it is downloaded*: no window appears, and
  the update is installed as soon as nothing can be lost (no file operation, search or open dialog, no
  other running copy, half a minute without keyboard or mouse use); closing the program first still
  installs it then. A copy not installed by the installer says that it cannot update itself.
  - **Limitation:** an installation for all users asks for an administrator's permission also when
    the automatic install starts on its own.
