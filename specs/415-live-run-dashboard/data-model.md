# Data model - feature 415

All types live in `packages/shared` (zod schemas where they cross the wire, plain TypeScript types
for the in-browser folds).

## TraceEvent.info (new optional field of the existing *Trace event*)

| Field | Type | From |
|---|---|---|
| `description` | string? | tool input `description` (Bash, PowerShell, Agent/Task), `skill` + `args` (Skill) |
| `filePath` | string? | tool input `file_path` / `notebook_path` / `path` |
| `subagentType` | string? | Agent/Task input `subagent_type` |
| `messageId` | string? | `message.id` of an assistant line (first event of the line) |
| `model` | string? | `message.model` |
| `usage` | {input, output, cacheRead, cacheWrite5m, cacheWrite1h}? | `message.usage` (first event of the line) |
| `outputChars` | number? | characters of text and tool input of the line (first event) |
| `costUsd` | number? | `result.total_cost_usd` |
| `totals` | {input, output, cacheRead, cacheWrite5m, cacheWrite1h, model}? | sum of `result.modelUsage` |
| `limits` | {status, fiveHour?, sevenDay?, resetsAt?}? | `rate_limit_event.rate_limit_info` |
| `taskStatus` | string? | `task_notification.status` / `task_progress.description` |

## Story entry

| Field | Meaning |
|---|---|
| `id` | `<offset>:<n>` of the event that opened it (stable across folds) |
| `at` / `endedAt` | ISO times (from the event / its result) or null |
| `phase` | the run phase when the entry was opened |
| `kind` | `phase`, `action`, `group`, `agent`, `message`, `attempt`, `limit`, `turn`, `session`, `unreadable` |
| `label` | `PHASE`, `SPEC KIT`, `BUILD`, `TEST`, `PROBE`, `CHECK`, `COMMIT`, `GIT`, `BACKLOG`, `EDIT`, `READ`, `SEARCH`, `SCREENSHOT`, `AGENT`, `REVIEW`, `SHELL`, `PLAN`, `TRANSLATE`, `WEB`, `DECISION`, `MESSAGE`, `LIMIT`, `RESTART`, `STOP`, `ERROR`, `INFO` |
| `title` | the human sentence (plain text, may hold `` `code` ``) |
| `detail` | Markdown or plain text shown when opened (a result excerpt, the message) |
| `outcome` | `running`, `ok`, `fail`, `warn`, `info` |
| `importance` | `critical`, `high`, `normal`, `low` |
| `toolUseId` | the tool call it stands for |
| `children` | lines of a group or of a subagent (at most 200), `childCount` = all |
| `status` | the latest status line of an agent (its task progress) |
| `image` | the image path of a SCREENSHOT entry |
| `critical` | why the entry is critical (shown on the Critical tab) |
| `decision` | true when the entry states a decision (Decisions tab) |

Transitions: a tool entry opens `running`; its result sets `ok` / `fail` / `warn` and `endedAt`; a
new attempt marks entries still running as `warn` ("cut off"). A group grows while consecutive
calls of its kind arrive.

## Run metrics (snapshot)

`tokens {input, output, cacheRead, cacheWrite}`, `costUsd`, `costBasis` (`reported` / `estimate`
/ `none`), `unpricedModels[]`, `model`, `contextTokens` (input + cache of the last main-thread
message), `toolCalls`, `toolErrors`, `subagents`, `filesChanged`, `messages`, `limits` (the latest
`info.limits`).

## Progress estimate

`fraction` (0-1), `elapsedSeconds`, `expectedTotalSeconds`, `remainingSeconds`, `expectedEnd`
(ISO), `phaseFraction`, `basis` (text), `done` (bool).

## Run insight (server answer of `GET /api/runs/:id/insight`)

`branch`, `featureFolder`, `documents [{name, file, size, modified}]`, `decisions [{question,
answer, how}]`, `assumptions [string]`, `diagrams [{title, text}]`, `images [{n, name, where,
source: trace|feature, size, modified}]`, `estimate {medianSeconds, count, basis}`.

## Time index

Anchors `[{offset, ms}]`, sorted by offset, at most 2 000 (thinned evenly when more);
`timeAt(offset)` interpolates; before the first anchor = the first, after the last = the last.
Saved as `cache/times/<run>.json` in the state folder.

## Live snapshot (chat)

Plain text of at most about 8 000 characters - `contracts/chat-snapshot.md`.
