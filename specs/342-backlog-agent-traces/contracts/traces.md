# Contract — traces of the backlog loop in `.agent-traces/` (feature 342)

This adopts the format of the reference project (`2026_hscr_ai_chatbot`, feature
003, `contracts/traces.md`): the same layout, file names and JSON keys. It differs
in two ways: one extra attempt reason (`killed`), and the `imported` key on runs
copied from the old logs. The traces are input for a future eval system.
`.agent-traces/` is in `.gitignore`, and the loop never deletes from it.

## Layout

```text
.agent-traces/
├── index.jsonl                               one line per ended run (append only)
└── 20261025-140200-claude-<slug>/            <YYYYMMDD-HHMMSS>-claude-<slug|triage>[-N]
    ├── trace.jsonl                           claude's stdout unchanged + attempt separators
    ├── stderr.log                            claude's stderr, a header line per attempt
    └── meta.json                             the run (replaced atomically)
```

The stamp is the run's start in local time. `-2`, `-3` … are added when the name
is taken. An item run uses the item's slug, and an auto-triage uses `triage`.

## `trace.jsonl`

Claude Code's `--output-format stream-json --verbose` output, byte for byte,
appended as it is written. Before every attempt the loop appends one line:

```json
{"type":"backlog_loop.attempt","attempt":2,"kind":"continue","reason":"usage-limit","started":"2026-10-25T15:10:03+02:00","harness":"claude","session_id":"…"}
```

`kind`: `start` | `continue`. `reason`: `-` (the first attempt), `usage-limit`,
`error`, `stall`, `idle`, `killed` (the run was cut off by Ctrl+C, a killed loop or
a reboot, and is continued at the next start). `restart` belongs to the reference
and is never written here. Imported runs have no separators.

## `stderr.log`

```text
=== attempt 2 (continue, usage-limit) 2026-10-25T15:10:03+02:00 ===
<claude's stderr of that attempt>
```

## `meta.json`

```json
{
  "format_version": 1,
  "kind": "item",
  "slug": "some-slug",
  "harness": "claude",
  "harness_version": "2.1.310",
  "model": "claude-opus-5-5[1m]",
  "session_id": "…",
  "started": "2026-10-25T14:02:00+02:00",
  "ended": "2026-10-25T15:40:12+02:00",
  "phase": "done",
  "outcome": "closed",
  "feature": "343",
  "branch": "343-some-slug",
  "commits": ["a1b2c3d", "…"],
  "why": null,
  "attempts": [
    {"attempt": 1, "kind": "start", "reason": "-", "started": "…", "ended": "…", "ending": "error",
     "error_kind": "usage-limit", "resets_at": "…", "exit_code": 1, "idle_killed": false, "usage": {}}
  ],
  "counters": {"limits": 1, "errors": 0, "stalls": 0, "idles": 0, "restarts": 0},
  "loop": {"pid": 1234, "host": "…", "auto_triage": true}
}
```

| Key | Value |
|---|---|
| `kind` | `item` \| `triage` |
| `harness` | always `claude` |
| `harness_version` | first word of `claude --version` when the loop started, or `null` |
| `model` | `--model` of the loop, else the `model` of the first `system/init`, else `null` |
| `phase` | `new`, `running`, `waiting`, `killed`, `failed`, `lost`, `done` |
| `outcome` | the outcome of the run's `RUNS.md` row (`closed`, `blocked`, `not-reproduced`, `split`, `nothing-to-do`); a triage that ended: `triaged`; else `null` |
| `feature`, `branch` | from the run's `RUNS.md` row (`-` there → `null`) |
| `commits` | short hashes, oldest first, of `git log --all` not reachable from `HEAD` at the run's start (an imported run: between `started` and `ended`) whose subject starts with `[<feature>]` or `backlog: <slug> `; for a triage `backlog: auto-triage` |
| `why` | the loop's reason text for the last interruption, or `null` |
| `attempts[].ending` | `success`, `error`, `interrupted` (no result event), or `null` while running |
| `attempts[].error_kind` | `usage-limit`, `session-lost`, `other`, or `null` |
| `attempts[].resets_at` | ISO time of a limit's reset, or `null` |
| `attempts[].exit_code` | claude's exit code; `null` when the loop did not start that process |
| `attempts[].usage` | the `usage` object of the attempt's `result` event, or `{}` |
| `counters` | `limits`, `errors`, `stalls`, `idles` (idle kills), `restarts` (always 0) |
| `imported` | only on runs moved from `.git/tandem-backlog-loop/logs/`: `true`; their `attempts` are `[]`, their `counters` all `null` and their index line has `"attempts": null`, because the old logs do not mark where an attempt started |

All times are ISO 8601 in local time with the offset. Unknown values are `null`.

## `index.jsonl`

One line per run, appended when the run ends: phase `done`, a dropped record
(refused, unrecorded, `--forget-run` of a run never indexed), a stop for a
person (`failed`, `lost`), or an auto-triage killed by Ctrl+C (`killed`; a
triage is never continued). A run continued across loop restarts gets one line.

```json
{"dir":"20261025-140200-claude-some-slug","kind":"item","slug":"some-slug","harness":"claude","model":"…","started":"…","ended":"…","phase":"done","outcome":"closed","feature":"343","attempts":2}
```

Lines are in the order runs ended. The imported runs come first, in start order.

## One-time import of the old logs

At the first `bin/backlog-loop.sh start` after this feature (no
`.git/tandem-backlog-loop/imported.json`), before anything else:

1. every old pair `<stamp>-<slug>.jsonl/.err` (`auto-triage` → `triage`) **moves**
   to `<stamp>-claude-<slug|triage>/`, unless a folder of that name exists or it is
   the log of a pending `run.json` that can still be continued. The folder is built
   as `<name>.part`, its files are compared byte for byte with the old ones, and it
   is renamed. Its `meta.json` is reconstructed as in research R6, and its index
   line is appended in name order. Only then is the old pair deleted. An emptied
   `logs/` folder is removed;
2. a pending `run.json` in phase `failed` / `lost` (only ever dropped) moves with
   the rest and is pointed at its new folder (`indexed: true`);
3. `imported.json` (`{"date", "imported", "skipped"}`) is written, and the window
   says how many logs were moved;
4. when the loop reaches a pending run that can be continued, after any claude a
   previous loop left running has ended, its log moves to a run folder named after
   its log file (content copied, offsets unchanged, the old pair deleted). The run
   continues there and gets its index line when it ends.

The loop's control and state files (`loop.json`, `run.json`, `triage.json`,
`pause`, `stop`, `imported.json`) stay in `.git/tandem-backlog-loop/`.

## Format changes

A change of a key or of a value's meaning raises `format_version`. Adding a value
to an enumeration is announced here.
