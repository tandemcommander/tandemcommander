# Tasks: A WSL server path offers its distributions as the share list

**Input**: `specs/373-wsl-share-list/` - plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: saltests checks for the pure rules (project rule: pure decisions in `src/common/` with saltests) and the GUI probe `probe/wslshares_probe.ps1`.

## Phase 1: Setup

- [ ] T001 Read the FEATURE-HISTORY entries 125, 193, 284, 285 (`specs/FEATURE-HISTORY.md`) and enumerate every caller of `CUncSharesJob::Start` / `Read` and every reader of `job->Error` (Grep `src/`); record the list in `specs/373-wsl-share-list/fix-log.md`

## Phase 2: Foundational (the pure rule)

- [ ] T002 Add `SalUncServerNotFoundErr`, `SalUncShareListAsksProviders`, `SalUncProviderListError` (feature 373, the table of `data-model.md`) to `src/common/saluncserver.h`, with the header comment's list extended
- [ ] T003 Add saltests checks for the three rules (every row of the decision table, 53 with and without shares, 51 / 1231 / 1232, `ERROR_MORE_DATA`, 5, 1326, 1707, providers ok / failed / empty) in `src/saltests/saltests.cpp` next to the checks of `SalUncShareListStep`

## Phase 3: User Story 1 + 3 - `\\wsl.localhost` offers the distributions; a missing server still one error (P1)

**Goal**: error 53 with no share asks the providers second; both fail -> 53.
**Independent Test**: probe rows W1, W2 (list, pick) and N1, U1 (one 53 box, time within 2 s of before).

- [ ] T004 [US1] In `CUncSharesJob::Read` (`src/shares.cpp`) replace the `notFound` test with `SalUncShareListAsksProviders` / `SalUncServerNotFoundErr`, and the final error of the provider branch with `SalUncProviderListError`; rewrite the comment with the measured reason (research R1)
- [ ] T005 [US1] Build `.\build.cmd` -> `BUILD SUCCEEDED`; saltests -> 0 failed; record numbers in `specs/373-wsl-share-list/fix-log.md`
- [ ] T006 [US1] Run the probe `-Expect fixed` on the hidden desktop -> `specs/373-wsl-share-list/probe/result_after.txt`; W1, W2, N1, U1 PASS

## Phase 4: User Story 2 - `\\wsl$` and the way up (P2)

- [ ] T007 [US2] Check rows W3 (`\\wsl$` -> `\\wsl$\<distro>`) and W4 (Backspace at `\\wsl.localhost\<distro>`, Esc) PASS in `specs/373-wsl-share-list/probe/result_after.txt`; C1 (`\\localhost` SMB list) PASS

## Phase 5: Polish

- [ ] T008 Negative control: the probe `-Expect fixed` against the build of `main` (before) must FAIL rows W1, W3, W4 - record (`specs/373-wsl-share-list/probe/result_negative.txt`; the before build is the same binary as `result_before.txt`, re-run with `-Expect fixed`)
- [ ] T009 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; fix-log *Measurement after* and *Checks* in `specs/373-wsl-share-list/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007; T008 needs the before build (run it before T004 changes the binary, or in a worktree of `main`); T009 last.

## Parallel opportunities

T002 and T003 touch different files ([P] possible once the rule's names are fixed); everything else is sequential (one binary, one probe at a time).

## Implementation strategy

MVP = Phase 3 (US1 + US3 share the one code change); US2 is verified by the same build.
