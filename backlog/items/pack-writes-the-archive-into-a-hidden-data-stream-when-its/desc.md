---
title: Pack writes the archive into a hidden data stream when its name holds a colon
type: bug
status: in-progress
severity: 4
area: archives
source: measure:318
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: 2026-10-23 e9c35c2e
effort: S
feature: 319
related: []
depends-on: []
reason: -
---

# Pack writes the archive into a hidden data stream when its name holds a colon

## Problem

A user who types an archive name containing a colon in the Pack dialog (Alt+F5), e.g. `report:zip`
or `rep:x.zip`, gets no archive they can find: the ZIP plug-in creates an empty file `report` (or
`rep`) in the panel's folder and writes the archive into its NTFS alternate data stream
(`report:zip.zip`), invisible to Explorer and to the panel. With an existing file of that name the
archive is attached to it as a hidden stream.

## Evidence

Measured in feature 318 (`specs/318-pack-name-trailing-dot/fix-log.md`, *Out of scope*), on the
build of branch `318-pack-name-trailing-dot` (Debug x64), with a scratch copy of
`specs/318-pack-name-trailing-dot/probe/pack318_probe.ps1` whose rows were replaced by
`oos-colon` (`report:zip`) and `oos-colon-ext` (`rep:x.zip`): the ZIP plug-in's "Create New
Archive" box named `...\src\report:zip.zip` / `...\src\rep:x.zip`; the only new file under the row
was an empty `src\report` / `src\rep` (first byte -1 through a plain path). `a*b.zip` and a name
ending in a tab were refused by the ZIP plug-in ("Cannot access file. ... syntax is incorrect"),
nothing created.

Site: `CFilesWindow::Pack` (`src/fileswn7.cpp`, after `dlg.Execute() == IDOK`) - after
`SalGetFullName` only `SalPackNameIsNotKeptAsTyped` (`src/common/salpackname.h`, 318: trailing dot
or space, device names) is checked; `SalGetFullName` treats `:` as a drive only at the second
character, so `report:zip` stays a relative name.

## Expected

OK on an archive name whose last part holds a `:` is refused with a message, the dialog again;
nothing is created or changed. A probe row per case (`report:zip`, `rep:x.zip`, an existing file
`report` + `report:zip`), before FAIL / after PASS; a drive-letter name (`C:\x.zip`, `C:x.zip`)
unchanged.

## Notes

- Severity 4: nothing is lost (an existing file's main content is unchanged), but the archive
  cannot be found by ordinary means; a user rarely types a colon. Unsure of the band - the lower
  value chosen.
- Other packers (7-Zip, external archivers) not checked. Other characters Windows forbids
  (`* ? < > | "`) were refused by the ZIP plug-in for `*`; the rest not measured.

## Log

- 2026-10-23 — created (source measure:318)
- 2026-10-23 — moved to Next position 2
- 2026-10-23 — verified at e9c35c2e: reproduced at e9c35c2e: hidden-desktop probe 6 FAIL - report:zip, rep:x.zip, abs:x.zip create an empty base file and write the archive into its data stream
- 2026-10-23 — run started, feature 319
