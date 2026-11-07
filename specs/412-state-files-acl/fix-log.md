# Fix log - 412-state-files-acl

Backlog item `backlog-app-start-locks-existing-state-files`: the backlog app's start leaves the
files already in its state folder with an empty, protected access list (`D:PAI`).

## Measurement before (main at 23a9f24a)

1. Temp folder `%TEMP%\tcbl_measure` with `a.txt`, `sub\b.txt`; the exact call of
   `StateDir.restrictToOwner()`:
   `icacls <d> /inheritance:r /grant:r *<SID>:(OI)(CI)F *S-1-5-18:(OI)(CI)F /T /C /Q` -> exit 0,
   "Successfully processed 4 files".
   - `<d>`, `sub`: `D:PAI(A;OICI;FA;;;SY)(A;OICI;FA;;;<SID>)`
   - `a.txt`, `sub\b.txt`: `D:PAI` (empty) - `Get-Content a.txt` -> "Access to the path ... is denied."
   - `c.txt` created afterwards: `D:AI(A;ID;FA;;;SY)(A;ID;FA;;;<SID>)` (inherits - hides the defect).
2. The maintainer's real state folder `.git\tandem-backlog-app` (read-only `Get-Acl`): 383 files,
   375 with `D:PAI`, among them `main-worktree\.git` and `events.jsonl`. Not repaired by the run:
   the next start of the fixed app repairs it.
3. Reachability: `main.ts` calls `state.restrictToOwner()` at every start; `SideWorktree.exists()`
   -> `existsSync(.git)` true (attributes are readable through the folder), `git rev-parse` fails
   (cannot read `.git`) -> false -> `ensure()` -> `rmSync(path, {recursive, force})` -> EPERM.
4. Trial of the item's approach in the same temp folder (after locking it again, plus a hidden
   `.git` file): `icacls <d> /inheritance:r /grant:r ... /C /Q` (no `/T`), then
   `icacls <d>\* /reset /T /C /Q` -> exit 0, every entry `D:AI` with inherited owner + SYSTEM ACEs
   (hidden `.git` included, previously locked files repaired), the folder `D:PAI` owner + SYSTEM.
   Empty folder: `icacls <e>\* /reset /T /C /Q` -> exit 0, "Successfully processed 0 files".

## Decisions

- Folder ACL without `/T`, then the contents reset (`<folder>\*` `/reset /T /C /Q`) - the item's
  first approach.
- The launcher secret depends on the folder step only (the secret file `instance.json` is written
  after the step and inherits); a failed contents reset prints a note.
- `SideWorktree`: a `.git` that exists but cannot be read (EACCES / EPERM) is an error, never a
  reason to delete the folder.

## Work

- T001 baseline `npm run check` (tools/backlog-app): exit 0, 329 passed / 2 skipped.
- `state-dir.ts`: `restrictToOwner()` returns `StateAccess { private, contents }`. The folder
  alone (no `/T`) gets `/inheritance:r /grant:r <SID>:(OI)(CI)F SY:(OI)(CI)F`; then the contents:
  `treeWithoutLinks()` (a `readdirSync(withFileTypes)` walk) -> one
  `icacls <folder>\* /reset /T /C /Q`; a link or an unlistable folder -> `resetFolderByFolder()`
  (`<dir>\* /reset /C /L /Q`, top-down, never into a link).
- `main.ts`: the secret follows `access.private` as before; a note when the folder is private but
  the contents reset failed.
- `side-worktree.ts` `ensure()`: a `.git` that exists but reads with EACCES / EPERM -> `ApiError
  tool-failed` "the side worktree of main cannot be read ... restart the backlog app", folder
  kept. `exists()` stays a boolean (`revert()` uses it in failure paths).
- Tests: `test/state-dir.test.ts` (5, Windows-only): usable + owner-only DACLs, repair of locked
  files, an unlistable folder, an empty folder, a junction never followed;
  `side-worktree.test.ts` +1: an unreadable `.git` refused without deleting, works after the
  start's repair.
- Negative controls: the old icacls call (only adapted to the new return shape) -> 4 of 5
  state-dir tests fail (`D:P...` DACLs; the junction case: the outside file became
  `D:PAI(A;;FR;;;BU)` - the old `/T` followed the junction and locked the owner out of a file
  outside the folder); the old `ensure()` -> the side-worktree case fails with exactly the item's
  `EPERM, Permission denied: \\?\...\main-worktree`.
- `npm run check`: exit 0, 336 passed / 2 skipped (19 files + 1 skipped).
- Encoding guard `TOTAL: 0 finding(s)`; `build.cmd` `BUILD SUCCEEDED` (no product source changed;
  saltests not needed). No UI string of the product changed (no `.slt` refresh).
- Docs: no text describes the `/T` call (`tools/backlog-app/README.md`, `architecture/`).

## Measurement after

- `node ../../specs/412-state-files-acl/probe/measure_after.ts` (from tools/backlog-app): after
  344's call `events.jsonl`, `main-worktree\.git`, `main-worktree\backlog\BACKLOG.md` = `D:PAI`
  (EPERM); `restrictToOwner` -> `{"private":true,"contents":"reset"}`; after: all three
  `D:AI(A;ID;FA;;;SY)(A;ID;FA;;;<SID>)` (readable).
- Time on a tree like the real one (690 folders, 400 files): 1175 / 1149 ms; feature 344's call on
  the same tree 1073 ms.
- The maintainer's own state folder is left as it is: the next start of the app repairs it.

## Findings fixed on the way

- **icacls `/T` follows a junction out of the state folder** (severity 3: unreachable in normal
  use - the app and git create no links there - but the old `/T` call has the same property).
  Measured in `%TEMP%\tcbl_measure` with a junction `junc` -> `%TEMP%\tcbl_outside` whose `out.txt`
  had an explicit `(A;;FR;;;BU)`: `icacls <d>\* /reset /T /C /Q` -> "Successfully processed 7
  files" and the BU ACE of `out.txt` was gone; the same with `/L` added. Without `/T`
  (`icacls <d>\* /reset /C /L /Q`) the outside file kept its ACE. Node's
  `readdirSync(..., { withFileTypes: true })` reports the junction as `isSymbolicLink() == true`.
  Decision (clarification Q1, Q2): one `/T` call only when a walk of the folder found no link and
  could list every folder; otherwise folder by folder (`<dir>\* /reset /C /L /Q`, top-down,
  never into a link). Cost measured: 9 ms per icacls call; the real state folder has 691 folders
  (about 6 s folder by folder - hence the fast path).

## Analyze

- Run 1: CRITICAL 0, HIGH 0. C1 (MEDIUM) the unlistable-folder path had no test -> added to T006.
  C2 (LOW) the note of a failed contents reset is not tested: forcing an `icacls` failure needs
  an entry the owner cannot change, accepted. C3 (LOW) POSIX path unchanged, not testable here,
  accepted.
- Run 2 (after the T006 change): CRITICAL 0, HIGH 0, MEDIUM 0; C2, C3 as accepted.

## Review

### Review 1 (refute-first agent, 2026-11-07) - MUST 0, SHOULD 2, NOTE 5

It re-ran `measure_after.ts` (same result), read the real state folder (691 folders, 383 files,
no link, all listable - the next start takes the one-call path; 356-character paths repaired),
checked the callers (`main.ts` only; `restrictToOwner()` runs before `services.start()`;
`ensure()` only from `sync()`; `revert()` unchanged), and ran negative controls (344's call: 5
tests fail; old `ensure()`: the item's EPERM; link walk forced clean: only the junction test
fails).

- SHOULD 1: the ACL tests failed from PowerShell 7 (the inherited `PSModulePath` keeps Windows
  PowerShell 5.1 from loading `Get-Acl`; 4 failed / 8 passed). Fixed: `daclsOf()` runs it
  without `PSModulePath` and throws when it returns fewer DACLs than paths; `measure_after.ts`
  likewise and fails instead of printing an empty DACL. After: 13 / 13 from pwsh 7.6.6.
- SHOULD 2: nothing tested the `/L` of the folder-by-folder reset (the reviewer measured that
  without `/L` a file symbolic link's outside target loses an explicit ACE). Fixed: a test with a
  file symbolic link to an outside file with an explicit Users read ACE (skipped when the
  machine cannot create file symlinks; it ran here). Negative control: `/L` removed -> that test
  fails (1 failed / 5 passed).
- NOTE 1: the unlistable-folder test also passes on the fast path (`/T` repairs such a folder
  itself) - it still runs the folder-by-folder path at the actual code; left.
- NOTE 2: `ensure()` still deleted a `main-worktree` folder that itself could not be listed
  (severity 2). Fixed: `readdirSync(path)` is tried before `.git`; EACCES / EPERM -> the same
  `tool-failed` refusal. Test: the side-worktree case locks the folder after the `.git` part,
  `sync()` refuses, the folder stays, the start's repair makes it work. Negative control: the
  `readdirSync` line removed -> the test fails with the item's EPERM.
- NOTE 3: one flaky failure of `write-channels.test.ts:96` (an `rmSync` in its cleanup) in one
  of the reviewer's runs, not reproduced (9 / 9 alone, the full suite green twice); unrelated
  (the ACL tests touch only their own temp folders). Recorded only.
- NOTE 4: a backspace (0x08) in this fix-log where a here-document ate a backslash - fixed (rule
  123); the same trap hit the review fixes once and was corrected with the editor.
- NOTE 5: unchanged from 344 and unreachable in normal use (the app creates the folder): an
  explicit ACE for another user already on the folder itself survives `/grant:r`; `/reset` on a
  hard link changes the shared file. Recorded only.

After the fixes: `npm run check` exit 0, 337 passed / 2 skipped; encoding guard `TOTAL: 0`.

### Review 2 (refute-first agent, 2026-11-07) - MUST 0, SHOULD 2, NOTE 3

Re-checked: the measurement (same), the real folder (1074 entries, no link, 375 locked, owned by
the user - the next start takes the one-call path), the review-1 fixes (13 / 13 from pwsh 7.6.6
and Bash; `/L` and the link walk removed -> the junction and file-symlink tests fail), non-ASCII
names (`ř voilà`, `ž kůň.json`) and a 336-character path repaired on both paths, empty folders
exit 0 with `/L` and `/T`.

- SHOULD 1: the event log was read before the start repaired it - `new Services()` (main.ts)
  builds `Notifications`, whose constructor reads `events.jsonl` for the last id; the repair ran
  only later, so the first fixed start would number new events from 1 again (reviewer's probe:
  ids `1,2,3,1`, `after(3)` empty) and `AiJobs.load()` skipped the locked job files for one
  session. Fixed: `restrictToOwner()` runs at the start of step 2, before `new Services()` (after
  the reuse check of a running instance, as before); the secret decision stays where it was.
  Test: "lets the event log keep its ids ..." - three events, 344's call locks the log, the
  repair, then a new `Notifications`: the next id is 4 and `after(3)` is `[4]`. (The order in
  `main.ts` itself is not unit-tested; the reviewer's probe is the negative control: built
  before the repair, the ids restart at 1.)
- SHOULD 2: with `/C` `icacls` exits 0 also when an entry failed (measured by the reviewer:
  OWNER RIGHTS denied WRITE_DAC -> "Failed processing 1 files", exit 0; without `/C` exit 5), so
  `private` could be true for a folder that kept other users' access (the launcher secret would
  be written there) and `contents: "failed"` could never be reported. Fixed: the folder call runs
  without `/C`; every reset runs without `/C` first and, when it fails, once more with `/C` so the
  other entries are still repaired, the result staying `failed`. Tests: a folder whose ACL the
  owner cannot change -> `{ private: false, contents: "failed" }`; a file that cannot be reset ->
  `contents: "failed"` and the other locked files repaired, on the one-call path and on the
  folder-by-folder path. Negative control: `/C` put back into both calls -> these 3 tests fail
  (3 failed / 7 passed).
- NOTE 1: a `.git` the start cannot repair leaves `ensure()` refusing with "restart the backlog
  app" although a restart does not help - the start now prints its note in exactly that case
  (`contents: "failed"`); the folder is kept. Left.
- NOTE 2: POSIX: a failed `chmod` returned `contents: "reset"` - now `"failed"`.
- NOTE 3: older reviewers' worktrees (`rev325` ... `rev341r3`) registered - not this feature's.

After the fixes: `npm run check` exit 0, 341 passed / 2 skipped; encoding guard `TOTAL: 0`.

### Review 3 (refute-first agent, 2026-11-07, at 19bd1bf6) - MUST 0, SHOULD 0, NOTE 3

Re-checked: the measurement (same), 17 / 17 feature tests, `npm run check` 341 / 2 skipped; no
`/C` first never reported a success as a failure - an empty folder, a folder of empty folders,
hidden / read-only / system files and a hidden read-only folder, non-ASCII names
(`ř voilà 中文\ž kůň 😀.json`), names with `[x] %PATH% & ^` and `a;b,c=d.txt`, empty folders
beside a junction (folder by folder; the junction reset as a link, its target untouched). What
now runs after the permissions step instead of before it: `SessionAuth`, `EventHub`, `new
Services` (`Notifications` reads `events.jsonl` - the purpose; `AiJobRunner.load()` reads the job
files, skips an unreadable one; `ChatService.prune()` by mtime only), `createApi`, the static
manifest (outside the state folder), the server, Vite - none depends on the old permissions.

- NOTE 1 (severity about 2): the permissions step now also runs on a start that then ends early
  (`EADDRINUSE`, web client not built), so two starts at once can reset the folder while the
  first instance writes: in the reviewer's race 4 of 3387 atomic writes failed with EPERM on the
  rename (old file kept, no corruption) and `restrictToOwner` reported `failed` in 4 of 8 calls;
  `main`'s code under the same race: 8521 of 8573 writes failed (the original defect). Recorded
  only.
- NOTE 2: the folder-by-folder failure test did not prove the repeat with `/C` (the stuck file
  sorted after every locked sibling). Fixed: both failure tests add a locked `zz.json` after
  `stuck.json`. Negative control: the repeat removed -> both failure tests fail (2 failed / 9
  passed).
- NOTE 3: no test caught the order in `main.ts`. Fixed: a test reads `main.ts` and checks that
  the one `state.restrictToOwner()` comes before `new Services(`; the event-log test renamed (it
  does not cover `main.ts`). Negative control: the call moved back after the services -> that
  test fails.

## Findings fixed on the way (continued)

- **Flaky `write-channels.test.ts` cleanup** (severity 3, from feature 371; seen by review 1 and
  in this run's `npm run check` after review 3: `EPERM` from `rmSync` of the fixture in
  `afterEach`, 1 failed / 341 passed; the file alone 6 / 6 green - only under the full suite's
  load). Cause: `loop.kill()` ends only the loop's Python process; a git it started can still
  hold the fixture when the cleanup (10 retries x 200 ms) removes it. Attempt 1: the afterEach
  ends the whole tree with `killTree()` (`taskkill /T /F`, the server's own helper) on Windows.
  After: `npm run check` 3 runs in a row exit 0, 342 passed / 2 skipped each (before: 1 of 2 full
  runs after review 3 failed, and 1 of the reviewer's runs). Not provable as a single test (the
  race needs the full suite's load); the three green runs are the evidence.
