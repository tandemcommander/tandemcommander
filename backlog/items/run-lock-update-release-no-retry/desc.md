---
title: Run lock update and release fail when a reader holds the lock open
type: bug
status: open
severity: 4
area: tooling
source: review:344
who: agent
created: 2026-10-30
updated: 2026-10-30
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Run lock update and release fail when a reader holds the lock open

## Problem

`bin/backlog.sh lock update` replaces `.git/tandem-backlog-run.lock` with `os.replace` and `lock release` deletes it with `Path.unlink`, both without a retry. On Windows both fail with `PermissionError` (WinError 5 / 32) while another process has the file open without share-delete, which is how Python's `open` reads it. Readers poll the lock all the time: `bin/backlog-loop.sh status --json` (the loop between runs, and since feature 344 the backlog app every 2 seconds while it is open), `bin/backlog.sh lock status`. A run whose `lock update` (after it creates its branch) or `lock release` (at its end) meets such a read fails that step: the run stops with an unexpected tool error, or ends with the lock still held, which closes the backlog app's write gate and makes the loop wait until a person releases it.

## Evidence

At a34796f5: `tools/backlog/backlog.py` `cmd_lock` (line 1883): `update` calls `write_text` (line 190, `os.replace(tmp, path)`, no retry); `release` calls `path.unlink()` (line 1921, no retry). The loop's own atomic writer `tools/backlog/traces.py` `write_json_atomic` retries `PermissionError` 40 times at 50 ms for exactly this reason (feature 342). Measured in feature 344: a reader that opens a file in a tight loop makes `os.replace` of that file fail with WinError 5 (`specs/344-backlog-web-app/fix-log.md`, the tailer finding). Found by the independent review of feature 344 (note on run lock reads). Not reproduced against the lock itself: the window per read is microseconds, so a failure is rare, not observed.

## Expected

`lock update` and `lock release` retry a `PermissionError` for a short time (as `write_json_atomic` does) and report a clear refusal only when it persists; a test opens the lock from another process during the call and the call still succeeds.

## Log

- 2026-10-30 — created (source review:344)
- 2026-10-30 — moved to Next position 33
