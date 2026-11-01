# HTTP API additions - 371

Amends `specs/344-backlog-web-app/contracts/http-api.md`. Every route is under `/api`, local
host only, behind the gate of 344 (`contracts/security.md`): token, Origin, JSON bodies with a
length, no user text on a command line.

## Changed answers

### `GET /api/gate` and the event `gate.changed`

`WriteGate` as in data-model.md: `state` gains `run-starting` and `run-on-main`, loses
`loop-between-runs` and `run-holds-lock`; new fields `channel` (`tray` | `commit` | `main-ref` |
null) and `frozenSlug` (string | null).

### Every changing route (`/items/...`, `/sections/...`, `/bulk`, `/items`, `/import-github`, `/check/sync`)

`ChangeResult` gains `channel` and `commit` (the hash when committed at once, else null). New
refusals (HTTP 409, `error.code`):

- `frozen-item` - the change would alter the item a run works on (its own change, or an indirect
  one found after the tool ran); nothing was changed.
- `busy` - the loop holds the edit lock (a run starts or returns to `main`) and did not release it
  within 30 s; the message is the lock's purpose. The gate event follows with `run-starting`.
- `changed-underneath` - also when `main` moved between the change's base and its landing (the
  run's return); `detail.board` is the new revision.
- `check-findings` - in the `commit` and `main-ref` channels a change whose check has findings is
  reverted; `detail.findings` holds them. (In the tray channel the change stays pending with its
  findings, as before.)

### `GET /api/board`, `GET /api/items/{slug}`

`Board.running: RunningItem | null`; while it is set, the running item's row is in *In progress*
(see data-model.md) and `GET /api/next` excludes it. `Item.section` of that slug is
`"In progress"`.

### `GET /api/tray`

`Tray.committedRecently: Change[]` - entries committed at once in the last hour, newest first.

### `GET /api/settings`, `PUT /api/settings`

`chatBudgetUsd` (number, 0.5-50, default 5).

## New routes - the conversation

All take `{slug}` validated by form (the slug pattern) and existence (the board, or an archived
conversation for reads).

| Method | Path | Body | Answer |
|---|---|---|---|
| GET | `/items/{slug}/chat` | - | `Conversation` (turns without progress beyond the last 200 lines each), or an empty one |
| GET | `/items/{slug}/chat/context` | - | `ChatContext`: the item's essentials for the page header (item, runs of the slug, journal rows, related, dependents, feature folder, branch) |
| POST | `/items/{slug}/chat/messages` | `{ text: string (1-20000) }` | `Turn` (state running) · 409 `busy` while a turn runs · 404 `not-found` for an unknown item · 503 `tool-failed` when claude is missing |
| POST | `/items/{slug}/chat/stop` | `{}` | `Turn` (state stopped), or the last turn when none runs |
| POST | `/items/{slug}/chat/reset` | `{}` | the new empty `Conversation` |
| GET | `/items/{slug}/chat/stream` | - | SSE: `delta` `{turn, text}` (appended text), `progress` `{turn, at, text}`, `done` `{turn}`, `failed` `{turn, error}`, `ping`; event ids are `<turn>:<n>`; `Last-Event-ID` resumes |

`chat.changed` `{ slug, turn, state }` is published on the app stream (`GET /api/events`) when a
turn starts or ends, so the item page can show "a reply is being written".

The text of a message goes to claude on stdin as a JSON line (never a command-line argument);
`slug` is never passed to claude as an argument either - the context block names it as data.
