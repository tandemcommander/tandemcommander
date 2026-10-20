# Tasks: Long names - Paste copy name, Edit New File, simple-selection conversion

**Input**: `specs/259-long-name-refusals/` (spec.md, plan.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: saltests checks for the pure rule (CLAUDE.md working method) and the hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Start `specs/259-long-name-refusals/fix-log.md` with the measurement of 7a13bdee (probe result_before.txt 7 / 3, the readings of fileswn6.cpp and shellib.cpp)

## Phase 2: Foundational

- [ ] T002 Enumerate the consumers of the three sites (callers of `BuildScriptMain2` with `MakeCopyOfName`, of `EditNewFile`, of `IsSimpleSelection` and readers of `CDragDropOperData::SrcPath`) and record them in specs/259-long-name-refusals/fix-log.md

## Phase 3: User Story 1 - Edit New File in long paths (P1)

**Goal**: a typed name or path up to the program's limit is created whole.
**Independent test**: probe rows SHORT, REL, ABS, CJK, OVER.

- [ ] T003 [US1] In `CFilesWindow::EditNewFile` (src/fileswn5.cpp) drop the `strlen(path) >= MAX_PATH` refusal, call `SalGetFullName` with `SAL_MAX_PATH_UTF8`, refuse a full path that reaches `SAL_MAX_PATH_UTF8` with `IDS_TOOLONGPATH`, make `checkPath` `SAL_MAX_PATH_UTF8`; update the feature-141 comment
- [ ] T004 [US1] Build, run the probe specs/259-long-name-refusals/probe/editnew259_probe.ps1 with label after (result_after.txt) - all rows PASS

## Phase 4: User Story 2 - Paste copy name (P2)

**Goal**: the copy name is built whole; too long -> the "name is too long" question, never "to itself".
**Independent test**: `TestCopyName259` in saltests.

- [ ] T005 [P] [US2] Write `src/common/salcopyname.h` (`SalMakeCopyNameU8`, `SAL_COPYNAME_OK` / `SAL_COPYNAME_TOOLONG`) per contracts/copy-name-rule.md; list it in src/vcxproj/saltests/saltests.vcxproj
- [ ] T006 [US2] Add `TestCopyName259` to src/saltests/saltests.cpp: the Explorer patterns (file, folder, extension with a space, "(n)" before / inside the extension, attempt 1 / 2 / 10), 84 CJK letters + ".txt" OK, a candidate of exactly 255 units OK and 256 TOOLONG, an emoji counted two units, a small `outSize` TOOLONG; run a negative control with a 260-byte limit and record it
- [ ] T007 [US2] In `CFilesWindow::BuildScriptMain2` (src/fileswn6.cpp) replace the Vista branch's assembly by `SalMakeCopyNameU8` into a whole buffer; a TOOLONG result or a full path reaching `SAL_MAX_PATH_UTF8` sets `copyNameTooLong`; the pre-Vista branches set it where they dropped the result, with a guard that their 260-byte writes stay inside `targetPath`; on `copyNameTooLong` call `BuildName(..., TRUE)` - Skip continues with the next item, otherwise the build ends (FALSE)

## Phase 5: User Story 3 - Simple selection without code page (P3)

**Goal**: no CP_ACP / raw-byte / cut name; a too long folder says "too long".
**Independent test**: by reading; ordinary paste / drop unchanged (build + existing probes of the area not needed - no behaviour change for real names).

- [ ] T008 [P] [US3] Add `BOOL SrcPathTooLong` to `CDragDropOperData` (src/shellib.h), initialised FALSE
- [ ] T009 [US3] In `IsSimpleSelection` (src/shellib.cpp) wide branch: folder by `SalWToU8Alloc` - NULL refuses, too long sets `SrcPathTooLong`; names by `SalWToU8Alloc` - NULL refuses; remove `mulbyteName` and both CP_ACP calls. ANSI branch: a failed folder / name conversion refuses, a too long folder sets `SrcPathTooLong` (no raw bytes, no `lstrcpyn` cut)
- [ ] T010 [US3] In `CFilesWindow::DragDropToArcOrFS` (src/fileswna.cpp) show `IDS_TOOLONGPATH` (title Copy / Move error) when `SrcPathTooLong` before the Unicode message

## Phase 6: Polish

- [ ] T011 Encoding guard `python tools/check_encoding.py --strict` - TOTAL 0; `.\build.cmd`; saltests 0 failed
- [ ] T012 Record before / after, the commands and results, the limits (the focus of a new name of 260+ bytes; the paste rows owed to a person) in specs/259-long-name-refusals/fix-log.md

## Dependencies

T001 -> T002 -> (US1: T003 -> T004), (US2: T005 -> T006 -> T007), (US3: T008 -> T009 -> T010) -> T011 -> T012.
The three stories touch different files and are independent; T005 and T008 can run in parallel.

## Implementation strategy

MVP = US1 (the measured failure). Then US2 (rule first, then the call site), then US3.
