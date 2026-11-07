# Research - feature 415

## R1 - Who writes the human story

- **Decision**: deterministic rules over the normalised events (`contracts/story-rules.md`): the
  tool's own `description` (Bash / PowerShell carry one in the real trace), the command's kind
  (build, test, probe, commit, backlog tool, encoding check, translation), the file and its
  component, the result's outcome (`BUILD SUCCEEDED`, `Tests  N passed`, `saltests: N checks, M
  failed`, a non-zero exit), the agent's own messages as Markdown.
- **Rationale**: immediate, free, never invents; the agent's messages already explain its
  decisions in prose; the chat answers "why" on request.
- **Alternatives**: a periodic summary by a model (cost per run, latency, may invent; the chat
  covers it on demand); showing only the agent's messages (misses builds, tests, edits).

## R2 - What the events must carry

- **Decision**: one optional object `info` on `TraceEvent` with `description`, `filePath`,
  `messageId`, `model`, `usage` (input, output, cache read, cache write 5 min / 1 h),
  `outputChars`, `costUsd` and `totals` of a result, `limits` of a rate-limit event, `taskStatus`
  of a subagent progress event. The first event made from an assistant line carries the line's
  usage; a line with only empty thinking still yields its thinking event, so no usage is lost.
- **Rationale**: append-only (old tests and replays keep working); the fields come from the line
  the event is made of; nothing is added to the trace itself.
- **Alternatives**: parse `text` (the input JSON is cut at 4 000 characters - an Edit with a long
  text is not parseable); a second endpoint with raw lines (double the traffic).

## R3 - Tokens and price

- Measured (fix-log *Measure*): in the 414 trace, input, cache read and cache write per message
  (counted once per `message.id`; one message spans several lines) add up exactly to the
  `modelUsage` of the final `result`; the output count of an assistant line is only the count at
  the start of streaming (8 455 vs 344 201). The list prices reproduce the reported cost.
- **Decision**: per attempt (one claude process; its `result` totals are cumulative): reported
  totals and cost of the last `result`; after it, messages counted once by id; output estimated
  as the larger of the streamed count and characters / 3.6, multiplied by a calibration factor
  (reported output growth / estimated output growth between the last two results, clamped 1-8,
  default 2.7, measured on 414 - thinking tokens are not visible in the stream); priced by the model's list
  prices; the run's price = sum over attempts. Shown as "reported" when nothing came after the
  last result, else "estimate". Unknown model: tokens shown, price "unknown".
- **Price table** (USD per million; `claude-api` skill, cached 2026-10-06; cache write 5 min =
  1.25x input, 1 h = 2x input): Fable 5.1 / Fable 5 / Mythos 10 / 50 / read 0.25 (Fable 5.1) or
  1.00; Opus 5.5 4 / 20 / 0.20; Opus 5, 4.8, 4.7, 4.6 5 / 25 / 0.50; Sonnet 5.5, Sonnet 5 2 / 10 /
  0.20; Sonnet 4.6 3 / 15 / 0.30; Haiku 5.5 0.10 / 0.50 / 0.01; Haiku 4.5 1 / 5 / 0.10. Matched by
  the model id's prefix (a dated suffix or `[1m]` still matches).
- **Alternatives**: wait for results only (today's behaviour - the request names it as the gap);
  count characters only (wrong by a factor for cached input).

## R4 - Times of events

- Measured: claude's lines carry no time. The server stamps live events on arrival; at an app start
  during a run it folds the whole trace at once with one time; a replay has no times at all.
- **Decision**: a time index from anchors (offset -> epoch ms): offset 0 = the run's start
  (`started_epoch` of the loop's run record, else the folder's name), every follow tick adds
  (offset read, now) at most every 2 s, attempt separators add their `started`; an offset gets the
  time interpolated linearly between its neighbouring anchors. The live run's anchors are saved in
  the state folder (`cache/times/<run>.json`) every 30 s and at the end; an ended run uses its saved
  anchors, else the anchors of its `meta.json` attempts (start, end) and the index line. The SSE
  stream and the event pages stamp `at` of events without one.
- **Rationale**: phase durations, "since when" and the elapsed time stay meaningful after an app
  restart and for ended runs, without changing the trace.
- **Alternatives**: no times for old events (the phase durations would show "-" for most runs).

## R5 - Progress and expected end

- **Decision**: `estimateProgress()`: fixed phase weights (selection 0.02, measure 0.08, specify
  0.05, clarify 0.03, plan 0.07, tasks 0.03, analyze 0.04, implement 0.38, verify 0.12, review
  0.12, close 0.04, merge 0.02); inside *implement* the task fraction, inside other phases the time
  in phase against its expected share (at most 90 %); expected total = the median wall-clock of the
  last 40 closed item runs (at least 3, else 3 h) blended with the projection elapsed / fraction
  (weight grows with the fraction); never less than the elapsed time; `done` = 100 %.
- **Rationale**: simple, testable, honest about its basis (shown under the bar).

## R6 - Images

- Measured: the API takes only a bearer header (no cookie, by design of 344); an `<img src>` cannot
  send it; the CSP allows `img-src 'self' data:`.
- **Decision**: the page fetches an image with the token and shows it as a `blob:` URL; the CSP
  gets `blob:` in `img-src` (only object URLs the page created; still nothing from the network).
  The server lists images (PNG, JPEG, GIF, BMP, WebP) the trace's main thread or subagents read or
  wrote (`Read` / `Write` with an image path, and image paths in a probe command's `-Out` style
  arguments are not guessed) and those under `specs/<branch>/` (at most 200, depth 4); serves one
  by its number in that list, only after `realpath` shows it inside the repository or the system
  temporary folder, a regular file of at most 25 MB.

## R7 - Documents and decisions

- **Decision**: `GET /api/runs/:id/insight` reads `specs/<branch>/spec.md` (decisions: the
  `- Q: … → A: …` bullets and `Assumption (autonomous run):` lines), the fenced blocks of
  `plan.md` with box-drawing or arrow characters (diagrams), the document list; a document's text
  only through `/documents/:name` from a fixed list. The page asks only while the tab is shown, at
  most every 10 s. Reads are open-read-close (`readFileSync`).

## R8 - Chat

- **Decision**: the panel is the item conversation of 371 (same routes, transcript, tools); the
  server prefixes every message of a live item with the snapshot of
  `contracts/chat-snapshot.md`; `turn.user` keeps only the maintainer's text.

## R9 - No new dependency

- **Decision**: the viewer (pointer swipe, keys, strip), the flow and file-map diagrams (inline SVG
  with theme tokens) and labels are written in the app. Mermaid or PhotoSwipe would add a large
  download and a licence row for little gain.

## R10 - Where the fold runs

- **Decision**: in the browser, incrementally over the events `useTraceStream` already receives
  (new events only; a reset or a trimmed list folds again); the server folds the live run once
  more for the chat snapshot. Measured fold speed: fix-log *Performance* (SC-004).
