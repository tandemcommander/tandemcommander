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
