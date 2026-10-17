---
title: Same-file guards on macOS / Samba and case-sensitive shares, snapshots, FAT
type: person-step
status: open
severity: 5
area: data-safety
source: leftover:107
who: person
created: 2026-10-06
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [name-identity-checks-092]
depends-on: []
reason: -
---

# Same-file guards on macOS / Samba and case-sensitive shares, snapshots, FAT

## Problem

The identity rules of 092 (name identity), 103 (same-file delete guard) and 107 (folder alias move) were verified locally, through \\localhost, subst and WebDAV seams; file systems that behave differently need hardware or admin rights: a macOS or Samba SMB share (NFC / NFD names), a case-sensitive share or a server that folds case differently from Windows, volume shadow-copy snapshots and FAT volumes.

## Evidence

Migrated from specs/NEXT-WORK.md §B 'Environment or hardware' ('a real macOS or Samba share (103, 107) and a case-sensitive share (092)', 'snapshots and FAT volumes (107, admin)') (at 7993914c). Sources: specs/103-same-file-delete-guard/quickstart.md 'By hand' step 6 (a macOS or Samba share where an NFC/NFD rename is answered 'already exists' - expected: renamed through salXXX, never deleted); specs/092-name-identity-unicode/quickstart.md 'Not testable on this machine' and fix-log S3 item 1; specs/107-folder-alias-move/fix-log.md (SalDirIsSame: snapshot tags via HarddiskVolumeShadowCopyN / @GMT- components, FAT / exFAT ids only with equal times; macOS / Samba named in its limits).

## Expected

On each environment no file or folder is deleted or overwritten as 'the same' when it is not, and a real alias is refused; results in the features' fix-logs; any loss is a severe new item.

## Steps

- [ ] 103: a macOS or Samba SMB share where an NFC / NFD rename is answered 'already exists' - renamed through salXXX, never deleted
- [ ] 107: on a macOS or Samba share, the folder-alias rows of 107's quickstart through a name the server folds (NFC / NFD) - refused as on the WebDAV seam that reproduced the folding (107 fix-log 'Not driven'); an ordinary move still works
- [ ] 092: a case-sensitive directory on a network share, and a server that folds case differently from Windows (092 fix-log S3 item 1)
- [ ] 107 (admin): a volume shadow-copy snapshot (a HarddiskVolumeShadowCopyN or @GMT- path) and its live folder - not taken for the same folder (SalSnapshotTagFromPath / SalDirIsSame, 107 fix-log table)
- [ ] 107 (admin): a FAT / exFAT volume - folder identity counts only with equal times; a move of a folder into its alias is refused, into another folder it is not

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
