# Contract - `bin/backlog.sh lock` under a concurrent reader (411)

Unchanged: arguments, the lock file format, every output line and exit code of
`specs/242-backlog-system` / 247 / 344 when no other process holds the lock file open.

Added:

| Action | Another process has the lock open (PermissionError) | ... for longer than the window (about 2 s) |
|---|---|---|
| `status` | waits, then prints the holder line or `free` | `refused: the run lock <path> could not be read: another process holds it open (<OS error>); nothing changed` - exit 1 |
| `acquire` | waits, then `lock acquired: <path>` or `another run in progress: ...` | `refused: the run lock <path> could not be created: ...; nothing changed` - exit 1 |
| `update` | waits, then `lock updated: branch <b>` - exit 0 | `refused: the run lock <path> could not be updated: ...; nothing changed` - exit 1; the lock keeps its bytes, no `*.tmp~` left |
| `release` (`--force`) | waits, then `lock released` - exit 0 | `refused: the run lock <path> could not be released: ...; nothing changed` - exit 1; the lock stays |

A lock that disappears between the tool's existence check and its read is treated as no lock:
`status` prints `free`; `update` / `release` print `no lock to update` / `no lock to release`
(exit 1, as before when there is no lock).

Errors other than `PermissionError` are not retried and behave as before.
