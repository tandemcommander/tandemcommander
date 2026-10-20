---
title: Paste of a case twin from an archive and SFTP twins by hand (252)
type: person-step
status: open
severity: 5
area: archives
source: leftover:252
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [drag-drop-paste-routes-194-228-230-240-by-hand]
depends-on: []
reason: -
---

# Paste of a case twin from an archive and SFTP twins by hand (252)

## Problem

Feature 252 made 7-Zip / TAR listings that hold names differing only in case (and every SFTP listing) case-sensitive. Two routes of it could not be driven on the hidden desktop: the clipboard Paste of one twin out of an archive (the item's own *Expected*: no clipboard and no shell extension copy hook there) and SFTP (the test container `tandem-sftp` was not running). Both use the same mechanism the probe proved (the panel's case sensitivity), but are unconfirmed.

## Evidence

`specs/252-archive-case-sensitivity/fix-log.md`, section *Owed to a person (NOT DRIVEN)*; probe `specs/252-archive-case-sensitivity/probe/arc252_probe.ps1` (rows HIDE / GLOBAL / TREE / CONTROL for TAR and 7z, 16 / 0 after). Code: `CSalShExtPastedData::SetData` / `DoPasteOperation` (`src/salshlib.cpp`), `src/plugins/sftp/fs.cpp` (`SetFlags(SALDIRFLAG_CASESENSITIVE | SALDIRFLAG_IGNOREDUPDIRS)`).

## Expected

Every step below passes on a Release build; the result is recorded in the 252 fix-log; a failure becomes a new item.

## Notes

Fixtures: a case-sensitive folder (`fsutil file setCaseSensitiveInfo <folder> enable`) holding `A.txt` (content `UPPER`) and `a.txt` (content `lower`); `tar -cf t.tar -C <folder> A.txt a.txt` and `7z a -t7z -ssc t.7z <folder>/*` (7-Zip needs `-ssc` for twins). One session can also do `drag-drop-paste-routes-194-228-230-240-by-hand`. The SFTP test server: Docker container `tandem-sftp` on localhost:2222 (user `tctest`).

## Steps

- [ ] TAR: open `t.tar` in a panel, focus `a.txt`, Ctrl+C, paste (Ctrl+V) into an Explorer window of an empty case-sensitive folder -> only `a.txt` arrives, its content is `lower`. Repeat with `A.txt` -> content `UPPER`.
- [ ] 7z: the same with `t.7z` -> the focused twin with its own content.
- [ ] SFTP: on the server, a folder holding `a.txt` and `A.txt`; in the panel select `a.txt`, Hide Selected Names (the menu command) -> `A.txt` stays visible; Store Selection / Unselect All / Restore Selection -> only `a.txt` selected.

## Log

- 2026-10-20 — created (source leftover:252)
- 2026-10-20 — moved to Person steps position 4
- 2026-10-20 — feature 271: the same Paste check is owed for a ZIP made on Windows holding a.txt (lower) and A.txt (UPPER) - fixture as in specs/271-zip-case-twins/probe/zip271_probe.ps1 (.NET ZipArchive)
