---
title: Archive operations through a re-pointed name: four gaps recorded by 145 / 146
type: bug
status: open
severity: 2
area: archives
source: leftover:146
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Archive operations through a re-pointed name: four gaps recorded by 145 / 146

## Problem

Features 145 and 146 refuse an archive operation when the archive's name now leads elsewhere than when the panel listed it (a re-pointed SUBST or network drive letter). Their reviews recorded gaps that never reached NEXT-WORK: (1) a paste of items copied from an archive whose panel then left it or was already reopened onto the other archive extracts the other archive's members (copy out only - nothing in either archive changes); (2) where `GetFinalPathNameByHandle` is not supported by the redirector, the check falls open and only the volume serial of 144's identity remains; (3) the `IDS_ARCHIVEREFRESHEDIT` note does not say that the operation was not done (needs a string); (4) from 145: a mapped drive reconnected under another server spelling, a folder mount given a letter, or possibly a DFS failover give another final path for the same archive - one false refusal of the pack (the edit can be copied) and one reopen, no loop; the refusal does not say why (needs a string).

## Evidence

`specs/146-archive-ops-repointed/fix-log.md` L44-47 ("Recorded: a paste of items copied from an archive whose panel left it or was already reopened ... the check falls open where `GetFinalPathNameByHandle` is not supported ... NIT: the note does not say the operation was not done (needs a string)"); `specs/145-pending-edits-repointed/fix-log.md` L47-50 ("Recorded, not changed"); `specs/FEATURE-HISTORY.md` entries `145-pending-edits-repointed` ("Left: ... false refusals after a server re-spelling / DFS failover") and `146-archive-ops-repointed` ("Left: paste of items copied before the panel left / reopened; no final path from the redirector = only the volume serial"). Code: `CFilesWindow::RefuseOperationIfArchiveMoved`, `ArchiveNameLeadsElsewhere` (145), the paste in `salshlib.cpp`. Found by the review of the migration (`specs/242-backlog-system/ledger/review.md`, N9).

## Expected

Either each gap is closed (the paste checks the source archive's identity; the refusal and the note name the reason), or the maintainer accepts them and the item is rejected with that reason. No gap loses data: (1) only copies out, (2) is the pre-145 behaviour, (3) and (4) are wording.

## Approach

Measure with 109's probe (`resubst-*` cases) first; the two texts need new strings (the two-stage `.slt` refresh, 084).

## Notes

Severity 2: no data loss in any of the four; a wrong copy out (1) is the worst outcome.

## Log

- 2026-10-17 — created (source leftover:146)
- 2026-10-17 — moved to Next position 56
- 2026-10-17 — title: four gaps (146 x3, 145 x1)
- 2026-10-17 — body written from the fix-logs of 145 and 146 (migration review N9)
