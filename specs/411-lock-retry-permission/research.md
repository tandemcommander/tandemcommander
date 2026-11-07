# Research - 411 lock retry

## R1. Why the operations fail

- Decision: treat `PermissionError` from `os.replace`, `Path.unlink`, `open` and `os.open` on the
  lock as "another process holds it", and retry.
- Rationale: measured at b5bb8329 (fix-log *Before*): a second Python process with
  `open(lock, 'rb')` makes `os.replace(tmp, lock)` fail with WinError 5 and `unlink` with
  WinError 32. Python's `open` does not pass `FILE_SHARE_DELETE`, so a rename over or a delete of
  an open file is refused for the whole time the handle is open. Readers (loop status, the backlog
  app every 2 s, `lock status`) hold it for microseconds, so a short retry clears it.
  A lock released while a share-delete reader (Node/libuv, git) holds it is "delete pending" until
  that handle closes: `os.open(O_CREAT|O_EXCL)` and `open` then give `PermissionError` too.
- Alternatives considered: opening the lock with share-delete in our readers only (the app's and
  any other process's readers would still block); a lock via `msvcrt.locking` (changes the
  protocol the loop and the app rely on - out of scope).

## R2. The retry window

- Decision: 40 attempts at 50 ms (about 2 s), module constants `LOCK_RETRY_ATTEMPTS` /
  `LOCK_RETRY_DELAY` (tests shorten them).
- Rationale: the item names `write_json_atomic` (342) as the model; `loop.py` `unlink` and
  `Repo.lock` use the same 40 x 50 ms.
- Alternatives: 100 x 50 ms as `loop.save_json` - longer than needed for a microsecond reader.

## R3. A persistent failure

- Decision: raise `Refused` - `main` prints `refused: <message>` and returns 1. The message names
  the lock file, says another process holds it open, quotes the OS error, and says nothing changed.
- Rationale: the run contract (SKILL.md §0.8): exit 1 + `refused:` = nothing written, fix and
  repeat. `write_text` already removes its temporary file when the replace fails, and the lock
  keeps its old bytes (the replace is atomic), so "nothing changed" holds.
- Alternatives: re-raising (the traceback the item reports); a new exit code (callers know only 0/1/2).

## R4. The read side and the check-then-read race

- Decision: one helper `lock_fields(path)` returns the lock's fields or `None` when the file is
  gone; it retries `PermissionError` the same way. `cmd_lock` uses it instead of
  `path.exists()` + `read_lock(path)`. Acquire: on `FileExistsError` it reads the holder; a holder
  that vanished meanwhile means "try to create again" (bounded by the same attempts).
- Rationale: severity-3 finding of the measurement (same commands, same cause); fixed on the way
  (stop-rules rule 11).

## R5. Testing

- Decision: Windows tests in `test_backlog.py` that start a child Python process holding
  `open(lock, 'rb')` (it prints a line once the handle is open) for a fixed time, and call the
  tool in-process. Proof that the holder really blocked: the call takes at least most of the hold
  time (negative control: with retries disabled, `LOCK_RETRY_ATTEMPTS = 1`, the same call is
  refused). Persistent case: attempts shortened to 3, holder 3 s. Read side: `msvcrt.locking`
  byte-range lock released by a timer thread; the race: `read_lock` wrapped to delete the file
  first.
