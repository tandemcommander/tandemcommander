# Data model — 342

The formats are binding in [contracts/traces.md](contracts/traces.md). This file
covers how the entities relate and how they move through states.

## Entities

| Entity | Where | Identity | Written by |
|---|---|---|---|
| Run folder | `.agent-traces/<YYYYMMDD-HHMMSS>-claude-<slug\|triage>[-N]/` | the folder name (unique: `-2`, `-3` … when taken) | the loop, created before the first attempt |
| Trace | `<run folder>/trace.jsonl` | — | claude (stdout, appended live) and the loop (one separator line before each attempt) |
| Error log | `<run folder>/stderr.log` | — | claude (stderr) and the loop (one header line before each attempt) |
| Run metadata | `<run folder>/meta.json` | `format_version` 1 | the loop, replaced atomically |
| Attempt | `meta.json.attempts[]` + a separator line | `attempt` (1, 2, …) within the run | the loop |
| Index line | `.agent-traces/index.jsonl` | `dir` | the loop, once per run when the run ends |
| Run record (existing, 247) | `.git/tandem-backlog-loop/run.json` | `session` | the loop; gains `trace` (the run folder), `trace_attempts` (the attempt list), `indexed` |
| Import marker | `.git/tandem-backlog-loop/imported.json` | — | the loop, after the one-time import |

A run folder belongs to exactly one run record while the run lives, and to no
record afterwards. The index holds at most one line per run folder.

## Run phases (`meta.json.phase`)

```text
new ──► running ──► (attempt ends)
                      ├─ finished / refused / unrecorded ─────► done ── index line
                      ├─ limit / error / stall / idle ─► waiting ─► running (attempt N+1)
                      ├─ Ctrl+C / killed loop ─► killed ─► (next start) running, reason killed
                      ├─ too many of one kind / refused-own ─► failed ── index line (stop for a person)
                      └─ lost session ─► lost ── index line (stop for a person)
failed / lost ──(--forget-run)──► record dropped; no second index line (`indexed` true)
```

A triage has the same folder and files, `kind: triage`. It is never continued:
a limit or an error means a new triage with a new folder, and the ended one gets
its index line with phase `failed` or `done`.

## Attempt record (in `run.json` and `meta.json`)

| Field | Set when | Values |
|---|---|---|
| `attempt` | launch | 1, 2, … |
| `kind` | launch | `start` \| `continue` |
| `reason` | launch | `-` (first), else the verdict that caused it: `usage-limit`, `error`, `stall`, `idle`, `killed` |
| `started` | launch | ISO 8601 local with offset |
| `ended`, `ending`, `error_kind`, `resets_at`, `exit_code`, `idle_killed`, `usage` | the attempt ends (claude's process ended and the verdict was taken) | see the contract; `null` while it runs or when unknown |

## Validation rules

- The folder name is the slug as given by `next` (slug pattern of 242, so no
  characters that need escaping). The stamp is the run's start in local time.
- `meta.json` is valid JSON at every moment a reader can see it: it is replaced,
  never written in place.
- `index.jsonl` lines are appended whole, one write per line, in the order runs
  end.
- An imported run has `imported: true`. A run of the loop has no `imported` key.
