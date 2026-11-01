---
title: Share list: a list a server never finishes (more data without an end) is shown as if it were whole
type: bug
status: open
severity: 2
area: panels-ui
source: review:373
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Share list: a list a server never finishes (more data without an end) is shown as if it were whole

## Problem

The share list of feature 125 (`\\server\` in Change Directory, and the way up of 284) stops reading when a server keeps answering "more data" without an end (no entries in a round, or 1000 rounds). The comment says such a list is reported as an error "rather than shown as one", and the job sets its error to `ERROR_MORE_DATA` - but when the earlier rounds gave shares, `PickServerShare` shows them as the whole list: `SalUncShareListStep` offers any non-empty list and ignores the error. The same holds for a later round that fails with any other error after shares were read. The user picks from an incomplete list without being told. Found by the independent review of feature 373 (NOTE 2); older than 373 (125/285).

## Evidence

- `src/shares.cpp` at 186a485d, `CUncSharesJob::Read`: the loop stop `if (res == ERROR_MORE_DATA && (read == 0 || ++rounds >= 1000))` (L574) and `Error = firstErr; // a list without an end (see the loop): not shown as if it were whole` (L637).
- `src/common/saluncserver.h` at 186a485d, `SalUncShareListStep` (L197): `if (count > 0) return SALUNC_LIST_SHOW;` before the error is looked at.
- `src/fileswnb.cpp`, `CFilesWindow::PickServerShare`: `step = SalUncShareListStep(job->Count, job->Error, ...)`.
- Not reproduced: needs a server (or a seam) that answers `ERROR_MORE_DATA` endlessly after a first round with shares; the Debug seam `TC_PROBE_UNC_SHARES` / `_ERROR` of 125 cannot express "shares and then an error".

## Expected

A share list that was not read to its end is not offered as if it were complete: either the error is shown (as the comment says), or the list is offered with a visible note that it is incomplete - the maintainer's or the feature's choice; a pure rule in `src/common/saluncserver.h` with saltests checks.

## Log

- 2026-11-01 — created (source review:373)
- 2026-11-01 — related item wsl-localhost-offers-no-share-list done in feature 373
- 2026-11-01 — moved to Next position 133
