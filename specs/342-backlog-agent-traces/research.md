# Research — 342 backlog loop traces and the two `bin/` commands

Measured on 2026-10-25 on this machine: Claude Code 2.1.310, Python from `PATH`,
Git Bash. The reference is `E:\Projects\2026_hscr_ai_chatbot` (read only),
feature 003, contract `specs/003-backlog-system/contracts/traces.md`.

## R1 — Where claude reports a session it does not know (FR-013, A4)

- **Measured**: `claude -p continue --resume <made-up uuid> --output-format stream-json --verbose`,
  stdin closed, in an empty folder. Exit 1. stdout: one `result` event,
  `subtype error_during_execution`, `is_error true`,
  `errors ["No conversation found with session ID: <uuid>"]`. stderr:
  `No conversation found with session ID: <uuid>`. No request reached the model
  (`total_cost_usd 0`).
- **Decision**: FR-013 and SC-005 are withdrawn. `loop.py` reads the text from the
  stderr tail (`LOST_RE` in `log_info`), and the text is there. The reference
  matched `errors` because it wanted one rule for two harnesses.
- **Alternative**: also match `errors` anyway, as belt and braces. Rejected:
  CLAUDE.md *Measure first*, the defect is not reachable here. If a later claude
  drops the stderr line, a lost session is treated as an error and stops after the
  backoffs. That is slow but safe.

## R2 — The reset time of a usage limit (A5)

- **Measured**: in all 284 old logs, the one real limit
  (`20261020-155105-backlog-fixture-empty-specs-folder-missing.jsonl`) carries a
  `rate_limit_event` with `status: rejected`, `resetsAt: 1792503600` and the text
  `You've hit your limit · resets 5pm`.
- **Decision**: no parsing of the text. `LogInfo.reset_at` already gets the time
  from the event.

## R3 — Writing the trace without touching the streaming

- **Finding**: `Loop.execute` hands claude the open log file as its stdout
  (`subprocess.Popen(..., stdout=out, stderr=err)`). The loop never pipes the
  output, and `watch` / `log_info` read the file from the attempt's byte offset
  (`run["offset"]`, `run["err_offset"]`).
- **Decision**: before each `Popen`, append the separator line to `trace.jsonl`
  and the header line to `stderr.log` through the same handles, flush them, then
  take the offsets. The verdict code is unchanged: it reads from the offset after
  the separator. The triage path (`Loop.triage`) does the same with its own
  `source` dict.
- **Alternative**: pipe the output through the loop and insert lines. Rejected:
  it adds a reader thread and a way to lose output when the loop dies while claude
  keeps running (FR-9 of 247: a claude left by a killed loop keeps writing to its
  file).

## R4 — Attempt reasons and endings

- **Reference values**: `reason` ∈ `-`, `usage-limit`, `error`, `stall`, `idle`,
  `restart`; `ending` ∈ `success`, `error`, `interrupted`; `error_kind` ∈
  `usage-limit`, `session-lost`, `other`, `null`.
- **Mapping of our verdicts** (`Loop.assess`, `Loop.conclude`) to the reason of
  the *next* attempt: `limit` → `usage-limit`; `error` → `error`; `stalled` →
  `stall`; idle kill → `idle`; a run cut off (phase `running` / `killed` / `new` at
  a pending-run check: Ctrl+C, a killed loop, a reboot) → `killed`. `killed` is our
  one addition to the reference values (spec FR-005). `restart` is never written.
- **Ending of an attempt** from `LogInfo`: a successful result → `success`; an
  error result → `error` (`error_kind` from `limited` / `lost` / else `other`); no
  result → `interrupted`. `idle_killed` is true when `watch` killed it.
  `exit_code` comes from `Popen.returncode`, and is `null` for a claude left by an
  earlier loop. `usage` is the result's `usage` object.

## R5 — `meta.json` fields and the `counters` mapping

- `counters` keeps the reference keys. `limits` = `run["limits"]`; `errors` =
  `run["attempts"]` (247's name for the error count); `stalls` = `run["stalls"]`;
  `idles` = `run["nudges"]`; `restarts` = 0.
- `harness_version` = the first word of `claude --version`, read once when the loop
  starts (`2.1.310`), or `null` when that fails. `model` = `--model`, else the
  `model` of the trace's first `system/init` event, else `null`.
- `phase` = `run["phase"]` while the run lives, `done` when it finished.
  `failed` / `lost` stay when it stops for a person.
- `why` = `run["why"]`.
- `loop` = `{pid, host, auto_triage}`.
- Written by one function called from `save_run()` (every phase change already
  goes through it) and at the end of each attempt. It writes atomically:
  `backlog.write_text` to a temporary file, then replace.

## R6 — Importing the old logs

- **Old layout**: `<YYYYMMDD-HHMMSS>-<slug>.jsonl` / `.err`, with triages as
  `<stamp>-auto-triage`. 284 files, 547 MB, 142 runs - 95 item runs, 47 auto-triages (one pair per run; a
  continued run appends to its pair). There are no separators.
- **Measured during implementation (corrects the plan)**: `system/init` is
  written at **every turn** of one claude process, after a scheduled wakeup or a
  task notification, not once per process. A run closed in one attempt
  (`20261024-121738-iso-…`) has 2; the 341 run has 7, at lines 0, 1047, 1389,
  1841, 1843, 2256 and 2258, some of them right after a `result` of the same
  process. The old logs therefore do not show where an attempt started.
  Imported runs record `attempts: []` and the index `attempts: null`. The
  separator lines of the new format exist to close exactly this gap.
- **Decision**: `start` imports by itself, before the pending-run check, when
  `.git/tandem-backlog-loop/imported.json` does not exist. Each pair becomes
  `.agent-traces/<stamp>-claude-<slug|triage>/`: a byte copy of `trace.jsonl` and
  `stderr.log`, plus `meta.json`:
  - `imported: true`;
  - `started` from the name;
  - `ended` = the `.jsonl` modification time;
  - `session_id` and `model` from the first `system/init`;
  - `attempts` = `[]` and `counters` all `null` (unknown, see above);
  - `outcome` / `feature` / `branch` from the first `RUNS.md` row of the slug
    written at or after the start minute and before the next old log of the same
    slug;
  - `commits` by the FR-009 rule;
  - `phase` `done` when a row matched, else `null`.

  Index lines are appended in name order, which is start order. Then
  `imported.json` records the date and the count.
- **Move, not copy** (the maintainer, during implementation): each folder is built
  as `<name>.part`, its two files are compared byte for byte with the old ones,
  it is renamed to its final name, its index line is appended, and only then is
  the old pair deleted. The emptied `logs/` folder is removed. An import cut off
  midway leaves at most a `.part` folder, which the next run of the import
  rebuilds, and never a lost log.
- **A pending run that can still be continued** (`run.json` with `log` in the old
  folder, any phase but `failed` / `lost`) is skipped by the import, by name. It
  is migrated in `Loop.pending` once any claude a previous loop left running has
  ended, so nothing is still writing to the old file. Its folder gets the same
  name the import would give it, its content is copied with offsets unchanged (no
  separator is put before old content), the old pair is deleted, and `run.json`
  gets `trace`.
- **A failed or lost pending run** is only ever dropped (`--forget-run`), so it
  moves with the rest. Its `run.json` is pointed at the new folder (`trace`, `log`,
  `err`, `indexed: true`), so `status` shows it and `--forget-run` does not index
  it twice. Found in the real state: the 341 run (phase `failed`, finished by
  hand).
- **Why automatic**: nothing to remember. The index stays in start order because
  the import runs before the first new run. The pending-run migration needs the
  same code anyway. A marker in the loop's state folder (not in the old folder,
  not in `.agent-traces/`) keeps a deleted trace from being imported again.
- **Alternative**: an `import-logs` command. Rejected: a sixth command for a
  one-time step, and if it ran after new runs the index would be out of order.

## R7 — Finding a run's commits (FR-009)

- **Subjects used** (SKILL.md of `tandem-backlog-implement` §0.10 and its outcome
  table, `tandem-backlog` §2.5a):
  - feature work: `[NNN] …`;
  - runs without a feature: `backlog: <slug> …` (`closed - not reproduced at …`,
    `not reproduced at …`, `blocked (NNN)`, `blocked before specify`,
    `split into n items`);
  - nothing eligible: `backlog: run found nothing to do`;
  - triage: `backlog: auto-triage - …`.
- **Decision** (amended during implementation): the loop records `base` = `HEAD`
  when a run or a triage starts, and takes
  `git log --all --reverse --format=%h%x00%s ^<base>`. It keeps the subjects that
  start with `[<feature>]` or `backlog: <slug> `, or for a triage
  `backlog: auto-triage`. `--all` covers a feature branch that was not merged
  (blocked runs). Only imported runs, which have no base, use
  `--since=<started> --until=<ended>`. Measured: with times, the second of two
  triages a few seconds apart also took the first one's commit (git dates have
  one-second steps).
- **Alternative**: a `Backlog-Item:` trailer (the reference). Rejected: it changes
  the skill's commit rules, and the subjects already identify the run.

## R8 — `bin/backlog.sh` and `bin/backlog-loop.sh`

- **Today**: `bin/backlog.sh` is the loop (`exec python -u tools/backlog/loop.py "$@"`,
  its own usage text). `tools/test_bin_help.py` runs every file in `bin/` with
  `--help` and wants exit 0, `usage` in stdout, and at least 3 lines.
  `test_loop.py` tests the wrapper (`BIN`, lines 826–862).
- **Decision**:
  - `git mv bin/backlog.sh bin/backlog-loop.sh`, then change its texts to
    `bin/backlog-loop.sh`. Its tests point at the new path.
  - The new `bin/backlog.sh` runs `exec "${PYTHON:-python}" tools/backlog/backlog.py "$@"`
    with `TANDEM_BACKLOG_PROG=bin/backlog.sh`, so argparse names the script in its
    usage lines (`build_parser(prog=…)`).
  - `--help` / `-h` / `help` / no command print a short header (what the script is
    for, that `bin/backlog-loop.sh` controls the loop, where the contract is), then
    argparse's own help, which lists every command with its one-line help. That way
    the command list cannot drift from the code.
  - No command: the same text to stderr, exit 2 (like the loop script).
- **Old loop words** are not treated specially (Clarifications Q3). Measured:
  `python tools/backlog/backlog.py pause` → argparse `invalid choice`, exit 2;
  `start` without a slug → `the following arguments are required`, exit 2. Nothing
  is written in either case.
- **Skills**: the alias line `BL = python tools/backlog/backlog.py` in each skill
  becomes `BL = bin/backlog.sh`. Every other mention follows. In the loop's
  messages, `python tools/backlog/backlog.py check` becomes `bin/backlog.sh check`.

## R9 — Where the old names live (FR-018, FR-020, SC-008)

`git grep` for `python tools/backlog/(backlog|loop).py`, `bin/backlog.sh`, and
`tools/backlog/loop-*.sh`, outside earlier feature folders:

| File | Hits | What changes |
|---|---|---|
| `tools/backlog/loop.py` | 35 | messages, docstring, status lines → `bin/backlog-loop.sh …` / `bin/backlog.sh check` |
| `.claude/skills/tandem-backlog/SKILL.md` | 9 | alias, loop commands |
| `.claude/skills/tandem-backlog-implement/SKILL.md` | 2 | alias |
| `.claude/skills/tandem-release/SKILL.md` | 1 | the tool call |
| `backlog/items/backlog-loop-person-checks/desc.md` | 9 | the person's steps (body text, hand edit allowed) |
| `bin/backlog.sh` | 8 | becomes `bin/backlog-loop.sh` |
| `backlog/BACKLOG.md`, `backlog/RUNS.md` (+ the fixture copies in `tools/backlog/fixtures/valid/`) | 1 each | prose intro |
| `CLAUDE.md` | 1 | the *Where things are* row |
| `tools/backlog/test_loop.py` | 3 | the wrapper path and texts |
| `specs/FEATURE-HISTORY.md` | 2 | history, left as is; the 342 entry says what changed |

Also amended (binding contracts, FR-016 / FR-020):
`specs/242-backlog-system/contracts/cli.md` and `skills.md`, and
`specs/247-backlog-run-loop/contracts/loop-cli.md`.

## R10 — Status speed with traces never deleted (SC-004)

- **Decision**: the size is a walk with `os.scandir`, recursing into the run
  folders and summing `stat().st_size`. 1,000 folders × 3 files = 4,000 `stat`
  calls, measured in the test (`--json`, wall clock < 2 s on a generated tree of
  sparse files). No cache: a cache would be state that can go stale.

## R11 — The ignore rule

- `/.agent-traces/` added to `.gitignore` (anchored at the root, like `/build`).
  The loop's precheck is `git status --porcelain` and honours `.gitignore`.
  `backlog.py check` looks only under `backlog/`.
