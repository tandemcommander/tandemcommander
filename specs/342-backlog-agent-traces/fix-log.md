# Fix log — 342

## 2026-10-25 — specify, clarify, plan (interactive, the maintainer)

- Compared our backlog system with `E:\Projects\2026_hscr_ai_chatbot` (read only).
  It is a TypeScript port of ours (242 + 247) plus Codex. Adopted: the traces format
  (A1), the commit lookup without a trailer (A2), the status speed criterion (A10),
  `bin/backlog.sh` as the tool's entry (A12). Not adopted: A3, A5–A9, A11 (spec
  table).
- Clarified: two scripts (`bin/backlog.sh` + `bin/backlog-loop.sh`); skills use
  `bin/backlog.sh`; no special handling of old loop words; traces never deleted.
- Measured before the plan:
  - claude 2.1.310 `--resume <unknown uuid>` → `No conversation found …` in stderr
    **and** in `result.errors` → FR-013 / SC-005 withdrawn (our loop reads stderr);
  - the one real limit in the old logs had `rate_limit_event` `rejected` with
    `resetsAt` → no text parsing (A5);
  - old logs: 284 files, 547 MB, 142 runs (95 items, 47 triages; 94 was the count of distinct slugs, corrected 2026-10-25);
  - `backlog.py pause|status` → `invalid choice`, exit 2; `start` without a slug →
    `required: slug, --feature`, exit 2; nothing written.
- Spec corrected in planning: FR-009 also finds `backlog: <slug> …` commits (runs
  without a feature); FR-015 makes the import automatic at the first `start`, with
  a marker in the state folder.
- Not run: `update-agent-context` (CLAUDE.md forbids *Active Technologies*
  sections).

## 2026-10-25 — implement

- Baseline before any change: `test_backlog` + `test_loop` + `test_bin_help` = 144
  tests OK (142 s).
- `tools/backlog/traces.py` (new, stdlib) with `test_traces.py` (20 tests): names,
  separator / header bytes, meta.json and index line in the contract's key order,
  the atomic write, the commit filter, the size walk (1,000 folders well under 2 s),
  and the old-log import.
- `loop.py`: run records carry `trace`, `trace_attempts`, `next_reason`, `indexed`,
  `base`. The separator and the header are written through claude's own file
  handles before `Popen`, then the offsets are taken, so the verdict code reads
  exactly as before. meta.json is rewritten in `save_run`. `finish_trace` (final
  meta + one index line) runs in `drop_run` and for `failed` / `lost` in
  `save_run`. Triages get their own folder, finished right after claude ends (or
  `killed` on Ctrl+C). `prune_logs` / `KEEP_LOGS` are gone. Status shows `trace:`
  and the total size.
- Measured while implementing (spec, contract and research amended):
  - `system/init` repeats at every turn of one process (7 times in the 341 log, 2 in
    a one-attempt run), so the attempts of an old log cannot be counted. Imported
    runs record `attempts: []` and the index `attempts: null`.
  - With time windows, two triages seconds apart each took the other's commit (git
    dates have one-second steps) → commits are taken after `base` = HEAD at the
    run's start; only imported runs use times.
  - The fake claude's two runs both logged feature 900 → it now gives each item its
    own number, as real runs have.
  - The real state held a pending `run.json` in phase `failed` (the 341 run,
    finished by hand) with its log in the old folder. Skipping it would have left
    it there for good, because the import runs once → a failed / lost pending run
    moves with the rest and its record is pointed at the new folder; only a run
    that can still be continued keeps its log for `migrate_old_run`.
  - Our backlog tool has no `show` command (the reference's has); the help text,
    contract and spec named it → corrected.
- The maintainer, mid-implementation: **move** the old logs (not copy) into the
  new structure. Done as copy → compare byte for byte → rename `<name>.part` to the
  final name → index line → delete the old pair → remove the emptied folder. The
  control and state files stay in `.git/tandem-backlog-loop/` (state, not traces;
  FR-004).
- Rehearsal on a scratch clone with a copy of the real logs and `run.json`:
  142 pairs → 142 folders, 142 index lines, every file equal byte for byte, no
  `.part` left, a second start moved nothing, `.agent-traces/` ignored by git.
- **The real move** (`bin/backlog-loop.sh start --until-idle --claude-cmd '["false"]'`
  on the repository, so no claude could start; it stopped at the failed 341 record
  as it should, exit 1): 142 runs moved: 81 closed, 5 blocked, 5 not-reproduced,
  4 split, 47 triaged. All verified against a byte copy taken before
  (`verify_move.py`: no problems). `.git/tandem-backlog-loop/` now holds
  `run.json` (pointing to `.agent-traces/20261024-125035-claude-ftp-an-upload-…`)
  and `imported.json`; `.agent-traces/` = 547 MB.
- Commands: `git mv bin/backlog.sh bin/backlog-loop.sh`; the new `bin/backlog.sh`
  wraps `backlog.py` (`TANDEM_BACKLOG_PROG` names the script in argparse's usage).
  Renamed in the skills (`BL = bin/backlog.sh`, loop commands →
  `bin/backlog-loop.sh`), the 242 / 247 contracts, `CLAUDE.md`, the prose of
  `BACKLOG.md` / `RUNS.md` (and their fixtures), and the steps of
  `backlog-loop-person-checks` (with a log line; its dated log line of 2026-10-24
  stays as history).
- Tests: 171 OK (144 + 27 new); `check_encoding.py` TOTAL 0.

## 2026-10-25 — independent review (refute-first, one agent)

No defect in the run path (verdicts, offsets, index count, clean tree). Negative
controls: the separator write removed → 11 failures in `test_loop`; the `indexed` guard
removed → 2 failures. Findings in the one-time move and the separators, all reproduced in
a scratch copy (R1–R4), all fixed. They now live as tests in `test_loop.ImportTests`, and
each fails without its fix (measured for R1 and R3 in a copy):

- **M1** The import moved the log of a 247 auto-triage whose claude was still writing it.
  On Windows it crashed (`WinError 32` at the delete), and the next start skipped the
  pair, leaving the full log behind with a 12-of-81-line copy. On POSIX the bytes written
  after the copy were lost. → the log named by `triage.json` is skipped and moved by
  `orphan_triage` once that claude has ended; a delete that fails leaves the file
  instead of crashing (`traces.remove_old`).
- **S1** A separator or header glued onto a partial last line left by a killed claude.
  → a newline is written first when the file does not end with one (`traces.ends_line`).
- **S2** A start that imported but paused before reaching a continuable old run, then
  `--forget-run`, stranded its log. → `--forget-run` of a pre-342 record moves its log
  (`Loop.move_old_log`).
- **S3** An import cut off after the rename left the old pair and no index line for ever.
  → a complete folder without an index line gets it, and the old pair is deleted when
  both files are equal byte for byte.
- **S4** A migrated pending run in phase `waiting` kept an attempt that was never closed.
  → only a cut-off run (`running` / `killed` / `new`) keeps the last attempt open.
- NOTEs fixed: Ctrl+C during a triage before claude started now ends and indexes its
  folder (`killed`); the exit code of an attempt the loop killed is recorded; a failed
  `Popen` of a continuation closes its attempt, so the next separator gets the next
  number. NOTEs left: a run pending at the upgrade on a branch whose `.gitignore`
  predates 342 could commit traces with the skill's `git add -A` (not reachable here:
  the one pending run is `failed`); `status --json` gives `trace: null` for a run not
  yet migrated (the text shows its old log).
- None of these could fire on this repository after the real move, which ran before
  the review ended; they matter for any other checkout.
- After the review fixes: 175 tests OK (171 + 4 review reproductions); `check_encoding.py` TOTAL 0; `bin/backlog.sh check` TOTAL 0.
- Afterwards (the maintainer: make run.json reflect the current state): the 341 record was finished (RUNS.md `closed`, lock free, item removed, branch in `main`, trace `done` / `closed` and indexed once), so `run.json` was removed (what `--forget-run` does, without starting the loop; a copy is kept in the session's scratchpad). `status`: loop not running, no run, lock free.
