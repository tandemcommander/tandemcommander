# Fix log - 411-lock-retry-permission

Backlog item `run-lock-update-release-no-retry` (review:344, severity 4): `bin/backlog.sh lock
update` / `lock release` fail with PermissionError when another process has the run lock open.

## Before (main at b5bb8329)

Sites (searched by name): `tools/backlog/backlog.py` `cmd_lock` - `update` calls `write_text`
(`os.replace(tmp, path)`, no retry), `release` calls `path.unlink()` (no retry); `status` and the
reads before update / release: `path.exists()` then `read_lock` (`read_text`, no retry).
Callers: SKILL.md of `/tandem-backlog-implement` (steps 2, 4.5, 3/8/9/10 release), the backlog
app's stale-lock release (`tools/backlog-app/packages/server/src/backlog/tool.ts`, `lock release
--force`), the maintainer. `tools/backlog/loop.py` reads the lock itself (`Repo.lock`, already
retries) and never writes it.

Measurement: `python specs/411-lock-retry-permission/probe/repro_lock.py "$(pwd -W)"` (written for
this feature; acquires a lock in a temporary `--lock-dir`, starts a second Python process that
holds `open(lock, 'rb')` for 5 s or 0.5 s, runs the command meanwhile):

```text
acquire (0, ['lock acquired: ...\tmpm9o0a2vg\tandem-backlog-run.lock'])
update while held (5 s) (1, ["PermissionError: [WinError 5] Přístup byl odepřen: '...lock.f1wbdo5s.tmp~' -> '...lock'"])
release while held (5 s) (1, ["PermissionError: [WinError 32] Proces nemá přístup k souboru, neboť jej právě využívá jiný proces: '...lock'"])
exists after True
update while held (0.5 s) (1, [... WinError 5 ...]) 0.28
release while held (0.5 s) (1, [... WinError 32 ...]) 0.27
exists after True
```

Both fail at once (0.28 s = the interpreter's start) with a traceback, the lock stays. With a held
handle the failure is deterministic; in real use the window is a reader's microseconds.

Finding of the measurement (severity 3, fixed on the way, stop-rules rule 11): the read side of
the same commands - `status` (and the reads in `acquire` / `update` / `release`) read without a
retry, and `exists()` then `read_lock` gives a FileNotFoundError traceback when a release lands in
between. `acquire` meeting a "delete pending" lock (released while a share-delete reader held it)
gets a PermissionError from `os.open` - same treatment.

## Design

- `lock_retry(path, what, action)`: 40 x 50 ms (`LOCK_RETRY_ATTEMPTS` / `LOCK_RETRY_DELAY`, the
  window of `traces.write_json_atomic`), then `Refused` → `refused: the run lock <path> could not
  be <what>: another process holds it open (<error>); nothing changed`, exit 1.
- `lock_fields(path)`: read through `lock_retry`, `None` when the file is gone.
- `cmd_lock` uses them for create, read, replace and delete.

Measured while designing (scratch `delpending.py`): on this Windows 11 NTFS volume a file opened
with `FILE_SHARE_DELETE` by another handle and then deleted disappears from the folder at once
(POSIX delete semantics); `os.open(O_CREAT|O_EXCL)` of the same name then succeeds. So the
"delete pending" acquire failure is not reachable here; the acquire retry stays as a cheap
defence (other file systems, older semantics) and is tested with a stubbed `os.open`.

## Implementation

- `tools/backlog/backlog.py`: `import time`; `LOCK_RETRY_ATTEMPTS = 40`, `LOCK_RETRY_DELAY =
  0.05`; `lock_retry(path, what, action)`; `lock_fields(path)`; `cmd_lock` - `status` and the
  read before update / release through `lock_fields` (no separate `exists()`); `acquire` creates
  through `lock_retry` and, on `FileExistsError`, reads the holder (a vanished holder: create
  again, at most 40 times, then `refused:`); `update` replaces through `lock_retry` (each attempt
  a fresh temporary file, removed by `write_text` on failure); `release` deletes through
  `lock_retry`, a file gone meanwhile counts as released.
- `tools/backlog/test_backlog.py`: class `LockHeldOpenTests` (Windows only), 11 tests: a child
  process holds `open(lock, 'rb')`; update / release / release --force wait out a 0.5 s hold
  (and take > 0.3 s - the holder really blocked them); negative control `LOCK_RETRY_ATTEMPTS = 1`
  is refused; no reader = no wait (< 0.2 s); attempts 3 + 3 s hold: update refused (one line,
  bytes unchanged, no `*.tmp~`), release refused (lock kept); status waits out a 0.3 s byte-range
  lock; a lock deleted between check and read is `free` / `no lock to update` / `no lock to
  release`; acquire retries 3 refused creates; acquire against a vanishing holder creates the lock.

Tests first: at HEAD (helpers added, `cmd_lock` unchanged) 10 of the 11 tests fail (12 errors
with subtests), each with the defect's own error (WinError 5 / 32, FileNotFoundError,
PermissionError, FileExistsError); only `test_no_reader_no_wait` passes.

## After

- `python -m unittest tools.backlog.test_backlog.LockHeldOpenTests` → `Ran 11 tests ... OK`.
- `python -m unittest tools/backlog/test_backlog.py tools/backlog/test_loop.py tools/backlog/test_traces.py` → `Ran 255 tests in 226.347s OK`.
- `python tools/test_bin_help.py` → OK.
- The measurement repeated (`probe/repro_lock.py`):

  ```text
  update while held (5 s) (1, ['refused: the run lock ...\tandem-backlog-run.lock could not be updated: another process holds it open (Přístup byl odepřen); nothing changed - try again'])
  release while held (5 s) (1, ['refused: the run lock ... could not be released: another process holds it open (Proces nemá přístup k souboru, ...); nothing changed - try again'])
  exists after True
  update while held (0.5 s) (0, ['lock updated: branch b2']) 0.56
  release while held (0.5 s) (0, ['lock released']) 0.55
  exists after False
  ```

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`; `bin/backlog.sh check` → `TOTAL: 0`.
- No product code changed: no `build.cmd`, `saltests` or GUI probe applies (SKILL.md step 6: build
  and saltests when the core or `src/common/` changed); no UI strings, no translations.

## Findings fixed on the way

- (severity 3, measure:411) `lock status` / the reads of `acquire`, `update`, `release`: no retry
  of PermissionError and an `exists()`-then-read race (FileNotFoundError traceback). Before: tests
  `test_status_waits_for_a_briefly_unreadable_lock` (PermissionError) and
  `test_lock_gone_between_check_and_read_is_no_lock` (FileNotFoundError ×3) fail at HEAD; after: pass.

## Review

### Review 1 (refute-first agent) - MUST 0, SHOULD 2, NOTE 4

Re-ran the measurement (0.5 s hold → both 0 in 0.53 s; 5 s → one `refused:` line each), the full
suite (255 OK), a negative control (the branch's tests against `main`'s `cmd_lock`: all 11 fail
with the defect's errors - the fix-log's "10 of 11" came from a variant where only the helpers
were added), and a 40 s stress run (3 readers opening the lock every 20 ms, 3 workers acquire →
update ×2 → status → release): branch 83 acquisitions, never two holders, no `*.tmp~`; `main`'s
`cmd_lock` under the same load: an `update` failed with the WinError 5 traceback - the defect is
reachable with microsecond readers too.

- S1 (fixed): the retry widened check-then-act in `update` / `release` to about 2 s: a lock
  force-released and taken by another run during the wait would be overwritten (update) or
  deleted (release). Now every attempt reads the lock again (`lock_now`) and acts only when it
  still holds the fields first checked (for `--force` too: it releases the lock it was shown);
  otherwise `refused: the lock changed while waiting (now <holder>); nothing changed`, exit 1.
  Tests `test_update_does_not_overwrite_a_lock_taken_meanwhile`,
  `test_release_does_not_delete_a_lock_taken_meanwhile` (`--slug` and `--force`; the stub makes
  the first replace / unlink fail after another holder took the lock). Negative control: against
  the pre-review `backlog.py` (HEAD ca423122, temp copy) both fail (2 failures, 1 error).
- S2 (fixed): the skill mapped every exit 1 of `lock acquire` to "another run in progress" and had
  no step for a refused release. `SKILL.md` §0.8 now says: a `refused: the run lock … could not
  be …` answer is repeated once; still refused → `acquire` ends `refused (precondition: …)`,
  `release` is named under *Lock* in §11.
- N1 (fixed): the message now says "another process holds it open, or it is not writable".
- N2 (fixed): `test_no_reader_no_wait` no longer times the whole command; it stubs `time.sleep`
  and asserts no sleep at all for status / update / release / acquire without a reader.
- N3 (fixed): `probe/repro_lock.py` removes its temporary folder.
- N4 (documented, no change): `acquire` against a lock that keeps appearing and disappearing is
  bounded at 40 rounds (each read up to 2 s) - pathological, harmless.

After the fixes: `LockHeldOpenTests` 13 OK; all three suites `Ran 257 tests in 222.385s OK`;
`test_bin_help.py` OK; encoding guard `TOTAL: 0 finding(s)`; repro unchanged (0.53 / 0.56 s
success, 5 s refused with the new wording).

### Review 2 (refute-first agent) - MUST 0, SHOULD 2, NOTE 4

Re-ran the measurement (5 s → one `refused:` line each, lock kept; 0.5 s → 0.53 / 0.52 s
success), the suites (257 OK), negative control 1 (branch helpers + `main`'s `cmd_lock`: 12 of 13
`LockHeldOpenTests` fail, 15 errors with subtests, each with the defect's error; only
`test_no_reader_no_wait` passes), negative control 2 (pre-review `backlog.py` ca423122: exactly
the S1 tests fail) and a 30 s stress run (3 readers, about 10,000 reads; 3 workers: 24
acquisitions, 48 updates, 24 releases, never two holders - checked by an exclusive marker file -
no traceback, no refusal, no `*.tmp~`). Review-1 fixes S1, S2, N1-N3 confirmed.

- S1 (fixed): the tests that hold the lock left a `%TEMP%\bl242-*` folder each (4 per run):
  `Base.tearDown` removed the folder before the cleanups ended the holder. `LockHeldOpenTests`
  now runs its cleanups first (`tearDown` → `doCleanups()` → `super().tearDown()`); measured:
  `%TEMP%\bl242-*` count 141 before and after a run of the class (the 141 are older runs').
- S2 (fixed): `contracts/lock-commands.md` showed the pre-N1 wording and missed three outputs
  (`refused: the lock changed while waiting …`, acquire's "kept appearing and disappearing",
  `lock released` for a lock gone during the retries) - rewritten. The last one (FR-002) got a
  test: `test_release_of_a_lock_gone_during_the_retries_is_released`.
- N1 (fixed): the skill's steps 2 (lines with "another run in progress") now point a
  `refused: the run lock …` line to §0.8; the §11 template has `not released: <the refused
  line, §0.8>`; §0.8 says a release answering `the lock changed while waiting` is no longer this
  run's lock - never repeated, never `--force`.
- N2 (documented): check-then-act is down to microseconds per attempt; a force-release followed by
  an acquire with the same slug, branch, host and `started` second would look unchanged - needs
  OS locking to close, beyond the item. Older: `release` without `--slug` matches a just-created,
  still-empty lock (slug `-`) - microseconds, not caused by 411.
- N3 (documented): `write_text` ignores an error deleting its temporary file; with retries an AV
  scanner holding them could leave several `*.tmp~` in `.git` - theoretical, older than 411, not
  seen in either stress run.
- N4 (not this feature's): stale worktrees of earlier reviews (`%TEMP%\rev325\neg` …) are
  registered; left as they are.

After the fixes: `LockHeldOpenTests` 14 OK; all three suites `Ran 258 tests in 220.846s OK`;
`test_bin_help.py` OK; encoding guard `TOTAL: 0 finding(s)`. No third review: review 2 had no
MUST finding and its fixes changed only tests, the contract and the skill's wording.
