# Quickstart - validating 411

From the repository root (Git Bash):

1. Unit tests - all pass, the new `LockHeldOpenTests` included (Windows):

   ```text
   python -m unittest tools/backlog/test_backlog.py tools/backlog/test_loop.py tools/backlog/test_traces.py
   ```

2. The measurement of the item, repeated (fix-log *Before* / *After*): `python specs/411-lock-retry-permission/probe/repro_lock.py "$(pwd -W)"` acquires a lock in a temporary `--lock-dir`, holds it open from a
   second process for 0.5 s and 5 s, and runs `lock update` / `lock release` meanwhile.
   Expected after the fix: 0.5 s → both exit 0 (`lock updated: branch b2`, `lock released`);
   5 s → both exit 1 with one `refused:` line (no traceback), the lock still there.

3. The backlog itself: `bin/backlog.sh check` → `TOTAL: 0`; `bin/backlog.sh lock status`
   prints the holder line as before.

Contract: [contracts/lock-commands.md](contracts/lock-commands.md).
