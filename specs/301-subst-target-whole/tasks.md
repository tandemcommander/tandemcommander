# Tasks: A subst drive's target is read whole or refused, never cut or in the code page

**Input**: Design documents from `specs/301-subst-target-whole/` (spec.md, plan.md, research.md,
data-model.md, quickstart.md)
**Tests**: `saltests` checks of the pure rule (stop-rules §2.5) and the hidden-desktop probe are
part of the feature (spec SC-001, SC-003).

## Phase 1: Setup

- [X] T001 Move the probe from the measurement scratch folder to `specs/301-subst-target-whole/probe/subst_probe.ps1`, the library path relative (`$PSScriptRoot\..\..\098-long-path-overruns\probe\fix_probe_lib.ps1`); keep `probe/result_before.txt` (7 / 2)

## Phase 2: Foundational (blocks every story)

- [X] T002 Create header-only `src/common/salsubst.h`: `SAL_SUBST_NONE` / `SAL_SUBST_OK` / `SAL_SUBST_TOO_LONG`, `SAL_SUBST_TEXT_U8_MAX` (3 * MAX_PATH + 1), `SalSubstTargetToPathU8(const WCHAR* device, char* path, int pathMax)` per data-model.md rules 1-4 (size measured with `SalWToU8(.., NULL, 0)` first, refused buffer emptied)
- [X] T003 [P] Add `TestSubstTarget301` to `src/saltests/saltests.cpp` (include `salsubst.h`, call from `main`): drive form, root form `\??\D:`, UNC form, a volume device / redirector / empty / NULL -> NONE, CJK target exact bytes, exact fit OK and one byte short TOO_LONG (both forms) with the buffer emptied, a 3 * (MAX_PATH - 1)-byte subst path fits `SAL_SUBST_TEXT_U8_MAX`, lone surrogate (WTF-8) converts
- [X] T004 In `src/salamdr2.cpp`: static `QueryDosDeviceWholeW(BYTE driveNum)` (heap, doubling on `ERROR_INSUFFICIENT_BUFFER` up to 64 Ki units); `MyQueryDosDevice` - whole read, size-measured `SalWToU8`, FALSE when it does not fit, the code-page `QueryDosDevice` removed; `GetSubstInformation(BYTE, char*, int, BOOL* tooLong)` via `SalSubstTargetToPathU8`; declaration in `src/consts.h` with `BOOL* tooLong = NULL`

## Phase 3: User Story 1 - Delete of a link on a subst drive with a long non-ASCII target (P1)

**Goal**: F8 on a junction of the CJK subst drive asks about a junction.
**Independent test**: probe rows CJK DEL / SHORT DEL / LONG DEL PASS.

- [X] T005 [US1] `ResolveSubsts` in `src/salamdr2.cpp`: pass `&tooLong`; a refused target -> `TRACE_E`, `ret = FALSE`, break (path unchanged); comment the feature

## Phase 4: User Story 2 - Drive Information shows the subst target whole (P2)

**Goal**: the drive type line holds the whole target or none of it.
**Independent test**: probe rows INFO PASS for SHORT, CJK, LONG.

- [X] T006 [US2] `CDriveInfo::Transfer` in `src/dialogs3.cpp`: the target into `char substTarget[SAL_SUBST_TEXT_U8_MAX]`; append "(subst: %s)" only when the composed line fits `volumeName`; `substInfo` TRUE for a subst drive also when the text is refused (no junction text instead)

## Phase 5: User Story 3 - Other users never see a cut or `?` path (P3)

**Goal**: Copy as UNC, the Change Drive menu, the bug report use the exact target or refuse.
**Independent test**: code reading of each caller + saltests; Copy as UNC is a person step.

- [X] T007 [P] [US3] `CopyUNCPathToClipboardAux` in `src/fileswn9.cpp`: pass `2 * MAX_PATH` (the buffer's size) and `&substTooLong`; a refused target sets `*tooLong`
- [X] T008 [P] [US3] `BuildData` in `src/drivelst.cpp`: `GetSubstInformation(.., volumeName, SAL_SUBST_TEXT_U8_MAX)` (include `salsubst.h` where needed); a refused target -> empty text
- [X] T009 [US3] Enumerate every caller of `GetSubstInformation` / `MyQueryDosDevice` / `ResolveSubsts` (Grep `src/` incl. plug-ins) and record in `specs/301-subst-target-whole/fix-log.md` what each now does on a refusal (`src/bugreprt.cpp` unchanged: the device line omitted)

## Phase 6: Polish & verification

- [X] T010 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T011 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed`; negative control (size test removed in a scratch edit -> the one-byte-short check fails; restored) recorded in fix-log.md
- [X] T012 `dumpbin /imports` of `tandemcommander.exe`: no `QueryDosDeviceA` (before: present) - fix-log.md
- [X] T013 Probe after: `probe/result_after.txt` 9 / 0 (quickstart.md step 4); fix-log.md before / after
- [X] T014 Inbox item for the Undelete plug-in's same-partition warning failing open when a volume cannot be told (spec *Clarifications*), source `measure:301`

## Dependencies

T001 independent. T002 -> T003, T004 -> T005, T006, T007, T008 -> T009 -> T010-T013. T014 any
time after T004.

## Parallel examples

- T003 (saltests) while T004 (salamdr2.cpp) is written.
- T007 and T008 (different files) after T004.

## Implementation strategy

MVP = Phases 2 + 3 (the delete question, the data-relevant part). Then US2, US3, verification.
