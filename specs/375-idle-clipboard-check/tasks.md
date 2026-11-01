---
description: "Task list for 375-idle-clipboard-check"
---

# Tasks: Switching back to the program never waits for a busy clipboard

**Input**: Design documents from `specs/375-idle-clipboard-check/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/idle-clipboard-check.md

**Tests**: SC-003 asks for unit checks of the pure rule (saltests); the probe covers SC-001/SC-002.

## Phase 1: Setup

- [ ] T001 Probe and measurement before the change recorded in specs/375-idle-clipboard-check/fix-log.md and specs/375-idle-clipboard-check/probe/result_before.txt (done during measure-first)

## Phase 2: Foundational

- [ ] T002 Create the pure rule `SalClipCheckNextLook` with `SAL_CLIPCHECK_RETRY_MS` (500) and `SAL_CLIPCHECK_MAX_RETRIES` (10) in src/common/salclipcheck.h (table of contracts/idle-clipboard-check.md)
- [ ] T003 [P] Add `TestClipCheck375` (every row of the contract table, the limit, a non-retry restart) and its call and include in src/saltests/saltests.cpp
- [ ] T004 [P] Add `IDT_CLIPCHECKRETRY` (956) and the externs `IdleClipCheckIsRetry`, `IdleClipCheckRetries`, `IdleClipCheckRetryPending` in src/consts.h; define them in src/salamdr1.cpp next to `IdleCheckClipboard`

## Phase 3: User Story 1 - Switching back answers at once (P1)

**Goal**: no wait for a busy clipboard in the idle check. **Independent test**: probe row HELD < 30 ms.

- [ ] T005 [US1] `IsTextOnClipboard(BOOL noWait = FALSE, BOOL* busy = NULL)`: one attempt without `Sleep` when `noWait`, report busy, in src/fileswn9.cpp and its declaration in src/fileswnd.h
- [ ] T006 [US1] The idle check calls `IsTextOnClipboard(TRUE, &busy)` in src/mainwnd1.cpp (`CMainWindow_RefreshCommandStates`)

## Phase 4: User Story 2 - The paste commands still follow the clipboard (P2)

**Goal**: a busy clipboard is looked at again (bounded). **Independent test**: saltests `TestClipCheck375`; person-step on a real desktop.

- [ ] T007 [US2] After the queries apply `SalClipCheckNextLook` and set / kill `IDT_CLIPCHECKRETRY` on the main window in src/mainwnd1.cpp
- [ ] T008 [US2] Handle `IDT_CLIPCHECKRETRY` in the main window's `WM_TIMER` (kill, mark retry, request the check) and look at once in `WM_USER_ENTERMENULOOP` when a look is pending, in src/mainwnd3.cpp

## Phase 5: Polish & verification

- [ ] T009 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0
- [ ] T010 `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T011 Probe after the change (rows FREE, HELD) -> specs/375-idle-clipboard-check/probe/result_after.txt; record in fix-log.md
- [ ] T012 Owed to a person: the paste commands' enabled state on a real desktop (quickstart step 4) - a person-step item at closing

## Dependencies

T002 -> T003, T007; T004 -> T007, T008; T005 -> T006 -> T007; all -> T009-T011.

## Parallel examples

T003 and T004 (different files) after T002.

## Implementation strategy

MVP = US1 (T005-T006) removes the wait; US2 keeps the paste states correct afterwards. Both ship together.
