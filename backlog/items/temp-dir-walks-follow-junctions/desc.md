---
title: SFX temp cleanup and the external unpacker's walk follow junctions
type: bug
status: in-progress
severity: 7
area: data-safety
source: review:212
who: agent
created: 2026-10-15
updated: 2026-10-19
verified: 2026-10-19 1c8140a0
effort: M
feature: 249
related: []
depends-on: []
reason: -
---

# SFX temp cleanup and the external unpacker's walk follow junctions

## Problem

Left by the review of feature 212: the ZIP self-extractor's own `_RemoveTemporaryDir` (`selfextr.cpp:157`) has the same defect 212 fixed in the core (walks into a junction, deletes the target's files; `A` calls); the external unpacker's walk `pack1.cpp:632-692` moves the extracted folder's content out - a junction extracted from the archive would have its target's content moved (rule 099), to be measured. Also owed: driving 212 itself (the start-up `SAL*.tmp` sweep with a junction inside), done only by reading.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L794-798. Feature 212 (`specs/212-temp-dir-links/`), rule 099 (`ScanMoveSelectionForDirLinks`).

## Expected

Neither cleanup nor the external unpacker's walk follows a junction / directory link: a link is removed as a link, never walked; a probe shows 212's sweep and the unpacker leave a junction's target intact.

## Approach

Measure the `pack1.cpp` walk first (an archive containing a junction, an external unpacker).

## Notes

Severity 7 (data loss, narrow) if the unpacker walk is reachable - not measured. The self-extractor is not shipped (NW §C: no SFX package), which may make `selfextr.cpp` unreachable. The rank (first in *Next*) presumes the worst case: measure first, then re-rank by the measurement (lower it if the `pack1.cpp` walk does not follow a junction).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
- 2026-10-17 — migration review N7: re-rank after the measurement (Notes)
- 2026-10-19 — verified at 1c8140a0: probe at 1c8140a0: a junction restored by an external unpacker (fake 7z) made the subfolder walk move the target files into the panel target; 212 sweep driven, target kept; selfextr not built
- 2026-10-19 — run started, feature 249
