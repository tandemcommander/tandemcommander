# Quickstart — validating 342

Run from the repository root in Git Bash. Nothing here needs a model or a GUI.

## 1. Automated checks

```bash
python -m unittest tools/backlog/test_backlog.py tools/backlog/test_loop.py tools/backlog/test_traces.py -v
python -m unittest tools/test_bin_help.py -v
```

Expected: all pass. `test_loop.py` drives the real loop with
`tools/backlog/fixtures/fake_claude.py` through the scenarios of SC-001 and checks
each run folder against [contracts/traces.md](contracts/traces.md). `test_traces.py`
covers the pure parts: names, the separator, `meta.json`, the index line, the
commit filter, the size, and the import with its RUNS.md matching.

## 2. The two commands

```bash
bin/backlog.sh --help                 # header + every tool command, exit 0
bin/backlog.sh list --section next    # same output as before through python
bin/backlog.sh check                  # TOTAL: 0
bin/backlog.sh pause; echo $?         # usage error, 2; git status unchanged
bin/backlog-loop.sh --help            # the loop's commands, exit 0
bin/backlog-loop.sh status            # 'trace:' line, no 'log:' line
```

## 3. The move of the old logs, on a copy first

Rehearse on a scratch clone with a copy of the state folder (logs + `run.json`),
then do the same on the real repository:

```bash
git clone -q . "$TMP/tc342" && mkdir -p "$TMP/tc342/.git/tandem-backlog-loop"
cp -r .git/tandem-backlog-loop/logs .git/tandem-backlog-loop/run.json "$TMP/tc342/.git/tandem-backlog-loop/"
bin/backlog-loop.sh start --root "$TMP/tc342" --until-idle --claude-cmd '["false"]'
```

The start moves the logs first. The pending `run.json` there is the 341 run in
phase `failed`, so the start then stops for a person (exit 1) without starting
claude.

Expected:
- `$TMP/tc342/.agent-traces/` holds 142 folders and `index.jsonl` 142 lines;
- every `trace.jsonl` / `stderr.log` compares equal (`cmp`) to its old file (keep a
  copy to compare against);
- `imported.json` exists, the old `logs/` folder is gone, and `run.json` points to
  the 341 run's new folder;
- a second `start` moves nothing;
- `git -C "$TMP/tc342" status --porcelain` shows nothing under `.agent-traces/`.

## 4. Text search (SC-008)

```bash
git grep -n -E "python tools/backlog/(backlog|loop)\.py|bin/backlog\.sh (start|pause|resume|stop|status)" -- \
  . ':!specs/FEATURE-HISTORY.md' ':!specs/[0-2]*' ':!specs/3[0-3]*' ':!specs/34[01]*' ':!specs/342*'
```

Expected: no output.

## Owed to a person

The first real loop run after the merge (`bin/backlog-loop.sh start`). Check that
the window names `.agent-traces/…`, that the import ran once, and that
`bin/backlog-loop.sh status` shows the size.
