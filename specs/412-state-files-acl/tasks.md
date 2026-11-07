# Tasks: Backlog app start keeps its state files accessible

**Input**: `specs/412-state-files-acl/` (spec, plan, research, data-model, contracts, quickstart)
**Tests**: requested by the item (*Approach*) - included.

## Phase 1: Setup

- [ ] T001 Confirm the baseline: `npm run check` in `tools/backlog-app/` passes at the start of the branch (record the counts in `specs/412-state-files-acl/fix-log.md`)

## Phase 2: Foundational

- [ ] T002 Add the `StateAccess` result type and change `restrictToOwner()` to return it in `tools/backlog-app/packages/server/src/settings/state-dir.ts` (POSIX: `{ private, contents: "reset" }`); adapt the caller in `tools/backlog-app/packages/server/src/main.ts` (secret on `private`, a note on `contents === "failed"`)

## Phase 3: User Story 1 + 2 - files stay accessible, locked files repaired (P1)

**Goal**: after the start every entry of the state folder inherits owner + SYSTEM access; entries locked by an earlier start are repaired.
**Independent test**: `test/state-dir.test.ts`.

- [ ] T003 [US1] Write `tools/backlog-app/packages/server/test/state-dir.test.ts` (Windows-only cases `skipIf`): files, a hidden `.git` and nested folders read / written / deleted after `restrictToOwner()`; every DACL names only the user's SID and SYSTEM; the folder protected, the entries not; a pre-locked folder (the old icacls call) repaired; an empty folder succeeds
- [ ] T004 [US1] Run T003 against the old body - the file cases must fail (negative control, record in fix-log)
- [ ] T005 [US1] Implement in `tools/backlog-app/packages/server/src/settings/state-dir.ts`: folder step without `/T`; walk with `readdirSync(withFileTypes)` (link or unlistable folder -> slow path); fast path `icacls <folder>\* /reset /T /C /Q`; slow path per folder `icacls <dir>\* /reset /C /L /Q`, top-down, only into real folders
- [ ] T006 [US1] Add the junction case to `tools/backlog-app/packages/server/test/state-dir.test.ts`: a junction to an outside folder whose file has an explicit ACE - after the step the outside ACE is still there, the inside files are repaired (slow path)

## Phase 4: User Story 3 - unreadable side worktree reported (P2)

- [ ] T007 [US3] In `tools/backlog-app/packages/server/src/backlog/side-worktree.ts` `ensure()`: when `exists()` is false and `.git` exists but reading it fails with EACCES / EPERM, throw `ApiError("tool-failed", ...)` and keep the folder
- [ ] T008 [US3] Add the case to `tools/backlog-app/packages/server/test/side-worktree.test.ts` (Windows: lock `.git` with an empty protected DACL, `ensure()` rejects with the message, the folder still exists; restore the DACL in cleanup); the existing "deleted and recreated" case still passes

## Phase 5: Polish

- [ ] T009 `npm run check` in `tools/backlog-app/` (typecheck, lint, format, tests) passes
- [ ] T010 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `build.cmd` -> `BUILD SUCCEEDED`
- [ ] T011 Repeat the measurement of step 3 in `%TEMP%` with the new code (fix-log *Measurement after*)
- [ ] T012 Update the trap line of 344 in the docs of the app if it describes `/T` (`tools/backlog-app/README.md`, grep `icacls`)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006; T007 -> T008 independent of T003-T006; T009-T012 last.

## Implementation strategy

MVP = Phase 3 (the item's main point). Phase 4 is the item's last *Approach* bullet.
