# Feature Specification: Live run view - a human-readable dashboard with story, metrics, gallery and chat

**Feature Branch**: `415-live-run-dashboard`
**Created**: 2026-11-07
**Status**: Draft
**Input**: Backlog item `backlog-app-live-run-human-dashboard` (Live run view: a human-readable dashboard with story, metrics, gallery and chat) - implement exactly what it describes. From backlog item backlog-app-live-run-human-dashboard.

## Measured at 90667c3f (before the change)

- The *Live run* page (`tools/backlog-app/packages/web/src/features/live/live-page.tsx`) shows a
  summary card (phase chips, a task bar, the tool in flight, attempts, cost, commits, the latest
  message) and below it the raw transcript - one row per event of the run's `trace.jsonl`
  (`Bash git status --short`, a tool result's first 200 characters, `Read E:\…`).
- The cost is known only from `result` lines (the end of a turn). The run of feature 414 (3 h)
  had 12 of them; between them the page shows the last total or nothing. Token counts are never
  shown (`liveRun()` returns them as 0).
- The trace of feature 414 holds 1100 `assistant` lines (588 messages; 581 lines of subagents).
  Each carries `message.usage`: input, cache read and cache write (5 min / 1 h) are exact when a
  message is counted once (its id); the output count is only the count at the start of the
  streamed message (8 455 counted vs 344 201 reported at the end). `rate_limit_event` lines carry
  the 5-hour and 7-day utilisation; Bash calls carry a human `description`; the run read 13 PNG
  screenshots (probe captures under `specs/NNN-*/probe/` and in `%TEMP%`).
- The list prices of `claude-opus-5-5` (input $4, output $20, cache read $0.20, cache write
  5 min $5, 1 h $8 per million tokens) give $33.899 for the first reported token totals of that
  trace, against $33.895 reported.
- Baseline `npm run check` of `tools/backlog-app`: typecheck, lint, format clean; 366 tests
  passed, 2 skipped.

## Clarifications

### Session 2026-11-07

- Q: Where does the "human-readable" text come from - a model summarising the trace, or rules? → A: rules over the trace (the tool's own description, the file, the command's kind, the result's outcome, the agent's own messages); a model is used only when the person asks in the chat. A rule-based story costs nothing, is immediate and never invents (autonomous run: conservative - no new spending, nothing invented)
- Q: What is "the price"? → A: the price at the list prices of the model the run uses (the prices reproduce claude's own reported cost); between two reported totals the tokens since the last total are priced and added, every reported total replaces the estimate. A run on a subscription is not billed per token; the figure is then what the tokens would cost at list prices, and the page says "at list prices" (autonomous run: item *Expected* + conservative)
- Q: Which screenshots may the gallery show? → A: images (PNG, JPEG, GIF, BMP, WebP) that the run's own trace opened or wrote, and images inside the feature folder of the run (`specs/<branch>/`); a file is served only from that list, never from a path a page sends, and only when it lies inside the repository or the system's temporary folder (autonomous run: item *Expected* - "images are served only when the run's own trace or its feature folder names them")
- Q: What does the expected time to finish rest on? → A: the median wall-clock duration of earlier closed runs (all, or of the same effort when at least three exist), the phase reached, and the task progress inside *implement*; with no history a fixed default. It is shown as an estimate with its basis (autonomous run: item *Approach*)
- Q: Does the chat beside the dashboard start a new kind of conversation? → A: no; it is the item conversation of feature 371 (the same transcript, the same read-only tools, the same limits) shown as a panel; while the item runs, every message carries a fresh snapshot of the run as data (autonomous run: item *Approach*; rule - feature 371 contract)
- Q: Does the page for an ended run (`/runs/<id>`) change too? → A: yes, it uses the same dashboard (story, critical, decisions, gallery, architecture, files, raw trace) without the live parts; durations it cannot know (a replayed trace has no times) are left out (autonomous run: conservative - one view, nothing guessed)
- Q: Where does the chat panel sit, and what happens on a narrow window? → A: on a wide window (at least 1280 px) it is a column on the right that can be hidden (the choice is remembered in the browser); on a narrower one it is hidden by default and opens over the dashboard from a "Chat" button (autonomous run: recommended)
- Q: How often are the documents, the decisions and the gallery list read again during a run? → A: only while their tab is shown, at most every 10 seconds, and once when the tab opens; never in the background (autonomous run: recommended - the run's files are written while it works, reading them seldom keeps the open-read-close promise cheap)
- Q: How large may the live snapshot given to the chat with every message be? → A: at most about 8 000 characters: the run's figures, the current activity, the last 25 story lines, every critical entry (the newest 15), the paths of the trace and the feature folder for Claude to read more (autonomous run: recommended - bounded cost per message)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See what the run is doing, in words, as it happens (Priority: P1)

The maintainer opens *Live run* while the loop implements an item. Instead of program output they
read a story: "Measuring the defect", "Writing the specification", "Builds the program - **build
succeeded**", "Runs the unit tests - **366 passed**", "Edits `live-page.tsx` (web, live)", the
agent's own explanations as formatted text, each line with an icon and a coloured label (BUILD,
TEST, EDIT, DECISION, REVIEW, COMMIT, BACKLOG, ERROR, …). A "now" panel says in one sentence what
happens at this moment and since when.

**Why this priority**: it is the item's main point - the page must be readable by a person.

**Independent Test**: replay a recorded trace into the live view; every main-thread tool call
appears as a sentence with a label and its outcome; routine reads are collapsed; subagent work is
folded under its agent.

**Acceptance Scenarios**:

1. **Given** a run whose trace holds a Bash call with a description and a result, **When** the
   live page shows it, **Then** the story line reads the description (not the command), carries
   the label of its kind and shows success or failure in colour.
2. **Given** ten consecutive reads of files, **When** shown, **Then** they are one collapsed line
   "Reads 10 files" that opens to the list.
3. **Given** a review agent with 40 tool calls, **When** shown, **Then** one line "Review agent:
   <its description>" with the count and its latest status, its calls hidden until opened.
4. **Given** the run moves from *plan* to *tasks*, **When** shown, **Then** a new phase section
   starts with the phase's name in words and the previous one shows its duration.

---

### User Story 2 - Know how far it is, how long it takes and what it costs (Priority: P1)

The header shows a progress bar with the percentage, the elapsed time, the expected remaining time
and the expected end, and the phase steps. A metrics strip shows input / output / cache tokens, the
price in USD updated with every message, the price per hour, the context in use, tool calls,
errors, subagents, files changed, commits and the usage-limit utilisation.

**Why this priority**: "how far, how long, how much" is the first question of anyone watching.

**Independent Test**: a fixed trace fold gives known token sums and a price that matches the
trace's reported cost within 1 % once a result line arrived; the progress estimate is a pure rule
with unit tests.

**Acceptance Scenarios**:

1. **Given** assistant messages arrive without a result line, **When** shown, **Then** the price
   grows with them (an estimate marked as such).
2. **Given** a result line with a total cost, **When** shown, **Then** the price is that total
   (plus nothing more until the next message).
3. **Given** the run is in *implement* with 6 of 12 tasks done, **When** shown, **Then** the
   progress lies between the start and the end of the implement phase's share, proportionally.
4. **Given** no earlier closed run exists, **When** shown, **Then** the expected remaining time
   uses the default and says so.

---

### User Story 3 - See at once what is critical, and what was decided (Priority: P2)

A *Critical* tab with a count lists what the reader must know: a failed build or test, a tool error
that stopped a step, a stop or block of the item, a usage limit, findings of a review, items the run
added to the backlog, steps owed to a person. A *Decisions* tab lists the answers the run recorded
in the feature's specification (*Clarifications*, *Assumptions*) and the agent's statements of what
it decided.

**Why this priority**: the critical items are what a person may have to act on.

**Independent Test**: a trace with a failed build and a `backlog.sh new` gives two critical
entries; a `spec.md` with two clarification bullets gives two decisions.

**Acceptance Scenarios**:

1. **Given** a build result containing "BUILD FAILED", **When** shown, **Then** a critical entry
   with the step and the error's first lines.
2. **Given** the run blocks its item, **When** shown, **Then** a critical entry "The run stopped
   and blocked the item" with the reason.
3. **Given** a spec with `- Q: … → A: …` lines, **When** the Decisions tab opens, **Then** each is
   a question and its answer, with how it was decided.

---

### User Story 4 - Ask about the running item (Priority: P2)

Beside the dashboard a chat panel talks with Claude about the running item. Ready questions
("What is it doing now?", "What did it decide so far?", "What are the risks?", "How long will it
take?") send with one click. Every message carries a fresh snapshot of the run, so the answer
reflects the moment it was asked.

**Why this priority**: the request names it; it reuses the item conversation.

**Independent Test**: with the fake claude of the end-to-end tests, a message sent from the live
page reaches claude with a snapshot block naming the run's phase, and the reply streams into the
panel.

**Acceptance Scenarios**:

1. **Given** a live run, **When** the maintainer sends a question from the panel, **Then** the
   message claude receives contains the live snapshot as data and the question.
2. **Given** the conversation exists on the item's chat page, **When** the live panel opens,
   **Then** it shows the same transcript.

---

### User Story 5 - Look at the screenshots of the work (Priority: P3)

A *Gallery* tab shows the screenshots the run looked at or produced as thumbnails; one opens a
full-screen viewer with swipe, arrow keys, a thumbnail strip, the name and where it came from.

**Why this priority**: valuable for visual features; empty for many runs.

**Independent Test**: a trace that reads a PNG inside the fixture's feature folder gives one
thumbnail served by the app; a path outside the allowed places is not listed.

**Acceptance Scenarios**:

1. **Given** the trace reads `specs/<branch>/probe/shot.png`, **When** the gallery opens, **Then**
   its thumbnail shows and opens in the viewer.
2. **Given** the viewer is open on the first of three images, **When** the right arrow is pressed
   or the image swiped left, **Then** the second shows; Escape closes.

---

### User Story 6 - Understand the solution being built (Priority: P3)

An *Architecture* tab draws the flow of the run (the phases with their state) and a map of the
files the run changed, grouped by component, with how often each changed; the diagrams written in
the feature's `plan.md` (fenced text diagrams) are shown as they are. A *Files* tab lists changed
files and commits; a *Documents* tab shows the feature's `spec.md`, `plan.md`, `tasks.md` and
`fix-log.md` as they are now. The *Raw trace* tab keeps the existing transcript.

**Why this priority**: helps to understand, not needed to follow the run.

**Independent Test**: edits of files in two folders give a map with two groups; a plan with a
fenced diagram shows it.

**Acceptance Scenarios**:

1. **Given** the run edited three files of `packages/web` and one of `packages/server`, **When**
   the Architecture tab opens, **Then** two groups with three and one files.
2. **Given** `plan.md` exists, **When** the Documents tab opens it, **Then** its Markdown renders.

### Edge Cases

- No run is live: the page keeps today's text (what the loop does, which item it would take).
- A trace line is not JSON: the story shows it as an unreadable line, never fails.
- A run with a triage (no item): no chat, no documents; the story and metrics still work.
- A continued attempt (a new claude process): token totals of each attempt add up; the price of
  an attempt is its last reported total plus what came after.
- An unknown model name: its tokens are shown, its price is not guessed ("price unknown for
  model X"); reported totals still count.
- A huge run (50 000 events): the story folds incrementally; the page stays responsive.
- An image deleted after it was listed: the viewer shows "the file is gone".
- The feature folder does not exist yet (before *specify*): the documents list is empty.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The live page MUST show a header with the item (link), feature and branch, a
  progress bar with percentage, elapsed time, expected remaining time and expected end, and the
  phase steps with their names in words.
- **FR-002**: The page MUST show a "now" panel: the current activity as a sentence, since when,
  and the latest message of the agent.
- **FR-003**: The page MUST show live metrics: input, output, cache-read and cache-write tokens,
  the price in USD (estimate between reported totals, the reported total when one arrives, the
  basis named), price per hour, context in use, tool calls, failed tool calls, subagents, files
  changed, commits and the latest usage-limit utilisation.
- **FR-004**: A *Story* tab MUST tell the run in sentences grouped by phase, each entry with an
  icon, a coloured label, an outcome (success / failure / running) in colour, routine reads and
  searches collapsed, subagent calls folded under their agent, the agent's messages as Markdown.
- **FR-005**: A *Critical* tab MUST list failed builds, tests, GUI probes and encoding checks, a
  turn that ended with an error, a stop or block, usage limits, review findings (an agent message
  in the review phase naming a MUST finding), items added to the backlog and person steps; the tab
  shows their count. Other failed tool calls are shown in the story as warnings and counted in the
  metrics, not listed as critical.
- **FR-006**: A *Decisions* tab MUST list the *Clarifications* and *Assumptions* of the feature's
  `spec.md` and the agent's messages that state a decision.
- **FR-007**: A *Gallery* tab MUST show the images the run's trace opened or wrote and the images
  of the feature folder, as thumbnails opening a full-screen viewer with swipe, arrow keys, a
  thumbnail strip and Escape.
- **FR-008**: The server MUST serve a gallery image only from the run's own list, by its number,
  only when it is a regular image file inside the repository or the system temporary folder,
  never from a path given by the page.
- **FR-009**: An *Architecture* tab MUST draw the run's flow and the map of changed files by
  component, and show the fenced diagrams of the feature's `plan.md`.
- **FR-010**: A *Files* tab MUST list the changed files with how often and the run's commits; a
  *Documents* tab MUST show the feature's `spec.md`, `plan.md`, `tasks.md`, `fix-log.md`.
- **FR-011**: A *Raw trace* tab MUST keep the existing transcript with its filter.
- **FR-012**: A chat panel MUST show the item's conversation (feature 371) on the live page, with
  ready questions; while the item runs, every message MUST carry a fresh snapshot of the run as
  data (phase, progress, activity, recent story, critical entries, metrics, trace and feature
  folder paths).
- **FR-013**: The ended run's page MUST use the same dashboard without the live parts.
- **FR-012a**: The chat panel MUST be a hideable right column on windows at least 1280 px wide
  and an overlay opened by a button on narrower ones; the live snapshot MUST stay within about
  8 000 characters.
- **FR-014a**: Documents, decisions and the gallery list MUST be read only while their tab is
  shown, at most every 10 seconds.
- **FR-014**: Nothing the page does MUST change the backlog, the loop, the run or any file; run
  files are read open-read-close; documents and images are read only on request.
- **FR-015**: The page MUST stay responsive with 50 000 events (story folded incrementally, lists
  virtualised or capped).
- **FR-016**: Both themes MUST keep the contrast rules of the app (WCAG AA for text and labels).

### Key Entities

- **Story entry**: one human line of the run - when, phase, kind, label, icon, title, detail,
  outcome, importance, the events it stands for, its children (collapsed reads, subagent calls).
- **Critical entry**: a story entry that must reach the reader, with why.
- **Run metrics**: token sums per kind, reported and estimated cost, model, context in use, counts.
- **Progress estimate**: fraction done, elapsed, expected total, remaining, expected end, basis.
- **Run insight** (server): documents, decisions from the spec, gallery images, estimate basis.
- **Live snapshot**: the text given to the chat with every message while the item runs.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every main-thread tool call of a recorded real trace (feature 414) is shown as a
  sentence; no story line shows a raw command as its title when the call had a description.
- **SC-002**: The live price after the last result line of the 414 trace equals the reported total
  within 1 %, and between result lines it grows with every message.
- **SC-003**: A new trace line shows in the story within 3 seconds of being written.
- **SC-004**: Folding the 6 MB trace of feature 414 into story and metrics takes under 2 seconds
  in the browser.
- **SC-005**: The gallery never serves a file outside the run's list (a request for any other
  number or path is refused).
- **SC-006**: The live page passes the app's accessibility check (no serious or critical axe
  violations) in both themes.
- **SC-007**: `npm run check` and the end-to-end tests stay green; new rules have unit tests.

## Assumptions

- Assumption (autonomous run): the price table lists the current models (Fable 5.1, Opus 5.5,
  Opus 5, Sonnet 5.5, Sonnet 5, Haiku 5.5) at the Claude API list prices of the `claude-api`
  skill (2026-10-06); cache writes at 1.25x (5 min) and 2x (1 h) of input; output tokens between
  reported totals are estimated from the streamed text and tool inputs and corrected by the next
  reported total.
- Assumption (autonomous run): the phase weights of the progress estimate are fixed defaults
  (implement the largest share), not learned; task progress refines *implement*.
- Assumption (autonomous run): no new npm dependency; the gallery viewer, diagrams and labels are
  built with the app's existing libraries (React, Tailwind, lucide icons) and inline SVG.
- The loop, its traces (feature 342) and the item conversation (feature 371) are unchanged; the
  fake claude of the tests gets a step that replays a recorded trace.
