# Contract: HTTP API of the backlog app (feature 344)

The single source of the shapes is the zod schemas in `tools/backlog-app/packages/shared`; this
document is their reference. Entities: [data-model.md](../data-model.md). Access rules for every
route: [security.md](security.md).

## Conventions

- Base path `/api`. JSON bodies, UTF-8. Every request except `POST /api/session/claim` carries
  `Authorization: Bearer <token>`.
- `GET` routes never change anything.
- Changing routes take `Content-Type: application/json` and return the result of the
  operation plus the new revisions. They are queued (one at a time) and run under the edit lock
  (research R9).
- Changing routes that act on the backlog carry `base`: `{"board": "<revision>"}` and/or
  `{"item": "<revision>"}` - the revisions the user's view was based on (R12).
- Errors: `{"error": {"code", "message", "detail"?}}` with these codes:

| HTTP | `code` | Meaning |
|---|---|---|
| 400 | `invalid-request` | schema validation failed (`detail` = the issues) |
| 401 | `unauthorized` | token missing or wrong; bootstrap code unknown, used or expired |
| 403 | `forbidden-origin` | Origin / Fetch-Metadata check failed |
| 404 | `not-found` | unknown slug, run, feature, job or view |
| 409 | `changed-underneath` | `base` revision differs (`detail` = the new revisions) |
| 409 | `gate-closed` | the write gate is not `free` (`detail` = the gate) |
| 409 | `busy` | an AI job already runs; the loop already lives (start) |
| 413 | `too-large` | body over 256 KiB |
| 415 | `unsupported-media-type` | changing request not `application/json` |
| 421 | `misdirected` | Host header not allowed (no body detail) |
| 422 | `refused` | the backlog tool or the loop refused; `message` = its text verbatim, nothing written |
| 500 | `tool-failed` | a tool crashed (`detail` = stderr), the check is run and published |

- A tool result that was **written with check findings** is `200` with
  `{"ok": true, "findings": [...]}` - the client shows a warning and never retries.

## Session

| Method, path | Body / query | Response |
|---|---|---|
| `POST /api/session/claim` | `{"boot": "<code>"}` | `{"token", "repo": {"root", "name"}, "version"}`; the code is single-use, valid 120 s |
| `POST /api/session/link` | - | `{"url"}` with a new bootstrap code (for "copy link" / a second browser) |

## Overview and state

| Method, path | Response |
|---|---|
| `GET /api/state` | `{"gate": WriteGate, "loop": LoopView, "run": Run \| null, "tray": {"pending": n}, "repo": {"branch", "headIsMain", "dirtyOutsideBacklog": paths[], "aheadOfOrigin", "behindOrigin"}, "check": {"total"}, "unseenEvents": n}` |
| `GET /api/home` | `{"needsYou": Event[], "sinceLastVisit": Event[], "nextUp": NextUp, "counts": {section: n}}` |

## Backlog (read)

| Method, path | Query | Response |
|---|---|---|
| `GET /api/legend` | - | Legend |
| `GET /api/board` | `q` (filter language, R20), `section`, `sort` | Board with the rows that match, each with a `snippet` when `q` has free text; `ref` says worktree or main |
| `GET /api/items/{slug}` | - | Item |
| `GET /api/items/{slug}/history` | - | `{"commits": [{"hash", "date", "subject", "author"}]}` (also for closed items) |
| `GET /api/items/{slug}/history/{hash}` | - | `{"markdown"}` of `desc.md` at that commit |
| `GET /api/items/{slug}/files/{name}` | - | `issue.md`, `reply.md` or an `evidence/` file by name (validated against `show`), as text or bytes |
| `GET /api/next` | - | NextUp |
| `GET /api/check` | - | Check result |
| `GET /api/closed` | `q` | `{"items": ClosedItem[]}` |
| `GET /api/closed/{slug}` | - | ClosedItem with `lastDescription` |
| `POST /api/query/parse` | `{"q"}` | `{"terms": [...], "errors": [...]}` (the filter language; used by the palette for hints) |

## Backlog (change) - each returns `{"ok", "findings", "change": Change, "board": revision, "item": revision?}`

| Method, path | Body (besides `base`) | Tool call |
|---|---|---|
| `POST /api/items` | `{"type", "severity", "area", "who", "effort", "source"?, "related"?, "dependsOn"?, "slug"?, "title", "problem", "evidence", "expected", ...other body fields, "place"?: {"section", "position"}}` | `new` (+ `move` when placed) |
| `POST /api/items/{slug}/fields` | `{"set": {key: value}, "title"?, "reason", "position"?}` | `set` |
| `POST /api/items/{slug}/move` | `{"section", "position"?, "reason"?}` | `move` (also park, reject, reopen, back to Inbox) |
| `POST /api/sections/{section}/order` | `{"order": [slug, ...]}` | `reorder` |
| `POST /api/items/{slug}/block` | `{"reason"}` | `block` |
| `POST /api/items/{slug}/unblock` | `{"note"?}` | `unblock` |
| `POST /api/items/{slug}/close` | `{"reason"}` | `remove --reason` |
| `POST /api/items/{slug}/body/{section}` | `{"markdown"} \| {"remove": true}`, `{"log"?}` | `body` |
| `POST /api/items/{slug}/steps/{n}` | `{"done": bool, "note"?}` | `step` |
| `POST /api/items/{slug}/decide` | `{"option", "decision", "then": {"action", "section"?, "position"?, "type"?, "who"?}}` | `decide` |
| `POST /api/items/{slug}/reply` | `{"state"}` | `reply` |
| `POST /api/items/{slug}/log` | `{"text"}` | `log` |
| `POST /api/items/{slug}/verify` | `{"note"?}` (commit = HEAD of `main`) | `verify` |
| `POST /api/import-github` | `{"number"} \| {"label", "dryRun"?}`, `{"area"?, "severity"?, "type"?}` | `import-github` (network: GitHub; started only here) |
| `POST /api/bulk` | `{"slugs": [...], "operation": {"kind": "block" \| "unblock" \| "move" \| "set", ...}}` | one command per slug; response `{"results": [{"slug", "ok", "refused"?, "findings"?}]}` |
| `POST /api/check/sync` | - | `sync` (the mechanical fix offered by the Check page) |
| `POST /api/lock/release-stale` | `{"confirm": "<slug of the lock>"}` | `lock release --force`; refused unless the lock is stale and no live claude names it |

## Change tray

| Method, path | Body | Effect |
|---|---|---|
| `GET /api/tray` | - | `{"pending": Change[], "outside": paths[], "proposedMessage"}` |
| `POST /api/tray/undo` | `{"changeId"}` | undo that pending change if it is the newest not-undone one and its files are unchanged since; else 409 |
| `POST /api/tray/commit` | `{"message", "includeOutside": paths[]}` | stages the tray's paths (+ the ticked outside paths), commits on `main`; 409 `gate-closed` when not on `main` or something else is staged |
| `POST /api/tray/discard` | `{"changeIds"}` | undo several (newest first), same rules |

## Loop

| Method, path | Body | Effect |
|---|---|---|
| `GET /api/loop` | - | LoopView (+ `logTail`: last 200 lines of `loop.log`) |
| `POST /api/loop/start` | `{"maxItems"?, "maxBlocked"?, "poll"?, "model"?, "untilIdle"?, "autoTriage"?, "forgetRun"?, "commitTray": bool}` | commits the tray if asked (or by the setting), then `loop.py start --new-window ...` |
| `POST /api/loop/run-item` | `{"slug", "model"?, "commitTray": bool}` | `loop.py start --new-window --item <slug>` |
| `POST /api/loop/pause` / `resume` / `stop` | `{"commitTray"?}` (resume) | the loop's command; resume commits the tray first if asked |
| `POST /api/loop/kill` | `{"confirm": "<slug of the running item or 'triage'>"}` | `loop.py kill` |

## Runs and features

| Method, path | Query | Response |
|---|---|---|
| `GET /api/runs` | `outcome`, `from`, `to`, `slug`, `kind` | `{"runs": Run[]}` (newest first; ended runs from cache, the live one computed) |
| `GET /api/runs/{id}` | - | Run with phase timeline, attempts, commits, cost |
| `GET /api/runs/{id}/events` | `from` (byte offset), `limit` | a page of trace events (replay) |
| `GET /api/runs/{id}/raw/{offset}` | - | the raw JSON line at that offset |
| `GET /api/stats` | `from`, `to` | `{"byOutcome", "byArea", "byWeek", "cost", "durations"}` |
| `GET /api/features` | `q` | `{"features": [{"number", "name", "closed", "items"}]}` |
| `GET /api/features/{nnn}` | - | Feature record |
| `GET /api/features/{nnn}/files/{path}` | - | a file of `specs/<nnn>-*/` by a path validated against the listing |
| `GET /api/release` | - | `{"unreleased": markdown, "blockers": Item[], "ahead", "behind", "tags", "records": markdown}` |

## AI jobs ([ai-jobs.md](ai-jobs.md))

| Method, path | Body | Response |
|---|---|---|
| `POST /api/ai/jobs` | `{"kind", "input"}` | AiJob (state `running`); 409 `busy` if one runs; 409 `gate-closed` for proposing kinds while the gate is closed |
| `GET /api/ai/jobs` / `GET /api/ai/jobs/{id}` | - | AiJob list / one |
| `POST /api/ai/jobs/{id}/cancel` | - | AiJob (state `cancelled`) |
| `POST /api/ai/jobs/{id}/apply` | `{"proposal": edited proposal, "base"}` | applies through the backlog routes above; returns the changes |

## Settings, views, events

| Method, path | Body |
|---|---|
| `GET` / `PUT /api/settings` | Settings |
| `GET /api/views`, `POST /api/views`, `DELETE /api/views/{name}` | SavedView |
| `GET /api/events/log` | `?since=<id>` -> Event[] |
| `POST /api/events/seen` | `{"upTo": id}` |

## Streams (Server-Sent Events over `fetch`)

`GET /api/events` - one per tab. Event names and data:

| `event:` | `data` |
|---|---|
| `hello` | `{"state": /api/state}` (first event and after every reconnect) |
| `board.changed` | `{"board": revision, "slugs": changed slugs, "ref"}` |
| `gate.changed` | WriteGate |
| `loop.changed` | LoopView |
| `run.changed` | `{"id", "phase", "tasks", "currentTool", "outcome"}` (summary for every tab) |
| `tray.changed` | `{"pending": n}` |
| `check.changed` | `{"total"}` |
| `job.changed` | AiJob (without the full transcript) |
| `notify` | Event (a new notification) |
| `ping` | `{}` every 15 s |

`id:` is a monotonically increasing counter per server process; a reconnect with
`Last-Event-ID` of an older process gets `hello` again.

`GET /api/runs/{id}/stream?from=<offset>` - one per open live or replay view: `event: trace`
with a TraceEvent per line (`id:` = the byte offset after the line), `event: attempt` at
separators, `event: phase` when the phase changes, `event: ended` when the run ended. A
reconnect with `Last-Event-ID` continues from that offset.

`GET /api/ai/jobs/{id}/stream` - `event: progress` (tool and text), `event: done` (the
proposal or the answer), `event: failed`.
