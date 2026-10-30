# Data model: Backlog web app (344)

**Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

Two kinds of entities: **projections** of data other tools own (the application never stores
them; it reads them through the tools or git and validates them with schemas of the shared
package) and **application state** (owned by the application, kept in
`<git-common-dir>/tandem-backlog-app/`, never in the tracked tree). Field names are those of the
shared zod schemas; the API contract ([contracts/http-api.md](contracts/http-api.md)) uses them.

---

## Projections (owned by other tools)

### Legend

Source: `backlog.py legend --json` (R8). The vocabulary of every field; the application has no
built-in list of areas, types, sources or who values.

| Field | Type | Notes |
|---|---|---|
| `types` | `{value, meaning}[]` | today `bug feature improvement tech-debt decision person-step` |
| `statuses` | `{value, meaning}[]` | `new open blocked in-progress parked rejected` (the code knows only these six) |
| `areas` | `{value, meaning}[]` | 18 today |
| `who` | `{value, meaning}[]` | `agent person both` |
| `efforts` | `{value, meaning}[]` | `S M L ? -` |
| `sources` | `{form, meaning}[]` | `manual`, `github#N`, `review:NNN`, ... |
| `severityAnchors` | `{range, meaning}[]` | 0-10 |

### Board

Source: `backlog.py board --json [--with-body] [--ref main]` (R8, R10).

| Field | Type | Notes |
|---|---|---|
| `revision` | string | SHA-256 of `BACKLOG.md` as read (R12) |
| `ref` | `"worktree" \| "main"` | where it was read from (R10) |
| `lastTriaged` | date | |
| `sections` | `Section[]` | in overview order |
| `unreadable` | `{slug, path, finding}[]` | items with a broken header (shown, not editable) |

**Section**: `name` (`In progress`, `Next`, `Decisions for the maintainer`, `Person steps`,
`Inbox`, `Parked`, `Rejected`), `ordered` (bool; the four first ones), `rows`:
`{position | null, slug, title} | {note: string}` (a hand-written row kept verbatim).

### Item

Source: `backlog.py show <slug> --json [--ref main]`; summary fields also in the board rows
(`--with-body` adds bodies for search).

| Field | Type | Validation (from the item format, 242) |
|---|---|---|
| `slug` | string | `^[a-z0-9]+(-[a-z0-9]+)*$`, <= 60; never renamed |
| `revision` | string | SHA-256 of `desc.md` (R12) |
| `title` | string | one line, no control characters |
| `type`, `status`, `area`, `who`, `effort`, `source` | string | legend values |
| `severity` | integer 0-10 | the tool prints a string; the schema converts |
| `created`, `updated` | date | `updated >= created` |
| `verified` | `{date, commit} \| null` | |
| `feature` | `"NNN" \| null` | required iff `in-progress` |
| `related`, `dependsOn` | slug[] | existing slugs; `dependsOn` acyclic, not rejected |
| `dependents` | slug[] | derived: items whose `depends-on` names this one |
| `reason` | string \| null | required iff `blocked`/`parked`/`rejected` |
| `section`, `position` | string, integer \| null | where the board shows it |
| `body` | `{name, markdown}[]` | the ten fixed sections in order (Problem, Evidence, Expected, Approach, Notes, Question, Options, Recommendation, Steps, Log) |
| `log` | `{date, text}[]` | parsed *Log* |
| `steps` | `{index, done, text}[]` | parsed *Steps* checklist (person steps) |
| `options` | `{key, text}[]` | parsed *Options* (decisions) |
| `files` | `{issue?: {number, head}, reply?: {state}, evidence: string[]}` | |
| `findings` | `{rule, line, message}[]` | the item's own check findings |
| `eligibility` | `{eligible, reason}` | from `next --json` (who/type/dependency rules) |

**Status transitions** (enforced by the tool; the application only offers the allowed ones):
`new -> open` (move to Next / Decisions / Person steps, by admission rules), `new|open|blocked ->
parked|rejected` (reason required), `open <-> blocked` (reason required to block),
`open|blocked -> new` (back to Inbox), `parked|rejected -> any section` (new reason required),
`any (not in-progress) -> removed` (close with reason). `open -> in-progress` and
`remove --feature` belong to runs and are never offered.

### Check result

Source: `backlog.py check --json`: `{total, findings: {path, line, rule, message}[]}`; `rule`
is one of the 18 rule ids of 242.

### Next-up

Source: `backlog.py next --json [--ref main]`: `{slug | null, skipped: {slug, reason}[]}`.

### Loop view

Source: `loop.py status --json` every 3 s, plus `loop.json`, `run.json`, `triage.json`, the
`pause`/`stop`/`kill` flags, `last.json` and `loop.log` read whole (open-read-close) at 1 Hz
(R13, R15).

| Field | Type | Notes |
|---|---|---|
| `shown` | enum | `not-running`, `starting`, `running`, `triage`, `waiting`, `idle`, `paused`, `pause-pending`, `stop-pending`, `kill-pending`, `limit`, `backoff`, `dead`, `run-outside-loop`, `stopped-for-person` |
| `detail` | string | the loop's own words (`loop.json.detail`) |
| `until` | datetime \| null | limit or backoff end |
| `live` | bool | process identity checked by the loop |
| `heartbeatAge` | seconds | from `loop.json.updated` |
| `pid`, `started`, `since`, `options` | | |
| `counts` | `{closed, blocked, notReproduced, split, nothingToDo}` | |
| `blockedStreak`, `items` | integer | |
| `usage` | `{status, resetsAt, fiveHour?, sevenDay?}` | last rate-limit info |
| `ctrlCSafe` | bool | |
| `lock` | `{slug, branch, started, host, stale} \| null` | the run lock |
| `interruptedRun` | `{slug, phase, why, waitUntil, todo[]} \| null` | `run.json` without a live loop |
| `orphanClaude` | bool | |
| `tracesBytes` | integer | |
| `lastEnd` | `{ended, exitCode, reason, counts} \| null` | `last.json` |

Derivation rules of `shown`: A2 §1.2 (table "Derived states").

### Run (live or ended)

Sources: `run.json`, `.agent-traces/<dir>/meta.json`, `trace.jsonl`, `index.jsonl`, `RUNS.md`
row, `git log <base>..<branch>`, `specs/<BRANCH>/tasks.md`.

| Field | Type | Notes |
|---|---|---|
| `id` | string | the trace folder name `<YYYYMMDD-HHMMSS>-claude-<slug|triage>[-N]`, or `runs-md:<row>` for a journal row without a trace |
| `kind` | `item \| triage` | |
| `slug`, `title` | | title from the item, or the archive when closed |
| `session` | string | |
| `started`, `ended`, `durationWall`, `durationActive` | | active = sum of attempts |
| `phase` | Phase | R14 |
| `phaseTimeline` | `{phase, at}[]` | |
| `attempts` | `{n, kind, reason, started, ended, ending, errorKind}[]` | separators + meta |
| `outcome` | `closed \| blocked \| not-reproduced \| split \| nothing-to-do \| triaged \| killed \| failed \| lost \| running` | |
| `feature`, `branch` | | |
| `commits` | `{hash, subject}[]` | `meta.commits` + `[Spec Kit]` commits from git |
| `tasks` | `{done, total} \| null` | `tasks.md` checkboxes |
| `currentTool` | `{name, summary, since} \| null` | last main-thread `tool_use` without result |
| `recentMessages` | string[] | last main-thread text blocks |
| `guiProbeRunning` | bool | open `run_on_hidden_desktop.ps1` call |
| `cost` | `{usd, inputTokens, outputTokens, cacheRead, cacheWrite} \| null` | last `result` per attempt, summed |
| `note` | string | `RUNS.md` note (blocked reason etc.) |

**Phase** (monotonic, R14): `selection -> measure -> specify -> clarify -> plan -> tasks ->
analyze -> implement -> verify -> review -> close -> merge -> done`, with the side exit `stopped`
(the `block` path). A triage run has only `triage -> done`.

### Trace event (stream)

One parsed line of `trace.jsonl`, normalised for the view: `offset` (byte offset, the SSE id),
`at` (event timestamp or receive time), `kind` (`attempt`, `init`, `assistant-text`, `tool-use`,
`tool-result`, `subagent`, `task`, `rate-limit`, `result`, `thinking`, `unparsable`),
`parentToolUseId`, `toolUseId`, `name`, `summary` (a short one-line rendering), `raw` (the
original JSON, sent only on demand).

### Feature record

Source: `specs/<NNN>-*/` (git objects when a run is active, R10): `number`, `name`, files
present (`spec.md`, `plan.md`, `tasks.md`, `fix-log.md`, `closing-report.md`, `research.md`,
`contracts/*`, `probe/*`), `tasks` progress, commits whose subject starts with `[NNN]`,
`FEATURE-HISTORY.md` entry `- NNN-...`, the backlog items whose text or log names the feature.

### Closed item

Source: git history (R16): `slug`, `title`, `closedIn` (commit, date, subject), `feature`
(from the subject `[NNN]` or the last log line), `lastDescription` (markdown at the parent of the
removing commit).

---

## Application state (owned by the application)

All files under `<git-common-dir>/tandem-backlog-app/`, UTF-8 JSON without BOM, written by temp
file + rename; read and written only by the server.

### WriteGate (computed, not stored)

| Field | Type | Notes |
|---|---|---|
| `state` | enum | `free`, `loop-between-runs`, `run-holds-lock`, `auto-triage`, `not-on-main`, `merge-in-progress`, `stale-lock`, `edit-in-progress`, `degraded` |
| `writable` | bool | `free` only (`loop-between-runs` offers *pause, change, resume*) |
| `reason` | string | shown at every disabled control |
| `checkClean` | bool | findings present -> writes allowed after the findings dialog |
| `branch`, `headIsMain`, `treeDirtyOutsideBacklog` | | |

Transitions follow the loop view, the lock and HEAD; recomputed on every relevant file change
and immediately before every queued operation (R9).

### Change (tray entry) - `tray.json`

| Field | Type | Notes |
|---|---|---|
| `id` | string | |
| `at` | datetime | |
| `operation` | enum | `move`, `reorder`, `set`, `block`, `unblock`, `park`, `reject`, `reopen`, `close`, `new`, `import`, `body`, `step`, `decide`, `reply`, `log`, `verify` |
| `slugs` | slug[] | |
| `summary` | string | one line in the skill's report style, e.g. `slug: Inbox -> Next #11` |
| `reason` | string \| null | |
| `files` | `{path, before: sha256 \| null, after: sha256 \| null}[]` | `null` = absent |
| `snapshot` | string | folder `undo/<id>/` holding the before-bytes of `files` |
| `state` | `pending \| committed \| undone` | |
| `commit` | string \| null | |

Rules: undo only for `pending`, newest first, and only while every file's current hash equals
`after` (R11); the tray empties into a commit; `undone` and `committed` entries are kept for the
session's history (pruned after 7 days).

### OutsideChange (computed)

Dirty paths under `backlog/` that no pending tray entry explains (`git status --porcelain
--no-optional-locks -- backlog/`): shown in the tray as "changed outside the app", included in a
commit only when ticked.

### AI job - `jobs/<id>.json`

| Field | Type | Notes |
|---|---|---|
| `id`, `kind` | | `ask`, `draft-item`, `triage-check`, `verify`, `auto-triage-plan`, `assess-issue` |
| `input` | object | the question, sentence or slug |
| `state` | `queued \| running \| done \| failed \| cancelled` | |
| `startedAt`, `endedAt`, `costUsd` | | |
| `progress` | `{lastTool, text}[]` | streamed |
| `proposal` | object \| null | validated against the kind's schema (contracts/ai-jobs.md) |
| `applied` | `{changeIds[]} \| null` | after the maintainer confirmed |

One job `running` at a time; jobs older than 30 days are pruned.

### Settings - `settings.json`

`theme` (`system|light|dark`), `density` (`compact|comfortable`), `notifications`
(`{enabled, events: {runEnded, stoppedForPerson, usageLimit, precheckWait, runAddedItems,
checkFindings}, quietHours: {from, to} | null}`), `autoCommitBeforeLoop` (`ask|always|never`),
`aiBudgetUsd` (default 2), `columns` per section, `lastVisit` (for "since your last visit").

### Saved view - `views.json`

`{name, url, pinned, builtIn}`; built-in views (not deletable): *Next up*, *Blocked*,
*Agent-doable small*, *Severity 7+*, *GitHub items*, *Not verified*, *Created by runs this week*.

### Notification event - `events.jsonl` (append-only)

`{id, at, kind, severity: info|attention|urgent, title, text, link, seen}`; kinds as in R21.
`seen` is tracked per event id in `settings.lastSeenEventId`.

### Instance - `instance.json`

`{pid, ident (process creation time), port, started, repoRoot, launcherSecret}`; written at
start, removed at a clean exit; a stale file (process gone) is replaced. `launcherSecret` lets
a second launch ask the running instance for a new bootstrap address (contracts/security.md);
it is not the session token.

### Edit lock - `<git-common-dir>/tandem-backlog-edit.lock`

Not under the app folder because the loop reads it (contract
[loop-cli-additions.md](contracts/loop-cli-additions.md)): four lines `pid`, `ident`,
`started`, `purpose`; created with exclusive create for the duration of one queued operation
or one commit; live = the process with that pid and creation time exists.

### Run cache - `cache/runs/<dir>.json`, `cache/closed.json`

Derived per ended run (phase timeline, cost, attempts) and per removing commit; never edited;
safe to delete.
