---
title: Check the Undelete same-partition warning for a target in an accented mount folder
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:324
who: person
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: [undelete-mount-points-and-efs-114-115]
depends-on: []
reason: -
---

# Check the Undelete same-partition warning for a target in an accented mount folder

## Problem

Feature 324 made Undelete's same-partition warning and the temporary-folder check of View fail
closed when the core cannot tell the target's volume (a mount folder named outside ASCII, a
junction to a volume-GUID folder): the plug-in then compares the volume serial numbers of the
nearest existing folders. The decision is checked by `saltests` on real junctions, but the restore
and View through the Undelete GUI were not run - opening a volume needs an elevated program.

## Evidence

- `specs/324-undelete-unknown-volume/fix-log.md` - *Measurement* (NOT DRIVEN: elevation) and
  *Review* (NOTE 6); `quickstart.md` step 4.
- `src/plugins/undelete/fs2.cpp` `UndPathsMayShareVolume`, used by `CopyOrMoveFromFS`
  (`IDS_SAMEPARTITION`) and `GetTempDirOutsideRoot` (`IDS_TEMPDIR`).
- Same setup as `undelete-mount-points-and-efs-114-115` (a spare volume mounted at an accented
  folder) - one session can do both.

## Expected

The warning "It seems you are undeleting to the same logical disk..." appears when restoring into
a folder of the recovered volume reached through its accented mount folder, does not appear for a
target on another volume, and View asks for a temporary folder on another disk when TEMP lies on
the recovered volume. Results recorded in `specs/324-undelete-unknown-volume/fix-log.md`.

## Notes

- The warning is off when "Don't show this again" was ticked earlier (Undelete configuration):
  check it is on before the steps.

## Steps

- [ ] Mount a spare volume X (USB stick) at both a drive letter (e.g. `E:\`) and an accented folder: `mkdir C:\mnt\Zálohy`, elevated `mountvol C:\mnt\Zálohy \\?\Volume{...}\` (the stick's volume name from `mountvol`)
- [ ] Start Tandem Commander as administrator, Ctrl+Shift+U, open X by its drive letter (`del:E:\`), select a deleted file, copy it with F5 into `C:\mnt\Zálohy\restore` - the same-partition warning appears (before 324 it did not); press Cancel
- [ ] Copy the same file into a folder on another volume (e.g. `D:\restore`) - no warning, the file is restored
- [ ] With the user's TEMP on X - set the user variables `TEMP` and `TMP` to `C:\mnt\Zálohy\tmp` in System Properties > Environment Variables (the program re-reads them from the registry, a TEMP set only in a console is ignored), restart the program as administrator, open `del:E:\` - View (F3) a deleted file: the program asks for a temporary folder on another disk; then set `TEMP` / `TMP` back
- [ ] `mountvol C:\mnt\Zálohy /D`; record the results in the 324 fix-log

## Log

- 2026-10-23 — created (source leftover:324)
- 2026-10-23 — moved to Person steps position 38
