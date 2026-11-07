# Contract - `bin/backlog.sh lock` under a concurrent reader (411)

Unchanged: arguments, the lock file format, every output line and exit code of
`specs/242-backlog-system` / 247 / 344 when no other process holds the lock file open and nobody
else changes the lock during the command.

Added (`<why>` = `another process holds it open, or it is not writable (<OS error>)`; the retry
window is 40 x 50 ms, about 2 s, per file operation):

| Action | Another process has the lock open (PermissionError) | ... for longer than the window |
|---|---|---|
| `status` | waits, then prints the holder line or `free` | `refused: the run lock <path> could not be read: <why>; nothing changed - try again` - exit 1 |
| `acquire` | waits, then `lock acquired: <path>` or `another run in progress: ...` | `refused: the run lock <path> could not be created: <why>; nothing changed - try again` - exit 1 |
| `update` | waits, then `lock updated: branch <b>` - exit 0 | `refused: the run lock <path> could not be updated: <why>; nothing changed - try again` - exit 1; the lock keeps its bytes, no `*.tmp~` left |
| `release` (`--force`) | waits, then `lock released` - exit 0 | `refused: the run lock <path> could not be released: <why>; nothing changed - try again` - exit 1; the lock stays |

Changes by someone else during the command (review 1 S1):

- `update` / `release` (also `--force`) read the lock again before every attempt and act only
  when it still holds the fields first read. Otherwise: `refused: the lock changed while waiting
  (now <holder line>); nothing changed` - exit 1, the other holder's lock untouched.
- `release`: a lock that disappeared during the retries → `lock released`, exit 0.
- A lock that disappears between the tool's first look and its read: `status` prints `free`;
  `update` / `release` print `no lock to update` / `no lock to release` (exit 1, as before when
  there is no lock); `update` whose lock disappeared during the retries prints `no lock to
  update`, exit 1.
- `acquire` whose holder disappears between the failed create and the read creates the lock
  again (at most 40 rounds; beyond that `refused: the run lock <path> could not be created: it
  kept appearing and disappearing; nothing changed - try again`, exit 1).

Errors other than `PermissionError` are not retried and behave as before.
