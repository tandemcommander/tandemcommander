# Data model - 411

## Run lock (unchanged)

File `.git/tandem-backlog-run.lock` (tests: `--lock-dir`), UTF-8, LF, four lines:

```text
started: <ISO time>
slug: <item slug or ->
branch: <branch or ->
host: <host name>
```

States: **free** (no file) → `acquire` → **held** (slug, branch `-` or given) → `update` →
**held** (branch set) → `release` → **free**. `release --force` releases any holder.

New in 411: every transition and every read retries a `PermissionError` within the retry window
(40 x 50 ms); a transition that cannot complete in the window is refused and the state stays as
it was. A file that vanishes during a read is **free**.
