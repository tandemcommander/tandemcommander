# Contract — the backlog's two commands in `bin/` (feature 342)

Git Bash. Like every script in `bin/`, both answer `--help`
(`tools/test_bin_help.py`). No other backlog script lives in `bin/`.

## `bin/backlog.sh <command> [options]` — the backlog

Runs `exec "${PYTHON:-python}" tools/backlog/backlog.py "$@"` with
`TANDEM_BACKLOG_PROG=bin/backlog.sh`, so the tool's usage lines name the script.
Every command, option, output and exit code is the tool's, as in
`specs/242-backlog-system/contracts/cli.md`: `check`, `sync`, `list`, `next`,
`new`, `import-github`, `set`, `log`, `verify`, `move`, `block`, `unblock`,
`start`, `remove`, `run-log`, `lock …`, and the global `--root`.

| Invocation | Effect | Exit |
|---|---|---|
| `bin/backlog.sh --help` (`-h`, `help`) | header (what it is for, `bin/backlog-loop.sh` for the loop, this contract) + the tool's help listing every command | 0 |
| `bin/backlog.sh` | the same text to stderr | 2 |
| `bin/backlog.sh <command> --help` | the tool's help of that command | 0 |
| `bin/backlog.sh <command> …` | the tool's command | the tool's (0, 1, 2) |
| `bin/backlog.sh pause` / `status` / `start` without a slug | the tool's usage error, nothing written (no hint, no alias; Clarifications Q3) | 2 |

The skills use it as `BL = bin/backlog.sh`.

## `bin/backlog-loop.sh <command> [options]` — the loop

The loop of feature 247 under a new name (it was `bin/backlog.sh` from 2026-10-24
to 342). Commands `start`, `pause`, `resume`, `stop`, `status` with every option,
exit code and help of `specs/247-backlog-run-loop/contracts/loop-cli.md`, which is
amended:

- *Files*: the run output is in `.agent-traces/` ([traces.md](traces.md)), not in
  `.git/tandem-backlog-loop/logs/`. `imported.json` is new there. Nothing is
  pruned any more.
- *Status*: `log:` becomes `trace: <run folder> (traces total: <size>)`. `--json`
  gains `trace` (the run folder or `null`) and `traces_bytes`.
- Every message names `bin/backlog-loop.sh …` for the loop and `bin/backlog.sh …`
  for the tool (`bin/backlog.sh check`).
