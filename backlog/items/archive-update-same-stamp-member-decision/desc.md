---
title: Archive Update: how to tell a member rewritten with the same size and time
type: decision
status: new
severity: 3
area: archives
source: manual
who: person
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: M
feature: -
related: [archive-update-change-detection-limits]
depends-on: []
reason: -
---

# Archive Update: how to tell a member rewritten with the same size and time

## Problem

Feature 153 marks, in the Archive Update dialog, a file whose member another program changed in the archive since the F4. It compares only the member's listed size and time. When the other program wrote different content with the same size and the same time (ZIP keeps DOS times of 2 s; tools that restore times), the line stays plain and "Update" overwrites that change without the warning. Telling it apart needs the content, which the core's listing does not carry: `CFileData` has no CRC, and neither the ZIP nor the 7-Zip plug-in shows a CRC column (`PluginData` is private to the plug-in).

## Evidence

Measured at ded1c8a7 (run of item `archive-update-change-detection-limits`, 2026-10-21): `specs/153-archive-member-changed-warning/probe/member_changed_probe.ps1 -Only x-same-stamp,x-changed,same` on the hidden desktop, Debug build - row `x-same-stamp` (x.txt another content, the size and time it had): x.txt's line plain; control `x-changed`: marked. Code: `CFileTimeStamps::MarkChangedInArchive` (`src/salamdr3.cpp` ~3763 at ded1c8a7) and `SalEditedMemberChangedInArchive` (`src/common/salarcedit.h`) compare size and time only; `CFileData` (`src/plugins/shared/spl_com.h` ~203) has no CRC; ZIP `main.cpp` ~840 and 7-Zip `7zip.cpp` ~1685 add only packed size / method columns.

## Expected

The maintainer chooses an option; the chosen work becomes a work item (or this part is rejected and the limit stays recorded in 153's history).

## Question

Should the Archive Update warning also catch a member rewritten with the same size and time, and at which cost?

## Options

- **A - a member's CRC from the plug-in (plug-in interface).** An append-only method (interface 109) that returns the CRC-32 of a listed member; ZIP and 7-Zip implement it; the F4 keeps the CRC with the stamp, the update compares it. Costs: a contract and an ABI change; external archivers, TAR, UnISO and older plug-ins stay at the limit; a ZIP member's CRC is of the stored data, fine for this purpose.
- **B - the core compares contents itself.** At the F4 the core hashes the freshly extracted copy (before the editor starts); at the update, only when the archive changed and a member's size and time are equal, it extracts that member again into a temporary folder and compares the hash. Works for every format without an ABI change. Costs: a second extraction per such member on each update after any change of the archive (time for large members, disk space, an encrypted archive may ask for the password again), more code on the update path.
- **C - keep the limit.** Nothing changes; the case needs another program to write different content with the same size and time while the member is open for editing. The update still packs exactly the user's edit.

## Recommendation

C - the case is rare and both A and B cost more than the warning is worth; the other parts of `archive-update-change-detection-limits` (the archive rewritten with the same stamp, the time-zone change) cover the realistic cases. If the maintainer wants it closed, B (no ABI change, every format).

## Log

- 2026-10-21 — created (source manual)
