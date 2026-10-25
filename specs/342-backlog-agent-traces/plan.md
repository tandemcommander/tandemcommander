# Implementation Plan: Backlog loop traces in `.agent-traces/` and two `bin/` commands

**Branch**: `342-backlog-agent-traces` | **Date**: 2026-10-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/342-backlog-agent-traces/spec.md`

## Summary

The backlog loop (247) writes each run into a folder of `.agent-traces/`, in the
reference project's format: `trace.jsonl` with attempt separators, `stderr.log`,
`meta.json`, and a shared `index.jsonl`. The folder is ignored by git, and the
loop never deletes from it. `status` shows the run folder and the total size. The
first `start` moves the 142 old runs from `.git/tandem-backlog-loop/logs/` into
the new layout once.

`bin/` gets two commands: `bin/backlog.sh` (new) runs the backlog tool, and
`bin/backlog-loop.sh` is today's `bin/backlog.sh`, renamed. The skills, contracts,
loop messages and `CLAUDE.md` switch to them.

The trace writing needs no change to the streaming: claude already writes
straight into the log file, so the loop only appends one separator line before
each launch (research R3). The planned lost-session change was measured
unnecessary (R1) and withdrawn from the spec.

## Technical Context

**Language/Version**: Python 3 (whatever `python` the build already requires), standard library only; Bash (Git Bash) for the two wrappers
**Primary Dependencies**: none new. Claude Code CLI 2.1.310 (`stream-json` output) as today
**Storage**: files: `.agent-traces/` (new, ignored), `.git/tandem-backlog-loop/` (existing state; `imported.json` new)
**Testing**: `unittest`: `tools/backlog/test_loop.py` (real loop processes with `fixtures/fake_claude.py`), `tools/backlog/test_backlog.py`, new `tools/backlog/test_traces.py`, `tools/test_bin_help.py`
**Target Platform**: Windows 11, Git Bash (the maintainer's machine)
**Project Type**: developer tooling inside the product repository (CLI scripts), no product code
**Performance Goals**: `status` < 2 s with 1,000 run folders / 5 GB (SC-004); the import of 547 MB once in under a minute
**Constraints**: never write to the working tree outside `.agent-traces/` (the loop's clean-tree precheck); never lose trace bytes on a crash (live append); the verdict never depends on the trace
**Scale/Scope**: about 10–20 runs a day, about 100 MB a day; 284 old files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Applies? | Result |
|---|---|---|
| I. Build reproducibility | no build input changes; `.agent-traces/` is outside the build and ignored | PASS |
| II. Backward compatibility (product) | no product, plug-in or registry change. Tooling: `bin/backlog.sh` changes meaning (the maintainer chose no alias, Clarifications Q3); the run lock, `run.json` and `RUNS.md` stay compatible, and an old pending run is migrated (FR-014) | PASS |
| III. Incremental modernization | small, testable steps; the pure parts go into a separate module with tests | PASS |
| IV. Windows commitment | Git Bash + Python on Windows, as 247 | PASS |
| V. Plugin architecture | untouched | PASS (n/a) |
| VI. UI consistency | no UI | PASS (n/a) |
| Technical constraints (C++, UTF-8-BOM, clang-format) | the C++ rules do not apply to Python and Bash tools. `tools/check_encoding.py` covers sources; the new files are UTF-8 without BOM like the existing `tools/backlog/*.py` | PASS |
| Development workflow: English commit messages, one concern | one concern: the backlog tooling's commands and output | PASS |
| Release documentation (`CHANGELOG.md`) | internal tooling with no user-visible effect → not recorded (constitution: "internal tooling … recorded only when they change what a user … can rely on") | PASS |
| CLAUDE.md standing rules: `PRIVACY.md` | traces are local developer files, with no network, product storage or installer change | PASS (no update) |
| CLAUDE.md: every `bin/` script answers `--help` (247) | both scripts, tested | PASS |

Re-check after Phase 1: unchanged. No violations, so *Complexity Tracking* is empty.

## Project Structure

### Documentation (this feature)

```text
specs/342-backlog-agent-traces/
├── spec.md              # clarified (4 answers) and corrected in planning (FR-009, FR-013, FR-015)
├── plan.md              # this file
├── research.md          # R1–R11 (measurements, decisions)
├── data-model.md        # entities, phases, attempt record
├── quickstart.md        # validation guide
├── contracts/
│   ├── traces.md        # the trace format (binding)
│   └── bin-commands.md  # bin/backlog.sh, bin/backlog-loop.sh
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source code (repository root)

```text
.gitignore                               + /.agent-traces/
bin/
├── backlog.sh                           NEW: the backlog tool (wraps tools/backlog/backlog.py)
└── backlog-loop.sh                      git mv of the former bin/backlog.sh; texts renamed
tools/backlog/
├── traces.py                            NEW, stdlib: run folder names, separator and header lines,
│                                        meta.json and index line builders, atomic write, commit filter,
│                                        size walk, old-log import + RUNS.md matching (pure where possible)
├── test_traces.py                       NEW: unit tests of traces.py
├── loop.py                              uses traces.py: new_run / execute / triage / conclude /
│                                        pending / status; prune_logs and KEEP_LOGS removed;
│                                        import + pending-run migration at start; messages renamed
├── backlog.py                           build_parser(prog from TANDEM_BACKLOG_PROG); RUNS.md header text
├── test_loop.py                         trace assertions per scenario; wrapper path bin/backlog-loop.sh;
│                                        import + migration tests
├── fixtures/fake_claude.py              emits system/init (+ model) and a result with usage, as needed
└── fixtures/valid/backlog/*.md          prose: bin/backlog.sh
tools/test_bin_help.py                   unchanged (covers both scripts by iterating bin/)
.claude/skills/tandem-backlog/SKILL.md          BL = bin/backlog.sh; loop commands → bin/backlog-loop.sh
.claude/skills/tandem-backlog/reference.md      the same, where it names them
.claude/skills/tandem-backlog-implement/SKILL.md  BL = bin/backlog.sh
.claude/skills/tandem-release/SKILL.md          the tool call
backlog/BACKLOG.md, backlog/RUNS.md             intro prose
backlog/items/backlog-loop-person-checks/desc.md  the person's steps
CLAUDE.md                                       Where-things-are row: bin/backlog.sh + bin/backlog-loop.sh
specs/242-backlog-system/contracts/cli.md, skills.md   invocation form (amendment note, dated)
specs/247-backlog-run-loop/contracts/loop-cli.md       Files, Status, script name (amendment note, dated)
specs/FEATURE-HISTORY.md                        342 entry (+ a pointer in 247's entry)
```

**Structure Decision**: the trace format lives in a new module `tools/backlog/traces.py`.
It keeps the 1,386-line `loop.py` from growing, and makes the format testable
without processes. The loop calls it at the five points where it already
handles logs: `new_run`, `execute`, `triage`, `conclude` / `drop_run`, and
`status`.

## Implementation outline

1. **Commands first** (US4): `git mv bin/backlog.sh bin/backlog-loop.sh`; write
   the new `bin/backlog.sh`; set `prog` from `TANDEM_BACKLOG_PROG`; rename the
   texts in `loop.py`, its tests, skills, contracts, `CLAUDE.md` and prose. Run
   the tests. This step stands alone and keeps the loop working.
2. **`traces.py` + tests** (US1, US2): pure builders for the separator, the header,
   meta, the index line, the folder name, the commit filter and the size; the
   atomic write.
3. **Loop integration** (US1, US2): `run.json` gains `trace`, `trace_attempts`,
   `indexed`; the separator and header before `Popen`; the attempt is closed in
   `assess` / `conclude`; meta is written in `save_run`; the index line where a
   record is dropped or frozen; the same for the triage `source`; `status` (text +
   `--json`); `prune_logs` / `KEEP_LOGS` / `logs` removed; `harness_version` read
   at start; `.gitignore`.
4. **Migration** (US3): pending-run migration and the one-time import at `start`,
   `imported.json`; tests with copies of real old logs (two items, one triage, one
   continued run) as fixtures, kept small.
5. **Records**: amend the 242 and 247 contracts, add the FEATURE-HISTORY entry, the
   quickstart run, the SC-008 search, and the fix-log. Then an independent review
   (refute-first) before merging.

## Risks

| Risk | Mitigation |
|---|---|
| A claude left by a killed loop is still writing to the **old** log when the new loop starts | the pending-run check already waits for a live claude before anything else (247 FR-9); the migration runs only once that claude has ended (order: wait → migrate → import) |
| The separator line lands in the middle of a line claude is writing | impossible: the separator is written before `Popen`, while no claude process holds the file. A claude from a previous loop is waited for first |
| `meta.json` written often (every `save_run`) | one small file, replaced atomically; `save_run` runs at phase changes, not per tick |
| The rename breaks muscle memory (`bin/backlog.sh start`) | the maintainer's choice (Q3): a plain usage error, nothing changes; the FEATURE-HISTORY entry and the `--help` header name `bin/backlog-loop.sh` |
| A loop started from an old checkout (before 342) on a tree after 342 | not supported. The loop runs from the tree it is in |

## Complexity Tracking

No constitution violations.
