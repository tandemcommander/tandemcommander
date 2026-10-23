---
title: Pack with a relative archive name that starts with a space drops the space
type: bug
status: in-progress
severity: 4
area: archives
source: measure:316
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: 2026-10-23 d526127f
effort: S
feature: 317
related: []
depends-on: []
reason: -
---

# Pack with a relative archive name that starts with a space drops the space

## Problem

The Pack dialog (Alt+F5) offers the focused name + the archive extension as a relative archive
name. For a file or folder whose name starts with a space (` report`) the entry shows
` report.zip`, but OK turns it into `<panel path>\report.zip`: `SalGetFullName` drops the leading
spaces of a relative name unless its `allowRelPathWithSpaces` is TRUE. The archive is written under
another name than the one shown; when `report.zip` already exists, the "Add or Overwrite?" question
is about that other archive. The same applies to a typed relative name with a leading space.

## Evidence

By code reading at 34591cd5 (feature 316, which fixed the same defect in Unpack):
`CFilesWindow::Pack` (`src/fileswn7.cpp`, after `dlg.Execute() == IDOK`, "adjust the archive name to
its full form") calls `SalGetFullName(fileBuf, &errTextID, Is(ptDisk) ? GetPath() : NULL, nextFocus)`
with the default `allowRelPathWithSpaces = FALSE`; `SalGetFullName` (`src/salamdr3.cpp`, the
relative branch) joins `curDir` with the name from after its leading spaces. Feature 316 measured the
Unpack twin on the hidden desktop (`specs/316-unpack-subdir-space/probe/unpack316_probe.ps1`, rows
space-sd / typed-space: before into the folder without the space).

## Expected

OK packs into the archive the entry shows (the leading space kept), or the program refuses with a
message - never into a differently named archive. A probe row with such a name, before FAIL / after
PASS.

## Notes

- Not verified on the build: the Pack path was read, not driven; measure first (the archive name
  goes through more steps than Unpack's target - plug-in packers, external archivers, the
  "Add or Overwrite?" question).
- Unsure of the band; the lower value chosen. With an existing `report.zip`, Overwrite would replace
  an archive the dialog never named (asked first, so not silent) - triage may raise it.

## Log

- 2026-10-23 — created (source measure:316)
- 2026-10-23 — moved to Next position 2
- 2026-10-23 — verified at d526127f: reproduced at d526127f: hidden-desktop pack probe, 5 leading-space rows packed into the trimmed name, an existing report.zip got Add
- 2026-10-23 — run started, feature 317
