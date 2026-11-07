# Closing report - 412-state-files-acl
Backlog item: backlog-app-start-locks-existing-state-files - Backlog app start leaves its existing state files with no access rights
Outcome: closed

## What changed

- `tools/backlog-app/packages/server/src/settings/state-dir.ts` `restrictToOwner()`: the state
  folder alone (no `/T`) gets the protected owner + SYSTEM ACL; then every entry inside is reset
  to inherit only from it - one `icacls <folder>\* /reset /T /Q` when a walk found no link and
  listed every folder, otherwise folder by folder (`<dir>\* /reset /L /Q`, top-down, never into
  a link). No `/C` on the calls whose exit code decides; a failed reset is repeated once with
  `/C` and reported. Returns `StateAccess { private, contents }`. The reset also repairs the
  files an earlier start locked.
- `main.ts`: the permissions step runs before the services are built (they read the event log's
  last id and the job files); the launcher secret still follows `private`; a note when the
  contents could not be reset.
- `backlog/side-worktree.ts` `ensure()`: a worktree folder or `.git` that exists but cannot be
  read is refused with `tool-failed` ("cannot be read ... restart the backlog app"), never
  deleted.
- Tests: `test/state-dir.test.ts` (new, 11, ACL cases Windows-only), one case in
  `side-worktree.test.ts`.

## Measurements (before / after, commands)

- Before (main 23a9f24a): feature 344's call on a temp folder left every file `D:PAI` (EPERM);
  the maintainer's real state folder: 375 of 383 files `D:PAI`, among them
  `main-worktree\.git` and `events.jsonl`.
- After: `node ../../specs/412-state-files-acl/probe/measure_after.ts` (from tools/backlog-app):
  the three files locked by 344's call -> `D:AI(A;ID;FA;;;SY)(A;ID;FA;;;<SID>)`, readable;
  `{"private":true,"contents":"reset"}`.
- Time on a tree like the real one (690 folders, 400 files): 1.15 s (344's call: 1.07 s).
- The maintainer's own state folder was not touched; the next start of the app repairs it.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `npm run check` (tools/backlog-app: typecheck, ESLint, Prettier, vitest): exit 0, 342 passed /
  2 skipped (final run, after the revert); baseline 329 / 2.
- Encoding guard `TOTAL: 0 finding(s)`; `build.cmd` `BUILD SUCCEEDED` (no product source
  changed; saltests not needed; no UI string, no `.slt` refresh).
- Negative controls: 344's call -> 4 of 5 first state-dir tests fail (the junction case: the
  old `/T` locked the owner out of a file outside the folder); old `ensure()` -> the item's exact
  `EPERM, Permission denied: \\?\...\main-worktree`; `/L` removed -> the file-symlink test fails;
  `/C` back -> 3 failure tests fail; the `/C` repeat removed -> 2 fail; the old start order -> the
  order test fails.

## Reviews (findings and what was done)

- Review 1: MUST 0, SHOULD 2 (tests failed from pwsh 7; `/L` untested), NOTE 5 (an unlistable
  worktree folder still deleted; a backspace in the fix-log; three recorded) - fixed.
- Review 2: MUST 0, SHOULD 2 (the event log read before the repair - ids restarting at 1; `/C`
  hid icacls failures so `private` could be wrong), NOTE 3 - fixed.
- Review 3: MUST 0, SHOULD 0, NOTE 3 (the `/C` repeat and the start order untested - fixed; two
  starts at once can race the reset - recorded).
- Review 4 (the last commit): MUST 0, SHOULD 1 (the `killTree` change in `write-channels.test.ts`
  did not fix the flaky fixture cleanup - 2 of 14 runs failed with it, 0 of 8 without) - reverted,
  Inbox item; NOTE 3 (moot after the revert, or accepted). The two new tests confirmed by its
  negative controls.

## Owed to a person (the lines added to the release checklist)

- 1 check added to `manual-checks-owed-before-the-next-release`: start the app once on the
  maintainer's tree; no `D:PAI` entry left, `main-worktree/.git` and `events.jsonl` readable, a
  change during a run lands on `main`.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- `icacls /T` follows a junction out of the state folder (severity 3) - links never followed.
- An unlistable `main-worktree` folder was deleted by `ensure()` (severity 2) - refused.
- POSIX `chmod` failure reported `contents: "reset"` - now `"failed"`.

Not fixed: the flaky `write-channels.test.ts` fixture cleanup (EPERM now and then, severity 3,
from 371) - one attempt refuted by review 4 and reverted; its own item below.

## New Inbox items (slug - title)

- backlog-app-tests-fail-now-and-then-removing-their-fixture - Backlog app tests fail now and then removing their fixture folder with EPERM
