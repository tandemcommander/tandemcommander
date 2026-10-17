---
title: Plug-in rows of 131 that need a volume or a special file
type: person-step
status: open
severity: 3
area: other-plugins
source: leftover:131
who: person
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [undelete-mount-points-and-efs-114-115]
depends-on: []
reason: -
---

# Plug-in rows of 131 that need a volume or a special file

## Problem

Feature 131 fixed defects in several plug-ins but could not drive these rows in the program (measured by test programs or read only): ZIP favourites (a long name survives a restart; VÍR / VÝR), Undelete (needs a volume to scan), Renamer ('Duplicate name.' alone), Registry Editor Find with '(', DiskMap on a deep (CJK) folder, the PE Viewer dump of a file with an accented version key.

## Evidence

Migrated from specs/NEXT-WORK.md header, 'Before 0.1.10 - steps owed to a person' point 3 (at 7993914c). Source: specs/131-plugin-defect-batch/fix-log.md section 5 'Tests', paragraph 'Not driven in the program'; per-plug-in detail in specs/131-plugin-defect-batch/items/*.md; the authors' test programs in specs/131-plugin-defect-batch/probe/pictview-diskmap-peviewer/.

## Expected

Each row below checked in the program and recorded in 131's fix-log; any failure becomes a new item.

## Notes

131's 'Not driven' paragraph lists more than NEXT-WORK names: PictView Update Thumbnail on an accented path, the .set round trip with zip2sfx.exe, the File Comparator's font field, FTP Quick Rename and the Logs combo (need a server), SFTP against a server (rows R1-R5, P1-P5). NEXT-WORK's point 3 names only the six below; check the rest with the same session if convenient. Third of the four person steps owed before 0.1.10 (`backlog/RELEASE.md`, *Current release*); NEXT-WORK §D L779-780 lists the same rows. The SFTP rows against the test server are `sftp-test-container-rows-133`.

## Steps

- [ ] ZIP favourites: a favourite with a long name survives a restart; VÍR / VÝR stay two entries
- [ ] Undelete on a real volume (scan, restore)
- [ ] Renamer: 'Duplicate name.' appears alone
- [ ] Registry Editor: Find with '(' in the text
- [ ] DiskMap on a deep folder (CJK names)
- [ ] PE Viewer: the dump of a file with an accented version key

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — moved to Person steps position 3
- 2026-10-17 — migration review M1/N1/N3: third of the four steps owed before 0.1.10; the seventh step repeating the six removed; migration remarks replaced
