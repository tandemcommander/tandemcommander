# Tasks: Backlog loop traces in `.agent-traces/` and two `bin/` commands

**Input**: `specs/342-backlog-agent-traces/` (spec.md, plan.md, research.md,
data-model.md, contracts/traces.md, contracts/bin-commands.md, quickstart.md)

**Tests**: requested by the spec (SC-001, SC-003, SC-004, SC-006, SC-007), so each
story has test tasks. The tests drive the real loop with
`tools/backlog/fixtures/fake_claude.py` (plan of steps via `FAKE_CLAUDE_PLAN`) as
the 247 tests do. Run them with
`python -m unittest tools/backlog/test_traces.py tools/backlog/test_loop.py tools/backlog/test_backlog.py tools/test_bin_help.py`.

**Rules for every task**: Python standard library only. Files are UTF-8 without
BOM with LF line ends, like the existing `tools/backlog/*.py`. Comments and
messages in English. Write scripts with the editor tools, not Bash
here-documents (CLAUDE.md, 123). Keep `specs/342-backlog-agent-traces/fix-log.md`
current after each phase.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1 traces per run, US2 index + status, US3 import of the old logs,
  US4 the two `bin/` commands

---

## Phase 1: Setup

- [X] T001 Add the line `/.agent-traces/` with a comment `# feature 342: traces of the backlog loop (input for evals, never committed)` to `.gitignore` (after the `/tools/salbreak/` block); check `git check-ignore -v .agent-traces/x` names that line
- [X] T002 Create `tools/backlog/traces.py` (SPDX header as in `loop.py`, module docstring citing `specs/342-backlog-agent-traces/contracts/traces.md`) with the constants `TRACES_DIR = ".agent-traces"`, `INDEX = "index.jsonl"`, `FORMAT_VERSION = 1`, `SEPARATOR_TYPE = "backlog_loop.attempt"`, `HARNESS = "claude"`, `REASONS = ("-", "usage-limit", "error", "stall", "idle", "killed")`, and an empty `tools/backlog/test_traces.py` (SPDX header, `unittest` main, `sys.path` insert of its folder as in `test_loop.py`)

---

## Phase 2: Foundational (pure builders every story uses)

**⚠️ Blocks US1–US3.** US4 does not depend on this phase.

- [X] T003 In `tools/backlog/traces.py` add `iso_local(t: float | None) -> str | None` (ISO 8601 local time with offset, seconds precision, e.g. `2026-10-25T14:02:00+02:00`; `None` → `None`) and `stamp_name(t: float) -> str` (`YYYYMMDD-HHMMSS` local)
- [X] T004 In `tools/backlog/traces.py` add `new_run_dir(root: Path, slug: str, started: float) -> Path`: creates `<root>/.agent-traces/<stamp>-claude-<slug>` (`slug` is the item slug or `triage`), appending `-2`, `-3` … while the name exists (`mkdir(exist_ok=False)` in a loop, so two loops cannot share one); returns the path
- [X] T005 In `tools/backlog/traces.py` add `separator_line(attempt, kind, reason, started, session) -> bytes` (one JSON object with the keys of the contract in this order: `type`, `attempt`, `kind`, `reason`, `started`, `harness`, `session_id`; compact separators; `\n`) and `stderr_header(attempt, kind, reason, started) -> bytes` (`=== attempt N (<kind>, <reason>) <started> ===\n`); raise `ValueError` for a reason outside `REASONS` or a kind outside `start` / `continue`
- [X] T006 In `tools/backlog/traces.py` add `write_json_atomic(path: Path, data: dict)` (write `path.with_name(path.name + ".tmp~")`, then `os.replace`; retry `PermissionError` 40× 50 ms like `loop.save_json`) and `append_line(path: Path, data: dict)` (one `write` of the JSON line opened in `ab`)
- [X] T007 In `tools/backlog/traces.py` add `build_meta(record: dict, *, phase, ended, outcome, feature, branch, commits, why, loop_info: dict, harness_version, model) -> dict` returning the exact key order of the contract's `meta.json` (`format_version` … `loop`), where `record` carries `kind`, `slug`, `session`, `started` (epoch), `trace_attempts` (list of attempt dicts with the contract's keys) and the 247 counters `limits`, `attempts`, `stalls`, `nudges`; map them to `counters` per research R5 (`errors` = `attempts`, `idles` = `nudges`, `restarts` = 0); and `build_index_line(meta: dict, dir_name: str) -> dict` with the contract's keys (`attempts` = `len(meta["attempts"])`)
- [X] T008 In `tools/backlog/traces.py` add `run_commits(root: Path, started: float, ended: float, *, slug, feature, kind) -> list[str]`: `git log --all --reverse --since=@<started> --until=@<ended> --format=%h%x00%s` (through `subprocess`, `cwd=root`, UTF-8, `[]` on any error); keep subjects starting with `[<feature>]` (when `feature` is not `None`) or `backlog: <slug> ` for an item, `backlog: auto-triage` for a triage (research R7)
- [X] T009 In `tools/backlog/traces.py` add `traces_size(root: Path) -> int` (recursive `os.scandir` over `.agent-traces/`, sum of `stat().st_size` of files, 0 when the folder is missing, ignoring files that vanish meanwhile) and `format_size(n) -> str` (`B`, `kB`, `MB`, `GB` with one decimal above bytes)
- [X] T010 [P] Unit tests in `tools/backlog/test_traces.py` for T003–T009: name collision suffixes; the exact bytes of a separator and a header; refused reason / kind; atomic write leaves no `.tmp~`; key order and values of `build_meta` (counters mapping, `null`s) and `build_index_line`; `run_commits` on a temporary git repository with commits `[343] a`, `backlog: some-slug blocked (343)`, `backlog: other-slug x`, `backlog: auto-triage - 1 placed` (item with feature, item without, triage); `traces_size` on a generated tree

**Checkpoint**: `python -m unittest tools/backlog/test_traces.py` passes.

---

## Phase 3: User Story 1 — every run leaves a complete, self-describing trace (P1) 🎯 MVP

**Goal**: each item run and each auto-triage writes `.agent-traces/<stamp>-claude-<slug|triage>/` with `trace.jsonl` (separators), `stderr.log` (headers) and `meta.json`; nothing goes to `.git/tandem-backlog-loop/logs/` any more.

**Independent test**: the RunTests / AutoTriageTests scenarios of `test_loop.py`, with each run folder checked against `contracts/traces.md` and `git status --porcelain` empty.

### Tests for User Story 1

- [X] T011 [US1] In `tools/backlog/test_loop.py` add a helper `trace_dirs(self)` (sorted folders of `<root>/.agent-traces/`, except `index.jsonl`) and `check_trace(self, d, *, kind, slug, attempts, reasons, phase, outcome)` that parses `trace.jsonl`, finds the separator lines (`type == backlog_loop.attempt`) and asserts their count, numbering, kinds and reasons. It also asserts that `stderr.log` has the same number of `=== attempt` headers, and that `meta.json` has the contract keys, `harness` `claude`, the `phase` / `outcome`, and `len(attempts)`
- [X] T012 [US1] In `tools/backlog/test_loop.py` extend the existing scenarios with `check_trace` asserts: a closed run (1 attempt, reason `-`, phase `done`, outcome `closed`, `feature` and `branch` from the journal row, `commits` non-empty); a limit then close (attempts 2, reasons `-`, `usage-limit`); a crash then close (`error`); a stall (`stall`); an idle kill (`idle`, `attempts[0].idle_killed` true); Ctrl+C then a new start that continues (`killed`); a refused run; an unrecorded run; a lost run (phase `lost`); an auto-triage (`kind` `triage`, folder `…-claude-triage`, outcome `triaged`). After each scenario, assert that `git status --porcelain` in the fixture is empty and that `.git/tandem-backlog-loop/logs` does not exist
- [X] T013 [US1] In `tools/backlog/fixtures/fake_claude.py` make `system/init` (line 257) also carry `"model": "fake-model"`, and make every `result` it emits carry a `"usage": {"input_tokens": 1, "output_tokens": 1}` object, so `model` and `attempts[].usage` can be asserted; keep every existing step's behaviour

### Implementation for User Story 1

- [X] T014 [US1] In `tools/backlog/loop.py` import `traces`; in `Loop.__init__` read `harness_version` once (`[*self.claude, "--version"]`, 10 s timeout, first word of stdout, `None` on any error or with a `--claude-cmd` that does not answer), and remove `Repo.logs`, `KEEP_LOGS` and `Loop.prune_logs` together with its call in `Loop.main`
- [X] T015 [US1] In `Loop.new_run` (`tools/backlog/loop.py`) create the run folder with `traces.new_run_dir(root, slug, time.time())` and store `trace` (its path), `trace_attempts: []`, `indexed: False`, `next_reason: "-"` in `run.json`; keep `log` / `err` keys pointing to `<trace>/trace.jsonl` and `<trace>/stderr.log`, so `log_info`, `watch` and `assess` keep working unchanged
- [X] T016 [US1] In `Loop.execute` (`tools/backlog/loop.py`), after opening `out` / `err` and **before** `Popen`, write `traces.separator_line(n, "continue" if resume else "start", run["next_reason"], iso_local(now), run["session"])` to `out` and `traces.stderr_header(...)` to `err`, flush both, *then* take `run["offset"]` / `run["err_offset"]`; append the attempt dict (`attempt`, `kind`, `reason`, `started`, the rest `None`, `usage` `{}`) to `run["trace_attempts"]`; after the process ends, record `exit_code` (`self.child.returncode`)
- [X] T017 [US1] In `tools/backlog/loop.py` add `Loop.close_attempt(info: LogInfo, verdict: str)`, called once per attempt where `assess` has taken its verdict (in `conclude`, and in `pending` for an attempt whose claude a previous loop started). It sets `ended`, `ending` (`success` / `error` / `interrupted` from `info.result` / `info.is_error`), `error_kind` (`usage-limit` if `info.limited`, `session-lost` if `info.lost`, else `other` for an error, else `None`), `resets_at` (`iso_local(info.reset_at)`), `idle_killed` (`run.get("idle")`) and `usage` (the result's `usage` or `{}`). It also sets `run["next_reason"]` from the verdict per research R4: limit → `usage-limit`, error → `error`, stalled → `stall`, idle → `idle`. In `pending`, a run found in phase `running` / `killed` / `new` gets `next_reason = "killed"` before it is continued
- [X] T018 [US1] In `tools/backlog/loop.py` add `Loop.write_meta(phase=None)`: `traces.build_meta(...)` with the journal row of the run (`our_row`, extended to return the whole row so `feature` (column 4) and `branch` (column 5) are read, `-` → `None`), `commits` via `traces.run_commits` once the run has ended, `model` = `args.model` or the `model` of the first `system/init` of the trace, `loop_info` = `{pid, host, auto_triage}`; write it with `traces.write_json_atomic(<trace>/meta.json)`. Call it from `save_run()` (every phase change) and after `close_attempt`. Phase `done` when the verdict is `finished`
- [X] T019 [US1] In `Loop.triage` (`tools/backlog/loop.py`) build the triage's `source` with a run folder from `traces.new_run_dir(root, "triage", now)`, the separator (attempt 1, `start`, `-`) and the header written before `Popen` as in T016, `log` / `err` inside the folder, and a `meta.json` (kind `triage`, slug `triage`) written at start and at the end (`outcome` `triaged` on a successful result, `phase` `done`; `failed` on a stop for a person; `commits` per T008)
- [X] T020 [US1] In `tools/backlog/loop.py` change every message that names a log (`log {Path(run['log']).name}`, `log {run['log']}`, `logs in …`, `log {source['log']}`) to name the run folder (`trace .agent-traces/<name>`), and rename the `log` key of `loop.json` (`write_state`, line ~539) to `trace` holding the run folder

**Checkpoint**: US1 tests pass; a fixture run leaves complete folders and a clean tree.

---

## Phase 4: User Story 2 — find and size runs without reading streams (P1)

**Goal**: `index.jsonl` gets exactly one line per ended run; `status` shows the trace folder and the total size; nothing is ever deleted.

**Independent test**: after the US1 scenarios, `index.jsonl` has one line per ended run (none for a run still pending); `status` and `status --json` carry `trace` and the size; 105 runs' folders all survive.

### Tests for User Story 2

- [X] T021 [P] [US2] In `tools/backlog/test_loop.py` assert after each scenario of T012 that `index.jsonl` has exactly one line per ended run with the contract's keys and `dir` equal to the folder name. Add a scenario where Ctrl+C is followed by a new start that finishes the run (one line, not two), and a `failed` run followed by `--forget-run` (one line, written at the stop; `indexed` prevents a second)
- [X] T022 [P] [US2] In `tools/backlog/test_loop.py` replace `PruneTests` with `KeepTracesTests`: create 105 run folders, run the loop `--until-idle` once, assert all 105 still exist; and a status test: `status` prints a `trace:` line with `traces total:` and no `log:` line, and `status --json` has `trace` and an integer `traces_bytes`
- [X] T023 [P] [US2] In `tools/backlog/test_traces.py` add a timing test (SC-004): build 1,000 run folders with three files each (sparse 5 MB files via `truncate`, so 5 GB is not written), assert `traces_size` returns in under 2 s and gives the exact sum

### Implementation for User Story 2

- [X] T024 [US2] In `tools/backlog/loop.py` add `Loop.index_run(run_or_source)`: if `indexed` is not set, append `traces.build_index_line(meta, dir)` to `<root>/.agent-traces/index.jsonl` with `traces.append_line`, set `indexed = True` and save. Call it where a run record is dropped (`drop_run` for finished / refused / unrecorded, the `--forget-run` drop in `Loop.main`, which must index the record first), where phase becomes `failed` or `lost`, and at the end of every auto-triage
- [X] T025 [US2] In `cmd_status` (`tools/backlog/loop.py`) replace the `log:` line with `trace:   <run folder or -> (traces total: <format_size>)` and add `"trace"` and `"traces_bytes"` to the `--json` output; keep every other line as in `specs/247-backlog-run-loop/contracts/loop-cli.md` *Status*

**Checkpoint**: US1 + US2 tests pass, so the traces are complete and findable.

---

## Phase 5: User Story 4 — two commands in `bin/` (P2)

**Goal**: `bin/backlog.sh` runs the backlog tool; `bin/backlog-loop.sh` is the loop; everything that shows a command uses these.

**Independent test**: `bin/backlog.sh --help`, `bin/backlog.sh list --section next` (same output as through Python), `bin/backlog.sh pause` → exit 2 with nothing written, `bin/backlog-loop.sh --help` / `status`; `tools/test_bin_help.py`.

**Note**: independent of Phases 2–4. Plan step 1 suggests doing it first, and that order is allowed.

### Tests for User Story 4

- [X] T026 [P] [US4] In `tools/backlog/test_loop.py` point `BIN` (line 34) to `bin/backlog-loop.sh` and change the expected texts (lines ~779, 838, 850) from `bin/backlog.sh` to `bin/backlog-loop.sh`
- [X] T027 [P] [US4] In `tools/backlog/test_backlog.py` add `BinTests` (skip when Git Bash is not found, finding bash as `tools/test_bin_help.py` `git_bash()` does): `bin/backlog.sh --help` exit 0, stdout contains `bin/backlog-loop.sh` and every subcommand name of `backlog.build_parser()`; no command → exit 2, text on stderr; `bin/backlog.sh list --root <fixture> --json` equals `python tools/backlog/backlog.py --root <fixture> list --json` (pass `--root` the way argparse expects it: global option before the command); `pause` and `start` without a slug → exit 2 and the fixture's files unchanged (hash before and after); usage lines name `bin/backlog.sh`

### Implementation for User Story 4

- [X] T028 [US4] `git mv bin/backlog.sh bin/backlog-loop.sh`; in it, change the comment, the usage text and the error message from `bin/backlog.sh` to `bin/backlog-loop.sh`; add one line to its usage: `The backlog itself: bin/backlog.sh (list, show, next, check, …)`; mention that the run output goes to `.agent-traces/`
- [X] T029 [US4] Create `bin/backlog.sh` (SPDX header, LF, executable bit via `git update-index --chmod=+x`): for `-h|--help|help`, print a header (what it is for: check, list, show and change the backlog, feature 242; the loop is `bin/backlog-loop.sh`; contract `specs/342-backlog-agent-traces/contracts/bin-commands.md`; examples `bin/backlog.sh next`, `bin/backlog.sh list --section next`, `bin/backlog.sh check`), then `TANDEM_BACKLOG_PROG=bin/backlog.sh "${PYTHON:-python}" tools/backlog/backlog.py --help`, exit 0; with no argument print the same to stderr, exit 2; otherwise `TANDEM_BACKLOG_PROG=bin/backlog.sh exec "${PYTHON:-python}" "$here/../tools/backlog/backlog.py" "$@"`
- [X] T030 [US4] In `tools/backlog/backlog.py` `build_parser()` take `prog=os.environ.get("TANDEM_BACKLOG_PROG", "backlog.py")`, and in the module docstring add `Run it as bin/backlog.sh <command> (feature 342).`
- [X] T031 [US4] In `tools/backlog/loop.py` rename every `bin/backlog.sh` to `bin/backlog-loop.sh` (docstring lines 6–12, `say(...)` texts, status `todo:` and `Ctrl+C` texts) and `python tools/backlog/backlog.py check` to `bin/backlog.sh check` (line ~933); the module docstring names `.agent-traces/` (contract 342) in place of the logs folder
- [X] T032 [P] [US4] In `.claude/skills/tandem-backlog/SKILL.md` set the alias (line 44) to `BL = bin/backlog.sh` and change the loop commands (lines 77–98, 447 and any other) to `bin/backlog-loop.sh …`; the `compatibility:` front-matter line says `backlog/ and bin/backlog.sh (features 242, 342)`; do the same for every mention in `.claude/skills/tandem-backlog/reference.md`
- [X] T033 [P] [US4] In `.claude/skills/tandem-backlog-implement/SKILL.md` set the alias to `BL = bin/backlog.sh` and change the other mention; in `.claude/skills/tandem-release/SKILL.md` change its call of `python tools/backlog/backlog.py` to `bin/backlog.sh`
- [X] T034 [P] [US4] Change the prose: `backlog/BACKLOG.md` intro (`python tools/backlog/backlog.py sync` → `bin/backlog.sh sync`), `backlog/RUNS.md` intro (`appended by bin/backlog.sh run-log`), the same two lines in `tools/backlog/fixtures/valid/backlog/BACKLOG.md` and `RUNS.md`; the steps of `backlog/items/backlog-loop-person-checks/desc.md` (body text only, header untouched) to `bin/backlog-loop.sh …`; afterwards `bin/backlog.sh check` must print `TOTAL: 0`
- [X] T035 [P] [US4] In `CLAUDE.md` *Where things are*, the first row: `run one item autonomously with /tandem-backlog-implement (242), item after item with bin/backlog-loop.sh start (+ pause, resume, stop, status; 247, 342); the backlog tool is bin/backlog.sh (342)`. Keep the line short (the file says so)

**Checkpoint**: US4 tests and `tools/test_bin_help.py` pass; `bin/backlog.sh check` → `TOTAL: 0`.

---

## Phase 6: User Story 3 — the old logs join the new layout (P3)

**Goal**: the first `start` after 342 migrates a pending old run, then imports the 94 old runs once, with a marker; the old folder is untouched.

**Independent test**: a fixture with copies of a few old logs: folders and index lines appear, content byte-identical, the second start imports nothing even after deleting a folder, and the old folder's file hashes are unchanged.

### Tests for User Story 3

- [X] T036 [P] [US3] Add small fixtures in `tools/backlog/fixtures/old_logs/`, cut from real old logs to a few KB each, keeping `system/init`, a few events and the `result`: an item closed in one attempt (`20261024-121738-<slug>.jsonl/.err`), an item continued once (two `system/init`), an auto-triage (`…-auto-triage.jsonl/.err`), and a log whose slug has no `RUNS.md` row. Add the matching rows to a fixture `RUNS.md` built in the test
- [X] T037 [US3] In `tools/backlog/test_traces.py` test the pure import parts: name parsing (`<stamp>-<slug>` / `auto-triage` → `triage`), attempt count from `system/init` events, `session_id` / `model` from the first init, RUNS.md matching (first row of the slug at or after the start minute and before the next old log of the same slug; none → `null`s, phase `null`)
- [X] T038 [US3] In `tools/backlog/test_loop.py` add `ImportTests`: (a) the first `start` (`--until-idle`, nothing eligible) imports every fixture pair, so the folders exist, `trace.jsonl` / `stderr.log` equal the old files byte for byte, `meta.json` has `imported: true`, `index.jsonl` has one line each in name order, `imported.json` exists, and the old files' hashes are unchanged; (b) delete one imported folder, start again, nothing is imported and the index is unchanged; (c) a pending `run.json` whose `log` is an old file: the start moves it into a run folder of the same name, offsets unchanged, the import skips it, and the run is continued there (the fake plays `close`), giving one index line for it

### Implementation for User Story 3

- [X] T039 [US3] In `tools/backlog/traces.py` add `parse_old_name(name) -> (stamp_epoch, slug, kind)`, `scan_old_log(path) -> {session_id, model, attempts}` (stream the file line by line; count `system/init`), `match_runs_row(rows, slug, started, next_started) -> row | None`, and `import_old_logs(root, logs_dir, runs_rows, skip_names) -> (imported, skipped)`. The last copies each pair with `shutil.copyfile` into a new run folder named `<stamp>-claude-<slug|triage>` (skipping names that exist or are in `skip_names`), writes `meta.json` (`imported: true`, attempts `[{attempt, kind}]`, `ended` = the `.jsonl` mtime, `commits` per T008, `phase` `done` when a row matched, else `None`) and appends index lines in name order
- [X] T040 [US3] In `tools/backlog/loop.py`: (1) in `Loop.pending`, right after it has waited for a claude left by a previous loop, if `run.json` names a `log` outside `.agent-traces/`, migrate it (new folder named after the old file's stem with `-claude-` inserted; copy `log` → `trace.jsonl` and `err` → `stderr.log`; set `trace`, `log`, `err`, `trace_attempts` = one entry per `system/init`, `next_reason` `killed` if its phase says it was cut off; save); (2) in `Loop.main`, right after `register()` and the `--forget-run` handling, if `.git/tandem-backlog-loop/imported.json` is missing and the old `logs/` folder exists, run `traces.import_old_logs` with `skip_names` = the stem of a pending run's old `log` (it is migrated by (1), never imported as ended), write `imported.json` (`{"date", "imported", "skipped"}`) and say `imported N old run logs into .agent-traces/; .git/tandem-backlog-loop/logs/ can be deleted`

**Checkpoint**: all stories pass their tests.

---

## Phase 7: Polish & cross-cutting

- [X] T041 [P] Amend `specs/247-backlog-run-loop/contracts/loop-cli.md` with a dated note (`amended 2026-10-25, feature 342`): the script is `bin/backlog-loop.sh`; *Files*: run output in `.agent-traces/` per `specs/342-backlog-agent-traces/contracts/traces.md`, no pruning, `imported.json`; *Status*: the `trace:` line and the `--json` keys; *Auto-triage*: the folder `…-claude-triage`
- [X] T042 [P] Amend `specs/242-backlog-system/contracts/cli.md` (invocation `bin/backlog.sh [--root <repo>] <command> [options]`, Python file as the implementation) and `specs/242-backlog-system/contracts/skills.md` (the alias) with the same dated note
- [X] T043 Add the entry `- 342-backlog-agent-traces:` to `specs/FEATURE-HISTORY.md` in the backlog area. It records: traces in `.agent-traces/` in the reference format, never deleted, `status` size; `bin/backlog.sh` = the tool, `bin/backlog-loop.sh` = the loop (old `bin/backlog.sh start` is a usage error); the one-time import with its marker. Traps: the separator is written before `Popen` because claude writes straight into the file; `errors` vs stderr measured (R1); the commit filter by subject. Add one sentence to the 247 entry pointing to 342 for the new place of the logs
- [X] T044 Run the SC-008 search of `quickstart.md` §4 and fix every hit outside the history records
- [X] T045 Run the full test set (`test_traces.py`, `test_loop.py`, `test_backlog.py`, `tools/test_bin_help.py`) and `python tools/check_encoding.py` (strict, `TOTAL: 0`); record the counts in `fix-log.md`
- [X] T046 Run `quickstart.md` §3 (import on a scratch clone with a copy of the real old logs). Expect 94 folders, 94 index lines and `cmp` equal; then the second start imports nothing and `git status --porcelain` is empty. Record it in `fix-log.md`
- [X] T047 Independent review (CLAUDE.md *Working method*, refute-first): one Agent (`general-purpose`) given the spec, the contracts and `git diff main...342-backlog-agent-traces`. It is asked to make the loop lose trace bytes, write two index lines for one run, leave the tree dirty, pick the wrong commits, or break a 247 behaviour (verdicts, continuation, Ctrl+C), and to run the test suites and a negative control (revert T016 and show a test failing). Fix MUSTs; record findings in `fix-log.md`
- [X] T048 Write `specs/342-backlog-agent-traces/closing-report.md` (what changed, measurements, review, what is owed to a person: the first real loop run after the merge, `quickstart.md` *Owed to a person*)

---

## Dependencies & execution order

- **Phase 1 → Phase 2 → US1 → US2 → US3**: US2's index needs US1's run record fields (`trace`, `indexed`); US3's import reuses the Phase 2 builders and US1's meta.
- **US4** depends on nothing in Phases 2–4 (it touches `loop.py` messages only, and T031 also renames the messages T020 introduces). Doing US4 first, as plan step 1, is fine. If it goes after US1, T031 also covers the texts of T020.
- **Polish** after all stories; T047 (review) after T045 / T046.
- Within a story: tests first (they fail), then the implementation tasks in ID order; the `loop.py` tasks are sequential (one file).

## Parallel opportunities

- T010 alongside T011–T013 (different files) once T003–T009 exist.
- T021, T022, T023 together (two test files, independent asserts).
- T026, T027 together; T032, T033, T034, T035 together (skills, prose, CLAUDE.md are separate files).
- T036 with T037; T041 with T042.

## Implementation strategy

- **MVP = Phase 1 + 2 + US1**: every run already has its complete trace in the new place.
- **+ US2**: findable and sized. This is the state the spec's P1 asks for.
- **+ US4**: the two commands (may also come first).
- **+ US3**: the history joins.
- Commit after each phase with `[342] …` subjects. Do not merge to `main` before T047 has no open MUST.

## Summary

| Story | Tasks | Test tasks |
|---|---|---|
| Setup + Foundational | T001–T010 (10) | T010 |
| US1 (P1) | T011–T020 (10) | T011–T013 |
| US2 (P1) | T021–T025 (5) | T021–T023 |
| US4 (P2) | T026–T035 (10) | T026–T027 |
| US3 (P3) | T036–T040 (5) | T036–T038 |
| Polish | T041–T048 (8) | — |
| **Total** | **48** | |

## Implementation notes (2026-10-25)

Where the work differs from the task text above (details in `fix-log.md`):

- T013: the fake also gives each item its own feature number (`fake_feature`), and its
  commits use the skill's subjects (`[NNN] …`, `backlog: <slug> …`).
- T023: 1,000 folders of small files instead of 5 GB of sparse files. The walk costs one
  `stat` per file whatever the file size, and extending files on NTFS reserves the space.
- T029 / T032: the backlog tool has no `show` command (the reference's has); the help and
  the texts name `list` / `next` / `check`.
- T037 / T039: the attempts of an old log are not counted (`system/init` repeats at every
  turn): imported runs have `attempts: []`, index `attempts: null`.
- T039 / T040: the import **moves** the old logs (the maintainer's instruction during
  implementation). A failed or lost pending run moves with them, and its record is
  pointed at the new folder.
- T008 / T018: commits are found after `base` (HEAD at the run's start); only imported
  runs use time windows.
- T046: done on a scratch clone, then on the real repository (142 runs, verified
  byte for byte).
