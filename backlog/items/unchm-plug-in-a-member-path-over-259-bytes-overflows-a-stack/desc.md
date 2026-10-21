---
title: unchm plug-in: a member path over 259 bytes overflows a stack buffer on F3 / F4
type: bug
status: parked
severity: 7
area: archives
source: measure:275
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: [unrar-plug-in-a-member-name-over-259-bytes-overflows-a-stack]
depends-on: []
reason: plug-in unchm not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-10-21
---

# unchm plug-in: a member path over 259 bytes overflows a stack buffer on F3 / F4

## Problem

The CHM plug-in (disabled in `plugins.cfg`, not shipped) copies the member's path inside the CHM file (`nameInArchive`, folders + name, UTF-8) into `char srcPath[MAX_PATH]` with an unbounded `lstrcpy` when F3 / F4 unpack one member. A member whose path inside the CHM has 260 bytes or more - e.g. a short page name inside folders with long or non-ASCII names - overruns the stack; it was reachable already under feature 095's 520-byte limit (260-519 bytes) and feature 275 lifted that limit. In the same function, when the target path does not fit `MAX_PATH` bytes the refused `SalPathAppend` leaves `ret = TRUE` (= `UNPACK_OK`), so F3 / F4 report success without a file and without a message.

## Evidence

At 97384331: `src/plugins/unchm/unchm.cpp` `CPluginInterfaceForArchiver::UnpackOneFile` - `char name[MAX_PATH]; strcpy(name, targetDir); ... if (SalamanderGeneral->SalPathAppend(name, lastComp, MAX_PATH)) { ... char srcPath[MAX_PATH]; lstrcpy(srcPath, nameInArchive); ... }` and `return ret == UNPACK_OK;` with `BOOL ret = TRUE;` (`UNPACK_OK` is 1, `src/plugins/unchm/chmfile.h`). By reading (audit of feature 275, `specs/275-arcmember-long-path/fix-log.md`, *Consumers enumerated*); not driven - the plug-in is not built in the default configuration. `ExtractObject` (`chmfile.cpp`) itself uses heap buffers.

## Expected

F3 / F4 of a CHM member take its whole path inside the CHM (heap buffer, or a refusal with a message - never a cut, never an overflow); a target path that does not fit is refused with a message and reported as a failure, not as success. To be fixed before the plug-in is enabled.

## Notes

The same kind of defect as the related unrar item (a parked item - plug-in not shipped). The 260-byte `name[MAX_PATH]` target limit also refuses valid copies of up to 259 UTF-16 units (feature 260's rule).

## Log

- 2026-10-21 — created (source measure:275)
- 2026-10-21 — moved to Parked: plug-in unchm not built or shipped (plugins.cfg off); fix before enabling it; auto-triage, maintainer 2026-10-21
