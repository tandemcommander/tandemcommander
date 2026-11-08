# Closing report - 420-auto-update-install
Backlog item: automatic-update-background-download - Automatic update: download the new version in the background and install it
Outcome: closed

## What changed

- Configuration > General: *When a new version is found* - notify only / download and offer
  installation (default for new and existing users) / install automatically when Tandem Commander
  closes. Enabled with the start-up check.
- After the check of feature 123 finds a newer release, the installer is downloaded in the background
  (GitHub API asset address, own redirect allow-list, HTTPS only, not on a metered connection) and
  proven (SHA-256 of the release record, Authenticode, pinned signer thumbprint, version resource).
- The notification offers *Install Now* / *Install When I Close* / *Remind Me Later* / *Skip This
  Version*; at the automatic level it says the update will be installed at the exit (*OK*,
  *Install Now*, *Skip*).
- The exit of the last instance installs a planned update silently; an update the exit did not start
  (crash, kill, sign-out, another instance) is completed at the next start; one whose installer ran
  and did not install it is only offered until the user confirms it again (`Install Confirmed`).
- Install mode taken from the uninstall entry (HKLM `/ALLUSERS` with UAC, HKCU `/CURRENTUSER`).
- `--updatetest` (session only, also Release): the published version is treated as newer - the whole
  process can be repeated on the installed version.
- `PRIVACY.md`, help pages (`configuration_gener.htm`, `othertask_newversion.htm`),
  `architecture/12-project-reference.md` (Automatic update, certificate renewal, test mode),
  `tools/check_update_pin.py` in `build.cmd`, translations of all new texts (8 languages, pins).

## Measurements (before / after, commands)

Before (at 824e8f58, fix-log "Measurements before"): the check only notified; the installer was
downloaded and run by hand. After: `specs/420-auto-update-install/probe/autoupd_probe.ps1` (hidden
desktop, fixture server `updserver420.py`) and `e2e_peruser.ps1` (real published 0.1.9 installed per
user, this build over it, the real 0.2.0 installer from GitHub).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL 0.
- `build.cmd`: BUILD SUCCEEDED; `build.cmd full` after the translation refreshes: BUILD SUCCEEDED.
- saltests: **287,190 checks, 0 failed** (`TestAutoUpdate420`).
- probe `autoupd_probe.ps1`: **104 PASS, 0 FAIL, 1 NOT DRIVEN** (R5 E, the keyboard after the forced reshow - a person); registry restored, SHA-256 equal.
- `e2e_peruser.ps1` against the real GitHub: **7 PASS, 0 FAIL** (after round 6; rounds 7-8 changed
  only failure paths the e2e run does not take).
- Release build: the Debug seams (`TC_UPDATE*` probe variables) are absent (string search on the
  Release build made during the run; the later seam `TC_UPDATE_PROBE_LAUNCHFAIL` sits inside the same
  `#ifdef _DEBUG` block of `UpdiLaunch`).

## Reviews (findings and what was done)

Eight independent refute-first reviews plus two UI/UX test passes; every finding is in
`fix-log.md` (sections Review 1 ... Round 8). MUST findings in review 1, round 3, round 4 and
round 5; rounds 6, 7 and 8 found **zero MUST** (SHOULD 2 / 1 / 3, all fixed). **Deviation from
stop-rules §3 #3** (a third review with MUST → stop): the maintainer asked in this session to have
the findings of independent agents worked in iteratively until the behaviour is functional, stable and
user-friendly; each round found a different, narrower defect, none repeated - the run continued.

## Owed to a person (the lines added to the release checklist)

8 lines in `manual-checks-owed-before-the-next-release` (feature 420): the all-users update with a
real UAC prompt (Yes / No; the restarted program not elevated), the automatic level with UAC at the
exit, real mouse / keyboard / Dark on the three forms, Narrator, the keyboard after a failed *Install
Now* that used up the launches, the next real release without `--updatetest`, the certificate renewal
procedure.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

All review / UX findings were inside the item's scope and fixed in the feature (fix-log).

## New Inbox items (slug - title)

None.

## CHANGELOG entry (no `[Unreleased]` section exists - for the maintainer)

- **Tandem Commander can update itself** (feature 420).
  - **Before:** the program only said that a newer version exists; the installer had to be downloaded
    in the browser and run by hand.
  - **Now:** Configuration > General > *When a new version is found*: notify only, **download and
    offer installation** (the default), or install automatically when Tandem Commander closes. The
    installer is downloaded in the background from the project's GitHub release and checked (its
    checksum, its signature and the project's signing certificate) before it is offered or run.
    *Install Now* closes the program, installs the update and starts it again; *Install When I Close*
    installs it when you close the program. An update that was planned but could not be installed at
    the close is completed at the next start. An installation for all users asks for administrator
    rights (UAC). Nothing is downloaded on a metered connection.
  - **Limitation:** a copy not installed by the installer (portable, unpacked) is only notified. An
    update whose installer was cancelled or failed is not installed again on its own - it is offered.
