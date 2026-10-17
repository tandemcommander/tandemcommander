---
title: Undelete on a mount point with an accented name (admin) and real EFS backups
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:114
who: person
created: 2026-10-06
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Undelete on a mount point with an accented name (admin) and real EFS backups

## Problem

The Undelete plug-in's fixes of 114 (volume list and paths with names outside the code page) and 115 (restore of encrypted files from backup) need an administrator with a spare volume mounted at an accented folder, and an EFS certificate with real encrypted files.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'Environment or hardware' ('volume mount points (114, admin)', 'real EFS backups (115, needs an EFS certificate)') (at 7993914c). Steps: specs/114-undelete-names/quickstart.md 'By hand (person, administrator, a spare volume)' 1-5; specs/115-undelete-leftovers/quickstart.md 'By hand (person, optional)'.

## Expected

114: the volume list shows C:\mnt\voilà exactly and the panel opens the USB volume's deleted files; 115: an EFS file undeleted to FAT and restored onto NTFS comes back encrypted under its name; recorded in each fix-log.

## Notes

131's Undelete row (needs a volume to scan) is in plugin-batch-131-rows-needing-volume-or-file; one session with a spare USB stick can do both.

## Steps

- [ ] 114 step 1: mkdir C:\mnt\voilà, then elevated mountvol C:\mnt\voilà \\?\Volume{...}\ with a spare volume (USB stick)
- [ ] 114 steps 2-3: start Tandem Commander as administrator, Ctrl+Shift+U - the list shows C:\mnt\voilà exactly with the volume's label; OK shows del:C:\mnt\voilà\ with the stick's deleted files
- [ ] 114 step 4: from C:\mnt\voilà\sub connect again to the same volume - the panel path is kept
- [ ] 114 step 5: mountvol C:\mnt\voilà /D
- [ ] 115: on a machine with an EFS certificate, undelete an encrypted file to a FAT USB stick (name.bak), then Restore Encrypted Files from Backup onto NTFS - it comes back encrypted under name
- [ ] 115 (if the probe's key route was NOT DRIVEN): restore from a tree deeper than 300 bytes - everything restored, no message

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — related item plugin-batch-131-rows-needing-volume-or-file closed: done: steps carried out by hand by the maintainer before the 0.1.10 release; maintainer 2026-10-17
