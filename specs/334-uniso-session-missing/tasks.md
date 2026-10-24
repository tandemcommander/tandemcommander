# Tasks: A disc image with a track the ISO plug-in cannot open is kept by Unpack with "Delete archive after unpacking"

**Input**: Design documents from `specs/334-uniso-session-missing/` (plan.md, spec.md, research.md,
data-model.md, quickstart.md)
**Tests**: required by the project's rules - `saltests` for the pure rule (FR-006), the hidden-desktop
probe for the user stories (SC-001..SC-003).

## Phase 1: Setup

- [X] T001 Record the measurement at 21c3ce91 (rows, commands, traced sites) in specs/334-uniso-session-missing/fix-log.md and keep the probe (iso334_probe.ps1, mkimg334.sh, img334.py, result_before.txt) in specs/334-uniso-session-missing/probe/

## Phase 2: Foundational (the rule, blocking both stories)

- [X] T002 Write the pure rule `SalIsoTrackMarksListing(kind, outsideImage, outcome)` with its kind and outcome constants in src/common/salisotrack.h (header-only, UTF-8 BOM, English comments, data-model.md table)
- [X] T003 Add `TestIsoTrackMarks334` (every kind x outsideImage x outcome, an unknown outcome value fails closed) and its call in src/saltests/saltests.cpp; include "salisotrack.h"
- [X] T004 Add `BOOL OutsideImage` to `CISOImage::Track` (initialised FALSE in `Track::Track`) and `void MarkTrack(int track, int outcome)` to `CISOImage` in src/plugins/uniso/isoimage.h; include "../../common/salisotrack.h"
- [X] T005 In `CISOImage::Open` (src/plugins/uniso/isoimage.cpp) set `OutsideImage` for a track whose detection returns ERR_CONTINUE (it becomes fsData) when its sector 16 is not within the image file; implement `CISOImage::MarkTrack` (kind from FSType, the rule, `ListingLeftOut.SetIncomplete()`)

## Phase 3: User Story 1 - a multi-session image with a session that cannot be opened is kept (P1)

**Independent test**: probe rows M-TERM, M-PAST (kept), M-OK (deleted).

- [X] T006 [US1] In the multi-session branch of `CISOImage::ListImage` (src/plugins/uniso/isoimage.cpp) call `MarkTrack` for every tried track with its outcome (not opened / listing failed / listed); the box (`ret = FALSE` for a non-audio track that does not open) and the listing stay as they are

## Phase 4: User Story 2 - a single-session image whose last data track does not open is kept (P2)

**Independent test**: probe row S-TERM (kept), S-OK (deleted).

- [X] T007 [US2] In the single-session branch of `CISOImage::ListImage` (src/plugins/uniso/isoimage.cpp): when the last data track lists, `MarkTrack(track, NOT_TRIED)` for every other track; when it does not open, `MarkTrack(LastTrack, NOT_OPENED)` (LastTrack >= 0) and mark every track the fallback tries with its outcome

## Phase 5: Polish & verification

- [X] T008 `python tools/check_encoding.py --strict` -> TOTAL: 0; `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed; a mutant of the rule fails TestIsoTrackMarks334 (record in specs/334-uniso-session-missing/fix-log.md)
- [X] T009 Run specs/334-uniso-session-missing/probe/iso334_probe.ps1 (after) -> 10 / 0, save result_after.txt; negative controls: main (no marking at all, result_before.txt) fails M-TERM / M-PAST / S-TERM, the mutant without the outside-image clause (result_mutant_no_outside.txt) fails M-PAST
- [X] T010 Run the regression probes of 322, 329, 330, 333 (specs/<NNN>-*/probe/) and save their results as specs/334-uniso-session-missing/probe/regress_<NNN>.txt
- [X] T011 clang-format the changed sources (src/common/salisotrack.h, src/saltests/saltests.cpp, src/plugins/uniso/isoimage.h, src/plugins/uniso/isoimage.cpp) and complete specs/334-uniso-session-missing/fix-log.md (after, checks)

## Dependencies

T001 -> T002 -> T003, T004 -> T005 -> T006 (US1), T007 (US2) -> T008 -> T009, T010 -> T011.
US1 and US2 touch the same function: done one after the other.

## Parallel opportunities

T003 [saltests] and T004 [plug-in header] touch different files once T002 exists; T009 and T010 are
separate probe runs but share the registry key - run them one after the other.

## Implementation strategy

MVP = US1 (the item's main point). US2 follows in the same function; both are checked by one probe run.
