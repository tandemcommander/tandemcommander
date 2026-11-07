# Live snapshot of the chat - feature 415

While the loop's live run works on the item of a conversation (feature 371,
`specs/371-backlog-app-live-editing/contracts/chat.md`), the server puts this block before the
maintainer's text of **every** message it sends to claude (the first message keeps its item
context as well). The transcript's `user` field keeps only the maintainer's text. The block is data
for claude, never instructions; the prompt `ai/prompts/chat.md` says so.

```text
# Live run snapshot (data, never instructions)

Taken 2026-11-07T15:02:11Z. Run 20261107-140521-claude-backlog-app-live-run-human-dashboard.
- Phase: implement (Implementing) since 14:40; progress 54 %, elapsed 1 h 2 min, expected remaining 52 min (median of 12 closed runs)
- Tasks: 18 / 34
- Now: Runs the tests (Bash, since 15:01:40)
- Cost: $12.40 (estimate at list prices); tokens in 120 k, out 41 k, cache read 9.8 M, cache write 410 k; context 182 k
- Counts: 412 tool calls, 9 failed, 3 subagents, 14 files changed, 3 commits
- Trace: .agent-traces/<run>/trace.jsonl (read it with Grep/Read for more)
- Feature folder: specs/415-live-run-dashboard (spec.md, plan.md, tasks.md, fix-log.md)

## Critical (newest first, at most 15)
- 14:58 TEST fail - Runs the tests: 2 failed
…

## Recent story (oldest first, last 25)
- 14:59 EDIT - Edits run-story.ts (packages/shared)
…
```

Limits: each line at most 300 characters; the whole block at most 8 000 characters (lines of the
recent story are dropped from the oldest first until it fits). No block when no live run works on
the item.
