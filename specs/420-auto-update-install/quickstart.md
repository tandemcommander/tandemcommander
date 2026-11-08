# Quickstart - validating 420-auto-update-install

## 1. Unit rules

`.\build.cmd` then `build\tandemcommander\Debug_x64\saltests\saltests.exe` -> `0 failed`
(groups: extended release record, asset address, redirect allow-list, digest, version-resource
rule, installer arguments, level, arm / start-up / exit decisions). `tools/check_update_pin.py` runs
in every build (pin == `codesign.cfg`).

## 2. Behaviour probe (Debug build, hidden desktop)

`specs/420-auto-update-install/probe/autoupd_probe.ps1` (registry backed up and restored) starts
`updserver420.py` on loopback - a release record of a chosen version with a digest, the asset
download (302 to itself), and hostile variants - and drives the program with the seams
`TC_UPDATECHECK_URL`, `TC_UPDATECHECK_PRETEND_VERSION`, `TC_UPDATE_PROBE_UNINSTALL`,
`TC_UPDATE_PROBE_RUNLOG`, `TC_UPDATE_PROBE_METERED`. The served installer is the published, signed
`setup/output/tandemcommander-0.2.0-x64-setup.exe`. Groups:

- L levels: 0 -> classic notice, no file; 1 -> offer notice, verified file; 2 -> armed + automatic notice; check off -> nothing.
- V verification: tampered, unsigned, foreign-signed, older version, truncated, oversized, redirect to a foreign host / plain HTTP -> refused, no file, classic notice, never in the run log.
- B buttons: Install Now -> run log `now` with the mode switch; Install When I Close -> armed; Skip -> disarmed, file deleted.
- X exit: armed + normal exit -> run log `exit`; two instances -> the first exit logs nothing, the last does.
- S start-up completion: armed, program killed -> next start logs `now` at once; launches counted, the fourth start gives up; reached version -> cleaned up.
- T test mode: `--updatetest` with the installed version = published -> offer / arm; no 123 state written; a test arm without the switch is dropped.

## 3. End-to-end with the real installer (per-user, hidden desktop)

`probe/e2e_peruser.ps1`: install the published 0.1.9 per-user (`/CURRENTUSER`), copy the Debug
build over it (an "installed" copy of this feature), set level 2, start it with `--updatetest`
(real GitHub, real download of 0.2.0), wait for the arm, close it normally -> the real installer
runs at exit; the installed `tandemcommander.exe` then equals 0.2.0's. Second scenario: arm, kill
the program, start again with `--updatetest` -> the installer runs at once (`TC_UPDATE_PROBE_NORESTART`
keeps the restart off the visible desktop) and the files become 0.2.0. Finally the per-user
installation is uninstalled.

## 4. Owed to a person

The all-users update with a real UAC prompt (accept and decline), *Install Now* with the restart on
the real desktop, the notification forms with a real mouse and a screen reader, one real release
update (0.2.0 -> next) with the default level.
