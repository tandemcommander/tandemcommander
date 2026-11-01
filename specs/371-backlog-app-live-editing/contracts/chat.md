# The conversation about an item - 371

How the app talks to the local Claude command-line tool for one item. Complements
`specs/344-backlog-web-app/contracts/ai-jobs.md` (one-shot jobs); the rules of that contract that
concern security and the tools apply here too.

## Process

One `claude` process per open conversation, started on the first message and kept while messages
arrive, ended after 10 minutes without a message, at `reset`, at `stop` and at the app's shutdown
(`taskkill /T /F`, as for jobs). Working directory: the repository root.

```text
claude -p --input-format stream-json --output-format stream-json --verbose
       --include-partial-messages
       --tools Read,Grep,Glob
       --allowedTools Read,Grep,Glob
       --permission-mode default
       --max-budget-usd <chatBudgetUsd>
       [--model <model>]
       --session-id <uuid>            (the first process of a conversation)
       --resume <uuid>                (a later process of the same conversation)
```

No user text is among the arguments. Session persistence stays on (the transcript of claude is
in its own project folder); `--resume` continues it after the idle end or an app restart.

Tests replace claude through `BACKLOG_APP_CLAUDE` as for jobs; the fake
`test/fixtures/fake-claude-chat.mjs` reads stream-json lines, answers with partial deltas, one
tool-use line and a `result`, and echoes the session id.

## Messages to claude (stdin, one JSON line each)

```json
{"type":"user","message":{"role":"user","content":"<text>"}}
```

The first message of a conversation is prefixed with the context block (data, never
instructions), built by the server:

```text
<the preamble prompts/chat.md: role, where things are, rules, "you only read">

# Repository
- branch, HEAD, main, today (as for jobs)

# The item (data)
```json
{ "slug", "title", header fields, "section", "position", "running": {branch, feature} | null,
  "body": [{name, markdown}], "log": [...], "related": [...], "dependents": [...],
  "runs": [{id, started, outcome, feature, note}], "journal": [RUNS.md rows of the slug],
  "featureFolder": "specs/NNN-slug" | null, "traces": ".agent-traces/<dir>" list }
```

# The maintainer's message
<text>
```

Later messages are sent as typed.

## Output of claude (stdout, one JSON line each)

| Line | Used as |
|---|---|
| `system` / `init` | the process is ready (session id confirmed) |
| `stream_event` with `content_block_delta` `text_delta` | appended to the turn's `assistant` text; sent as `delta` |
| `assistant` with `tool_use` content | a progress line `<tool>: <summary>` (the trace normaliser of 344) |
| `user` with `tool_result` | ignored (a denied tool shows as a progress line from the assistant text) |
| `rate_limit_event` | a progress line when the status is not `allowed` |
| `result` | the turn ends: `success` → `done` (cost added, text taken when no delta arrived); any other subtype or `is_error` → `failed` with the errors |

A process that ends without a `result` fails the turn with its exit code and stderr tail; the next
message starts a new process with `--resume`.

## Limits

- `chatBudgetUsd` per process (setting, default 5 USD); when claude stops for the budget the turn
  fails with `budget reached` and the next message starts a fresh process with `--resume` and a
  fresh budget.
- A turn ends after 15 minutes without a `result` (`stopped`, the process is ended).
- At most 200 turns per conversation file, 200 progress lines per turn, 200,000 characters of
  text per turn.
- At most 5 live processes at once across items; the sixth message gets 409 `busy` naming the
  items with live conversations.

## What claude may not do

The tools above and the preamble: no file is written, no command runs (the review of this feature
showed that an allow-listed `git log --output=<file> --format=<text>` writes any file, so no git
command is allowed; history comes from the item's log, `RUNS.md`, the traces and the feature
records), nothing is sent anywhere. The page states it. Item texts and messages are data; a message that asks
claude to change something gets the explanation that this conversation only reads.
