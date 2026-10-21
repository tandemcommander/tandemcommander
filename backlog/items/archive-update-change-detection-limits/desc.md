---
title: Archive Update: a changed member can go unmarked or be marked needlessly
type: bug
status: blocked
severity: 3
area: archives
source: review:153
who: agent
created: 2026-10-14
updated: 2026-10-21
verified: 2026-10-21 ded1c8a7
effort: M
feature: -
related: [archive-ops-repointed-name-recorded-gaps]
depends-on: []
reason: split: three limits of different kind, the member part needs a maintainer decision; agent 2026-10-21
---

# Archive Update: a changed member can go unmarked or be marked needlessly

## Problem

Feature 153 marks, in the Archive Update dialog, a file whose member changed in the archive since its F4. Recorded limits: (1) an archive or member rewritten with the same size and time is not told apart (FAT 2 s times, `7z -stl`) - the warning is missing; (2) a daylight-saving / time-zone change between the F4 and the update can mark a member needlessly (the ZIP plug-in converts DOS times with the current offset); (3) a changed archive is listed twice on the refresh path (once by the check, once by the reopen) - a cost on large archives.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 8 (L263) (at 7993914c). specs/153-archive-member-changed-warning/fix-log.md, *Review*, "LOW - recorded"; probe row `x-same-stamp` (*Probe findings on the way*) records limit (1).

## Expected

A member rewritten with the same size and time is detected (e.g. by its CRC where the format has one); a time-zone change alone marks nothing; the refresh lists a changed archive once.

## Approach

Measure each limit with 153's probe first; (1) may need the CRC from the listing, which not every format or plug-in gives.

## Notes

Also recorded there, not in NEXT-WORK: `GetFiles(ZIPRoot)` finds folders by the code-page fold (pre-existing, the panel's lookup - follows the B-2 listing decision of 2026-10-04).

Trade-off recorded by feature 112's review (SF1; NEXT-WORK §5 queue 108, entry 2a, L1475-1481 at 7993914c): an UNTOUCHED tracked copy is pinned too - after another program changed that member in the archive, the panel (not refreshed) shows and edits the old content until Ctrl+R or leaving the archive (before 112 its next F3 / F4 re-extracted the new one); telling "untouched" from "editor open with unsaved work" by the F4 stamp could lose an edit (2-s FAT times, tools restoring the write time). The per-member warning of 153 covers it at the update; limit (1) above applies to it as well.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-17 — migration review N4: 112 SF1 trade-off added to Notes
- 2026-10-21 — verified at ded1c8a7: limit 1 reproduced at ded1c8a7: 153 probe row x-same-stamp plain (x-changed control marked); limits 2-3 by reading
- 2026-10-21 — blocked: split: three limits of different kind, the member part needs a maintainer decision; agent 2026-10-21
- 2026-10-21 — split into: archive-update-same-stamp-member-decision, archive-update-archive-same-stamp, archive-update-time-zone-change-mark, archive-refresh-lists-changed-archive-twice
