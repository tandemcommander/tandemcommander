# Fix log: 145 - a pending edit is never packed into the archive a re-pointed name leads to

Backlog: `specs/NEXT-WORK.md` A.2a (found by the review of 144).

## Before (`probe/result_pre145.txt`, `Debug_x64_pre145` = the source at `83727d38`)

- `resubst-pending`: **FAIL** - the edit of A's x.txt packed into `B\arc.zip` (B's member replaced).
- `resubst-refresh` (review): **FAIL** - the refresh after the re-point did not reopen; F3 then gave
  the EDITED copy of A's x.txt in B's name, and leaving packed it into B.
- `resubst-back` (review): **FAIL** - no refusal at all, packed into B.
- `replace-pending` (control: the archive replaced at the same place by a renamed new file): PASS.

## Work

- `SalGetFinalPathOfHandleU8Alloc` (salfileio): split out of 107's `SalGetFinalPathU8Alloc`
  (which keeps its behaviour: one open, one close).
- The panel keeps `ZIPArchiveFinalPath` from the open's handle (with the date, size and 144's
  identity), forgotten by `SetZIPArchive`; `ArchiveNameLeadsElsewhere(name, handle)`: TRUE only
  when both final paths are known, the name is the panel's archive, and they differ.
- The refresh's "archive changed?" test: `|| ArchiveNameLeadsElsewhere(archive, file)`.
- `CheckAndPackAndClear`: `!Panel->ArchiveNameLeadsElsewhere(ZIPFile, NULL)` before
  `PackCompress` - a refusal goes the failed-pack way (`IDS_UPDATEFAILED`).

## After

- Debug build clean (old warnings only: `zip.cpp(5958)`, `salamdr2.cpp(1042/1050)` - also in the
  0.1.10 closing pass); `saltests` 21,829 / 0; `check_encoding.py` TOTAL 0.
- `probe/result_cases.txt`: `resubst-pending` **PASS** (A and B unchanged; the windows: the
  "about to close" note, Archive Update -> *Update All*, "Packing ... has failed. Try again?" ->
  No, Archive Update again - the probe then chose *Ignore All* and confirmed it, which discards
  the edit; a person has *Copy Selected To...* there); `replace-pending` PASS.

## Review (refute-first agent, 2026-10-14)

No critical finding. Taken over:

- MEDIUM (evidence): the refresh reopen and "letter back, then Try again" were not driven - probe
  cases `resubst-refresh` (step `refresh` must show "has changed. Archive will be reopened", F3
  gives B's x.txt) and `resubst-back` (Serve hook: the letter pointed back, then Yes - the edit
  reaches A); per-step `Want` expectations in the 109 probe.
- LOW: a symlinked archive with several pack groups - an archiver replacing the link by a file
  made the next group refuse: the final path is re-read after each successful pack
  (`RereadZIPArchiveFinalPath`).
- LOW: another volume mounted at the same letter keeps the DOS path - the volume serial of 144's
  identity is compared too (an in-place replacement keeps it).
- NIT: `INVALID_HANDLE_VALUE` treated as "no handle".
- Recorded, not changed: a mapped drive reconnected under another server spelling, a folder
  mount given a letter, maybe a DFS failover give another final path for the same archive - one
  refused pack (the edit can be copied) and one reopen, no loop; the refusal does not say why
  (needs a string); *Copy Selected To...* not driven (a folder dialog); millisecond
  time-of-check gaps.
- MEDIUM outside 145: F8 / F5 / F6 through a re-pointed name with the old listing -
  `specs/NEXT-WORK.md` 2b, feature 146.

## Final (the build with the review changes)

- `saltests` 21,829 / 0; `check_encoding.py` TOTAL 0.
- `probe/result_cases.txt`: the four cases **4 PASS / 0 FAIL** (control 1 / 3).
- `probe/result_109.txt`: the whole 109 probe **23 PASS / 0 FAIL / 0 NOT DRIVEN**.
- Regressions: 108 `namecoll` 30 / 0, `-CacheKeyRows` 2 / 0, 112 14 / 0.
