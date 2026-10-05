# Feature Specification: a flush of the disk cache never throws away a pending edit

**Feature Branch**: `112-cache-pending-edit`
**Created**: 2026-10-05
**Status**: Implemented, GUI runs pending
**Input**: `specs/NEXT-WORK.md` item 5, queue entry 2a (found by 109's review: "a flush marks a copy
with a pending edit out of date") and queue entry 3 (`AddFile` returning FALSE on low memory makes
`ExecuteFromArchive` release the copy the editor is using). Phase-0 research done before the work
(`research.md`, read-only, recommends design (b)); the maintainer asked for autonomy.

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the premise right? -> A: Yes (`research.md` 1-2). When both panels show one archive and the
  left panel (L) has a file opened for editing that it has not packed back yet, a flush of the
  archive's temporary copies by the right panel (R) - after R packed its own edits (leave, reopen,
  exit of that archive), or after R reopened the archive because another program changed it - marks
  L's copy out of date. The next look-up of that member (F3 or F4, in L) deletes L's copy and
  extracts the member over it. If the member did not change in the archive, the new copy has the
  stamp L recorded, so nothing is offered when L leaves: the edit is lost without a word (every
  release). The window is open only while L does not refresh in between (L's own refresh packs
  first): automatic refresh off for the drive type, a share without change notifications, Ctrl+R in
  R. Not reachable: an archive operation (both panels pack first), exit (sequential), one panel alone.
- Q: Which design? -> A: (b) of `research.md` 3: the panel's lock on a copy it tracks for editing
  becomes an explicit core-only EDIT lock (`crtCacheEdit`); a flush that meets a copy holding an edit
  lock does not mark it out of date but remembers "stale after edit", and the mark is set when the
  last edit lock goes (the panel packed or declined to pack) - then an unused copy is deleted at
  once, exactly as an out-of-date copy always was. (a) - the cache asking the panels' lists - has the
  wrong layering and needs a second lock across threads; (c) - refusing to re-create a modified copy
  - would change the plug-ins' cache semantics (FTP / SFTP view copies) and relies on time stamps.
- Q: What does a look-up see meanwhile? -> A: In L, the copy as it is, with the pending edit. R shares
  that copy only while it shows the archive L listed (one key = one copy since 109): after its own
  update or after another program changed the archive, R's reopen finds a size/time other than L's
  listing and gets a key of its own (109, `SalArchiveCacheKeyChoice` -> unique), so R's F3 / F4 show
  the archive's current member, never L's pending copy. When the member itself changed in the
  archive, L still sees its copy of the OLD member until L refreshes or leaves; L's update then
  overwrites the external change after the usual "Archive has changed" notice and the Archive Update
  list (the 096 behaviour). A per-member warning ("this file changed in the archive since you opened
  it") needs a new string and a dialog change: recorded as a follow-up, not part of 112.
- Q: A tracked copy that was never changed (review SF1)? -> A: Pinned too - the trade-off of the
  design, accepted and recorded. L F4 `x.txt`, closes the editor without saving; another program
  changes `x.txt` in the archive; R reopens (Ctrl+R) and flushes; L does not refresh: L's F3 shows the
  OLD `x.txt` (before 112: the new one), and a second F4 in L edits the old content, whose update on
  leaving overwrites the external change (before 112 that F4 re-extracted the new `x.txt`). The pin
  cannot tell "an editor is open with unsaved work" from "untouched": re-creating a copy whose file
  still has the F4 stamp would extract over an open editor's file (its later save then overwrites the
  new member anyway) and over an edit that kept size and time (FAT's 2-second times, a tool that
  restores the write time) - it could lose an edit, so it is not done (evaluation in `fix-log.md`).
  Ctrl+R or leaving the archive in L ends it (L packs nothing for an untouched copy, the deferred
  mark drops it, the next F3 / F4 extracts the new member). The per-member warning follow-up would
  cover this case too.
- Q: Plug-ins? -> A: Unchanged. Only `CFilesWindow::ExecuteFromArchive` passes the new lock type; the
  plug-in services pass `crtCache` / `crtDirect` (and their keys never meet the core's archive keys);
  for a record without an edit lock the new rule is the old one step by step (saltests: random
  sequences, 0 mismatches). No plug-in interface change (107), no registry change, no new string.
- Q: Queue entry 3 (`AddFile` on low memory)? -> A: `CFileTimeStamps::AddFile` returns three results
  (added / already tracked / failed). `ExecuteFromArchive` reads the copy's stamp, tracks it and
  gives it the edit lock BEFORE the editor or the association is launched; a copy that cannot be
  tracked (low memory, or a failed lock) is released and not edited - the existing "Insufficient
  memory." text (`IDS_PACKERR_NOMEM`) is shown. This also fixes a third defect found by the research:
  for a copy that already existed (F3 first, or the other panel's copy) the stamp was read AFTER the
  launch, so an editor that wrote before that read made its own edit part of the stamp and the edit
  was dropped as "unchanged". Refreshes are held (`BeginStopRefresh`) from the tracking to the end of
  the launch, so the request that used to keep the copy on disk during the launch is not needed.
- Q: Persistence, strings? -> A: None. In memory only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An edit pending in one panel survives the other panel's archive update (Priority: P1)

Both panels show `t.zip`. In the left panel the user edits `x.txt` (F4) and saves. In the right
panel the user edits `y.txt` and leaves the archive (Update). Back in the left panel the user views
or edits `x.txt` again, then leaves the archive.

**Why this priority**: silent data loss in every release.

**Independent Test**: probe rows `own-F3`, `own-F4` (and `@net`, `_7z`).

**Acceptance Scenarios**:

1. **Given** the pending edit of `x.txt` in L and R's update of `y.txt`, **When** L presses F3 on
   `x.txt`, **Then** the viewer shows the edited `x.txt`, and leaving the archive in L offers `x.txt`
   for the update; the archive ends with both edits.
2. **Given** the same, **When** L presses F4 on `x.txt` again and adds a second edit, **Then** both
   edits of L reach the archive.

### User Story 2 - An edit pending in one panel survives the other panel's reopen of a changed archive (Priority: P1)

Another program rewrites `t.zip` while L has a pending edit of `x.txt`; the user refreshes R
(Ctrl+R); then L looks at `x.txt` again.

**Independent Test**: probe rows `ext-ctrlR`, `ext-x` (and `@net`).

**Acceptance Scenarios**:

1. **Given** the archive was rewritten with the same `x.txt`, **When** L presses F3 on `x.txt`,
   **Then** the edited copy is shown and L's leave offers `x.txt`.
2. **Given** the archive was rewritten with a different `x.txt`, **When** L presses F3, **Then** L's
   edited copy is shown, L's leave offers it, and the update writes it (documented: it overwrites the
   external change, as before when L refreshed first).

### User Story 3 - A file opened for editing is always tracked (Priority: P2)

**Acceptance Scenarios**:

1. **Given** the copy already exists (F3 first), **When** F4 starts an editor that writes at once,
   **Then** leaving the archive offers the file (row `stamp-race`).
2. **Given** the copy cannot be tracked (low memory), **When** F4 is pressed, **Then** the editor is
   not started and "Insufficient memory." is shown - the editor never works on a copy that is deleted
   under it (code reading; not drivable without fault injection).

### Edge Cases

- Both panels track one copy (row `shared`): the stale mark waits for the second edit lock.
- A flush between the look-up and the edit lock (during the extraction): the mark is taken over as
  the deferred one; the fresh copy is not cached.
- Critical shutdown with changed files: the edit locks are never released (as before); the copies
  stay on disk for a manual repack.
- An untouched tracked copy is pinned as well (Clarification "never changed"): L sees the old member
  until it refreshes or leaves.
- R re-entering a changed archive: since 109 R gets a unique key (size/time differ from L's listing),
  so R never meets L's copy (row `own-reenter`, both builds).
- Own-delete archiver plug-ins (S10 of `research.md`): pre-existing queued-delete race, recorded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A flush of the disk cache MUST NOT mark out of date, delete or re-create a temporary
  copy that a panel tracks for packing back into its archive.
- **FR-002**: When the last panel lets go of such a copy, a flush that met it meanwhile MUST take
  effect then (the copy is re-created on its next use, or deleted when nothing uses it).
- **FR-003**: A copy without an edit lock (viewers, plug-ins) MUST behave exactly as before.
- **FR-004**: `ExecuteFromArchive` MUST record the copy's stamp and track it before launching the
  editor or the association, and MUST NOT launch them for a copy it could not track.
- **FR-005**: No plug-in interface, registry or string change.

### Key Entities

- **Edit lock**: the panel's `ExecuteAssocEvent` on a copy it tracks in `CFileTimeStamps`
  (`crtCacheEdit`, `CACHE_LOCK_EDIT`).
- **Deferred out-of-date mark**: `CSalCacheEditPin::StaleAfterEdit` (`salcacheedit.h`).

## Success Criteria *(mandatory)*

- **SC-001**: Probe loss rows (`own-F3`, `own-F4`, `own-F3_7z`, `ext-ctrlR`, `ext-x`, each also
  `@net` where defined) PASS on this build and FAIL on `Debug_x64_pre112` (or are CLOSED on both,
  with the `@net` variant then carrying the evidence).
- **SC-002**: Controls (`*-auto`) detect L's refresh on both builds; `own-reenter`, `shared` PASS on
  both builds; regressions 109 diskcache, 108 namecoll, 096 archedit unchanged.
- **SC-003**: saltests 14,169 -> 14,236 / 0; strict encoding guard TOTAL 0; Debug and full Release
  builds succeed.
