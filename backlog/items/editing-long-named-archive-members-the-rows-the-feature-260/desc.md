---
title: Editing long-named archive members: the rows the feature-260 probe could not drive
type: person-step
status: new
severity: 6
area: archives
source: leftover:260
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Editing long-named archive members: the rows the feature-260 probe could not drive

## Problem

Feature 260 made F3 / F4 of archive members with long names work and changed how the edited copy goes back into the archive (`CFileTimeStamps::CheckAndPackAndClear` holds the copy's path whole; `CopyFilesTo` - the Archive Update dialog's "Copy selected to..." - takes long names; the start-up cleanup of temporary folders walks long names). Two of these paths could not be driven by the hidden-desktop probe: a copy path over 620 bytes needs a %TEMP% of about 88+ bytes (the program regenerates its environment from the user's registry, so a probe cannot give it another TEMP), and "Copy selected to..." needs the folder browser. The first guards against an edit being dropped as "unchanged".

## Evidence

`specs/260-archive-cache-long-names/fix-log.md`, *Review* (review 1, S1 and S3). Probe `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` drives EDITLONG only with the system %TEMP% (a 319-byte copy path).

## Expected

Each step below done once on a Debug or Release build with feature 260 and its result recorded; a failure becomes an item of its own.

## Notes

Changing TEMP / TMP in the user environment (System Properties - Environment Variables) affects every program started afterwards: set it back when done.

## Steps

- [ ] Set the user's TEMP and TMP to an existing folder `C:\T\` + 35 Chinese letters (about 110 bytes, 40 characters), sign out and in (or restart the program). In a ZIP holding a member of 170 Chinese letters + `.txt` (514 bytes; the copy's path is then about 637 bytes / 227 characters), press F4, change the text in the editor and save, close the editor, leave the archive -> the Archive Update question appears; OK -> the archive holds one member under the whole name with the change.
- [ ] Same setup, F4, change and save, leave the archive, in the Archive Update dialog choose "Copy selected to..." and a short folder -> the edited file appears there under its whole name; with a target folder so deep that the full path passes 259 characters -> "too long name", the dialog stays and nothing is lost.
- [ ] Same setup, F4 on the long member, then end the program from Task Manager; start it again -> the question about temporary folders left behind; answer delete -> the SAL*.tmp folder with the long-named copy is gone (it does not come back at the next start).
- [ ] Set TEMP / TMP back to their previous values.

## Log

- 2026-10-20 — created (source leftover:260)
