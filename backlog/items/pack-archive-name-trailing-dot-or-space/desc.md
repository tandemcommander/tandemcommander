---
title: Pack creates an archive with a trailing dot or space Windows tools cannot open
type: bug
status: new
severity: 4
area: archives
source: measure:317
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Pack creates an archive with a trailing dot or space Windows tools cannot open

## Problem

The Pack dialog (Alt+F5) passes the archive name to the packer as typed after `SalGetFullName`.
The ZIP plug-in opens the archive through a `\\?\` path, where Windows does not trim trailing dots
and spaces, so a name ending in a dot or a space (`report.`, `report.zip `) - or a reserved device
name (`CON.zip`) - is created as a literal file that Explorer and most programs cannot open, rename
or delete. Feature 317 refuses only a last part made of spaces and dots alone (` ..`, ` .`).

## Evidence

Measured in feature 317 (`specs/317-pack-name-space/fix-log.md`, *Change* step 2): with the leading
space kept and before the refusal, probe rows typed-space-dots / typed-space-dot
(`specs/317-pack-name-space/probe/pack317_probe.ps1`) created files literally named ` ..` and ` .`
in the panel's folder. `CFilesWindow::Pack` (`src/fileswn7.cpp`, after `dlg.Execute() == IDOK`)
checks the name only with `SalPackNameIsOnlyDotsAndSpaces` (`src/common/salpackname.h`); the core's
own name rule `SalIsValidFileNameComponent` (`src/salamdr5.cpp`) rejects trailing dots / spaces and
device names but is not applied to the archive name.

## Expected

OK on an archive name whose last part the file system would not keep as typed (a trailing dot or
space, a device name) is refused with a message, the dialog again - never a literal file Windows
tools cannot handle. A probe row per case, before FAIL / after PASS.

## Notes

- Not verified on the build: `report.`, `report.zip ` and `CON.zip` were not driven - inferred from
  the measured ` ..` row (same `\\?\` route in the ZIP plug-in). External archivers not checked.
- Unsure of the band; the lower value chosen (no data is lost, the user typed the name).

## Log

- 2026-10-23 — created (source measure:317)
