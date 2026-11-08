# Closing report - 421-update-notice-levels
Backlog item: update-level-and-download-install-in-notification - Update notification: level choice, Download & Install, silent automatic install
Outcome: closed

## What changed

- **Level choice in the notification**: *When a new version is found* (the three levels of
  Configuration > General) under the check box; stored at once (a step with the closed list settles
  for one second); enabled only for a copy installed by the installer while the check is on; a change
  acts on the open window (`SalUpdNoticeLevelChange`).
- **Download & Install** on the notify-only (classic) form of an installed copy (default button):
  420's download and verification (also on a metered connection - a click), progress in the hint,
  *Cancel Download*; then the installer as *Install Now*; a failure is reported and the browser
  *Download* stays. Not offered without a verifiable asset or for a refused installer.
- **A copy not installed by the installer** says so in the hint; no Download & Install; level choice
  disabled.
- **The automatic level** has no window: the downloaded, verified update is installed as *Install Now*
  as soon as nothing can be lost (`DecideCloseApp` agrees, empty command line, no Quick Rename, the last
  instance, no installer running, 30 s without input unless the user asked for the check; once per
  session, decided in the idle part of the main loop); 420's exit / next-start install stays the
  fall-back. A declined failed silent install stays an offer; a cancelled Download & Install of that
  version is "not now". The automatic form and its texts are removed; the level reads *Install it
  automatically as soon as it is downloaded*.
- Manual (General page, new-version page), `PRIVACY.md`, 420's UI contract note, translations of 8
  languages (pins `_feature_421`), `CLAUDE.md` rule on `SalamanderBusy`.

## Measurements (before / after, commands)

- Before (1a25a164, by reading): no level control in the notification; the classic form only
  *Download* (browser); the automatic level showed the automatic form and installed only at exit.
- First probe run of the new code: every silent-install row FAIL (`close=decline: busy`) - fixed by
  moving the decision to the idle loop.
- After: `specs/421-update-notice-levels/probe/notice421_probe.ps1` on the hidden desktop -
  **57 PASS / 0 FAIL / 0 NOT DRIVEN**, registry restored identical (`probe/notice421_result.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `build.cmd full` → `BUILD SUCCEEDED`; `build.cmd` after the last change → `BUILD SUCCEEDED`.
- `saltests` → `287248 checks, 0 failed` (+58, group `TestUpdateNotice421`).
- `translate.slt --verify` → round-trip byte-exact (298 files).
- Probe 421: 57 PASS (groups D, P, L, A, F, R).
- 420's probe with the busy seam: 94 PASS / 10 FAIL / 1 NOT DRIVEN - the 10 FAILs all click or check the
  removed automatic form (fix-log *Regression of 420*).

## Reviews (findings and what was done)

- Review 1: M1 (No after a failed silent install re-planned it silently) fixed; S1-S4 fixed (guard,
  public wording, list settle, busy around the launch, file-operation row); N1-N5 recorded.
- Review 2: no MUST; S-A (*Cancel Download* during a requested check at level 2 still installed) fixed;
  notes fixed or recorded. Details in `fix-log.md`.

## Owed to a person (the lines added to the release checklist)

Five lines (feature 421) in `manual-checks-owed-before-the-next-release`: the real UAC prompt for both
routes (accept / decline + No → only offered), the restart on the real desktop, the window in front at
the end of the download (not closed under the user), keyboard / Narrator on the new controls, design in
every language / theme / scale.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The silent install never ran (`SalamanderBusy` during any dispatch) - decision in the idle loop.
- A level lowered on the General page while the silent install waited left the update unannounced until
  the next check - now shown (probe L6).

## New Inbox items (slug - title)

- (none)

## CHANGELOG entry (the tree has no `## [Unreleased]` section - owed to the maintainer)

- **The new-version window lets you choose how updates are handled, and installs with one click**
  (feature 421). The window shows *When a new version is found* (the setting of Configuration >
  General) and changes it at once. With *Notify me only* it offers **Download & Install**: Tandem
  Commander downloads the installer itself, shows the progress, checks it (published checksum,
  project signature, version) and installs the update; *Download* still opens it in the browser. The
  third setting is now *Install it automatically as soon as it is downloaded*: no window appears, and
  the update is installed as soon as nothing can be lost (no file operation or search running, no modal
  dialog, nothing typed in the command line, no other running copy, half a minute without keyboard or
  mouse use); closing the program first still installs it then. A copy not installed by the installer
  says that it cannot update itself.
  - **Limitation:** an installation for all users asks for an administrator's permission also when the
    automatic install starts on its own; declining it and not wanting it at the exit leaves the update
    only offered.
