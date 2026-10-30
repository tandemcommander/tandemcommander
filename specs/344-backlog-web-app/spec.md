# Feature Specification: Backlog web app - steer development through the backlog from a browser

**Feature Branch**: `344-backlog-web-app`
**Created**: 2026-10-30
**Status**: Draft
**Input**: User description (Czech, summarised in English): "Analyse, design and implement a web
application - a tool for controlling, monitoring and managing the backlog and its runs - in
`./tools/backlog-app`, a Node.js application written in TypeScript with a backend and a frontend
(the frontend possibly on Vite - the analysis decides). Every source file is documented in detail
in English: documentation comments of classes, methods and variables, and inline comments at the
important places. A new command `./bin/start-backlog-app.sh` starts the whole application. As a
user I want to work with the backlog through it: show it, filter it, query items interactively,
see the live progress of the item being implemented right now, enter a new item, move items
within the backlog - in short, steer the whole development through the backlog from this
application. Choose a frontend framework that gives a very nice and efficient UI with a
light/dark theme switch from the start. Security for now: the application is reachable only on
localhost, so only the user of the machine it runs on can use it. Use several independent agents
in the analysis to design and verify in detail every option and interaction the backlog allows,
so that the application offers the developer as much as possible and development can be steered
through it."

**Analysis**: four independent agents measured the current system before this specification was
written; their reports are in `analysis/`:
`01-backlog-operations.md` (every backlog operation, the tool's gaps, commit and concurrency
rules), `02-run-loop-monitoring.md` (loop states, control, live trace reading, hazards, measured
on scratch repositories), `03-tech-stack-security.md` (technology choice with versions and
licences, localhost security), `04-ux-interactions.md` (40 journeys, screens with wireframes,
interaction rules, priority slices, refute-first coverage table).

## Clarifications

### Session 2026-10-30

- Q: Which user stories does this feature build? → A: all six (stories 1-6); the priorities give
  the order of implementation.
- Q: How are changes made in the application committed? → A: a change tray committed by the
  maintainer's click, with an automatic commit before the loop starts or resumes; undo before
  the commit (FR-034, FR-035).
- Q: User interface language? → A: English; Czech accepted as input of the AI item draft (FR-044).

## User Scenarios & Testing *(mandatory)*

The single user is **the maintainer** of Tandem Commander, working on the machine where the
repository lives. Today the backlog is managed through Markdown files, a command-line tool and
Claude Code skills, and the autonomous loop is watched in a terminal window. The application
gives all of this one place in the browser without replacing the existing tools, which stay
the owners of the data and of the runs.

### User Story 1 - See the backlog and find any item (Priority: P1)

The maintainer opens the application and sees the whole backlog in its real order, section by
section (In progress, Next, Decisions for the maintainer, Person steps, Inbox, Parked,
Rejected), with each item's type, severity, area, who can do it, effort and status. They narrow
the view with filters (section, type, area, severity range, who, status, effort, relations),
search the full text of the items, open an item to read its whole description rendered
readably (problem, evidence, log, options, steps, relations, linked feature records), and copy
or bookmark a link to an item or to a filtered view. The application also shows which item the
next autonomous run would take and why each item above it is skipped.

**Why this priority**: every other journey starts with finding and reading items; it is
read-only and carries no risk to the data, so it is the foundation the rest builds on.

**Independent Test**: with only this story built, start the application on the repository,
compare the shown order and fields of every section with `backlog/BACKLOG.md` and the item
files, apply each filter and a full-text query and check the hits by hand, open a deep link in
a new tab.

**Acceptance Scenarios**:

1. **Given** the backlog with its current items, **When** the maintainer opens the backlog view,
   **Then** every section shows its items in the same order and with the same field values as
   the backlog files, and the counts per section match.
2. **Given** the backlog view, **When** the maintainer filters by area "archives", type "bug" and
   severity at least 4, **Then** exactly the matching items are shown, the filter is visible in
   the page address, and reopening that address restores the same view.
3. **Given** any item, **When** the maintainer opens it, **Then** its full description, log lines,
   relations (related, depends-on, dependents) and links to the feature records that touched it
   are shown, and Markdown is rendered (headings, lists, code, tables, links).
4. **Given** the backlog, **When** the maintainer types a few words into the search, **Then** items
   whose title or body contains them are listed with the matching passage highlighted.
5. **Given** an item that a run closed and removed, **When** the maintainer looks it up in the
   closed-items archive, **Then** its last description and the feature that closed it are shown.
6. **Given** the backlog, **When** the maintainer looks at the "next up" marker, **Then** it names
   the item the next autonomous run would take, with the skip reason of every row above it.

---

### User Story 2 - Watch the running item live and control the loop (Priority: P1)

While the autonomous loop implements items (often for hours, at night), the maintainer sees
what it does: the loop's state (running, waiting and why, paused, pause or stop pending,
waiting for a usage limit and until when, stopped for a person, not running), the item being
implemented, the phase of its run (selection, measurement, specify, clarify, plan, tasks,
analyze, implement, review, merge, close), the task progress, elapsed time, the current tool
action, the latest messages, the commits made so far, attempts and usage. They start the loop
with its options, pause, resume and stop it, and are notified when a run ends, blocks, or the
loop stops and needs them. A loop started from a terminal is seen and controlled the same way.

**Why this priority**: the loop is the engine of development and today its state is a terminal
window and a journal; seeing it and stopping it at the right moment is the first value the
maintainer asked for, and it changes no backlog data.

**Independent Test**: start the loop from the application on a test item (or with the fake
runner the loop's tests use), watch the phases and task progress advance, pause it, resume it,
stop it; start a loop from a terminal and check the application shows and controls it too;
close the application during a run and check the run continues untouched.

**Acceptance Scenarios**:

1. **Given** no loop runs, **When** the maintainer starts it from the application with chosen
   options (maximum items, stop after N blocked runs, until idle, auto-triage, model, forget an
   interrupted run), **Then** the loop starts in a way that survives closing the application,
   and its state appears within a few seconds.
2. **Given** a run in progress, **When** the maintainer opens the live view, **Then** the current
   item, the phase, completed/total tasks, elapsed time, the current action and the recent
   messages are shown and keep updating without reloading the page.
3. **Given** a running loop, **When** the maintainer chooses pause (or stop), **Then** the
   application shows "pause pending" (or "stop pending") until the running item finishes, then
   "paused" (or "not running"); resume cancels a pending stop.
4. **Given** the loop waits (nothing eligible, tree not clean, not on the main line, lock held,
   usage limit), **When** the maintainer looks at its state, **Then** the reason is stated in
   words, with the time of the next attempt where known.
5. **Given** a run ends (closed, blocked, not reproduced, split) or the loop stops for a person,
   **When** this happens, **Then** the maintainer gets an in-application notification and, if
   they allowed it, a desktop notification; a stop for a person stays until it is opened.
6. **Given** a loop started from a terminal, **When** the application is opened, **Then** the
   loop is shown and pause, resume, stop and hard stop work on it exactly as on a loop the
   application started.

---

### User Story 3 - Order and triage the backlog (Priority: P1)

The maintainer reorders items by drag and drop or keyboard, moves items between sections
(Inbox to Next at a position, to Decisions, to Person steps, park, reject, reopen, back to
Inbox), triages the Inbox one item after another with a suggested placement, changes an item's
fields (title, type, severity, area, who, effort, relations), blocks and unblocks items with a
reason, and runs the consistency check and its mechanical fixes. Every change goes through the
existing backlog tool, so the backlog's format rules stay in one place, and the change is
recorded so the loop is not blocked by uncommitted edits.

**Why this priority**: ordering is the maintainer's daily job and the loop takes exactly what
this order says; with stories 1 and 2 it makes the smallest application that really steers
development.

**Independent Test**: on a scratch copy of the repository, reorder Next by drag and drop and by
keys, triage three Inbox items, block and unblock one, park one, reject one with a reason; check
after each step that the backlog files match the tool's own output for the same commands, that
the consistency check stays clean, and that the changes are recorded according to FR-034.

**Acceptance Scenarios**:

1. **Given** the Next section, **When** the maintainer drags an item above another one, **Then**
   the order in the backlog files changes the same way, the row stays where it was dropped, and
   no other item changes.
2. **Given** an Inbox item, **When** the maintainer accepts the suggested placement "Next at #11",
   **Then** the item appears in Next at that position with a log line recording the triage.
3. **Given** a change the tool refuses (for example an item type that does not belong in the
   chosen section), **When** the maintainer tries it, **Then** nothing is written, the tool's
   reason is shown at the control in full, and a fix is offered where one exists.
4. **Given** an autonomous run holds the run lock, the loop runs unpaused, or the working tree is
   not on the main line, **When** the maintainer looks at any changing control, **Then** it is
   disabled with the reason, and reading continues to work.
5. **Given** the item file changed on disk since the maintainer opened it (a run or a terminal
   session wrote it), **When** the maintainer saves a change based on the old view, **Then** the
   change is refused as "changed underneath", the new state is shown, and no typed text is lost.
6. **Given** a park, reject or reopen, **When** the maintainer confirms it, **Then** a reason is
   required, the items depending on it are listed first, and the stored text is shown before it
   is written.

---

### User Story 4 - Decide, record person steps, create and edit items (Priority: P2)

The maintainer answers a "Decision for the maintainer" by choosing one of its options and
writing the decision sentence; works through a person step's checklist and records each
result (and, from a failed step, records a new bug); creates a new item with a form (type,
severity, area, who, effort, title, problem, evidence, relations) that lands in Inbox or
directly at a chosen place; edits the body sections of an item; closes an item that was fixed
elsewhere with a reason; imports a GitHub issue; reads an item's change history; and opens the
records of a finished feature (closing report, fix log, spec, tasks, commits).

**Why this priority**: completes "drive development without the terminal" for everything that
needs no code reading; it depends on the safe change path of story 3.

**Independent Test**: on a scratch copy, record a decision with option B, tick two person-step
lines with results, create a bug item with a multi-line problem text containing backticks,
quotes, Czech letters and `$(...)`, and check that the stored text is byte-exact and nothing of
it was executed.

**Acceptance Scenarios**:

1. **Given** a decision item with options A/B/C, **When** the maintainer chooses B and writes the
   decision, **Then** the decision is stored in the item with the date, and the item moves to
   the section the decision implies (or stays, as the maintainer chooses).
2. **Given** the new-item form, **When** the maintainer submits text with special characters,
   **Then** the item is created with that text unchanged and no part of it is interpreted as a
   command.
3. **Given** an item, **When** the maintainer opens its history, **Then** every past change of its
   description is listed with date, commit and message, and any version can be viewed.
4. **Given** a closed feature, **When** the maintainer opens its page, **Then** its closing report,
   fix log, specification, tasks with progress and commits are shown.
5. **Given** an item that lists a GitHub issue as its source, **When** a person step asks to
   answer the issue, **Then** the application offers to copy the answer and open the issue in
   the browser, and never posts to GitHub itself.

---

### User Story 5 - Ask questions and get AI help (Priority: P3)

The maintainer asks free questions about the backlog and its runs ("which encoding bugs are
small and agent-doable?", "what did the loop do last night?") and gets answers from structured
filters and search, and optionally from the local Claude command-line tool in a read-only
mode. They can let the AI draft a new item from one sentence (Czech or English, recorded in
English), check an Inbox item before placing it, verify an item at the current code, review an
auto-triage plan before it is applied, and judge an imported GitHub issue. AI output is always a
preview that the maintainer confirms; the application applies it with the backlog tool.

**Why this priority**: these are the judgement steps the skills do today; they take minutes and
use the same subscription as the loop, so they come after the deterministic application works.

**Independent Test**: ask three questions of different kinds and check the answers against the
backlog; draft an item from a Czech sentence and check that nothing is written before
confirmation; cancel a running AI job.

**Acceptance Scenarios**:

1. **Given** the Ask page, **When** the maintainer asks a question, **Then** the answer cites the
   items it is based on as links, and the backlog is not changed.
2. **Given** an AI draft of a new item, **When** the maintainer has not confirmed it, **Then**
   nothing is written; after confirmation the item is created as shown in the preview.
3. **Given** a running AI job, **When** the maintainer cancels it, **Then** it stops, its partial
   output is kept for reading, and nothing is written.

---

### User Story 6 - Oversee releases and use power tools (Priority: P3)

The maintainer sees release readiness at a glance (unreleased changelog entries, person steps
and decisions that block a release, the main line ahead of the remote), runs one chosen item
now instead of the next one, hard-stops the loop, releases a stale run
lock with typed confirmation, applies one change to several selected items, and reviews past
runs with their transcripts, outcomes, durations and costs.

**Why this priority**: valuable but rarer (a release every one to three weeks, bulk passes after
a review) or depending on small additions to the loop.

**Independent Test**: on a scratch copy, run a chosen item with the fake runner, hard-stop it and
check that the next start continues it; select five items and block them in one action; open
the transcript of a past run.

**Acceptance Scenarios**:

1. **Given** the release page, **When** the maintainer opens it, **Then** it lists what blocks a
   release and offers no build, tag, push or publish action.
2. **Given** a running loop, **When** the maintainer confirms a hard stop by
   typing the item's name, **Then** the run is stopped the same way as Ctrl+C in its window, and
   the application warns first if a GUI probe may be running.
3. **Given** a past run, **When** the maintainer opens it, **Then** its outcome, phases, duration,
   attempts, cost, commits and full transcript are shown.

---

### Edge Cases

- **Uncommitted changes block the loop**: the loop waits on a dirty working tree; changes made
  in the application must not leave it waiting silently (FR-034), and the application's own
  dependencies, build output and settings must never make the tree dirty.
- **The running item is edited**: changing on the main line the item a run is implementing makes
  the run end with "merge by hand"; the application never offers changes to that item while the
  run holds it.
- **The working tree is on a feature branch** (a run checked out its branch, or the maintainer
  did): the application shows the main line's backlog as recorded in version control (what the
  loop takes its next item from), marks the running item, says so, and does not write; the
  run's own changes are shown in the live view.
- **Another writer at the same time** (a terminal session, Claude Code, the loop's auto-triage):
  every write checks that the files it is based on did not change; two writes from the
  application never run at once.
- **A refused change** writes nothing; **a change written with check findings** is written and
  must not be retried - the two are shown differently.
- **Text with shell meaning** (backticks, `$(...)`, quotes, newlines, very long text) is stored
  byte-exact and never executed; text longer than a command line allows still works.
- **Malformed backlog** (conflict markers, a broken item header, a merge in progress): the
  application falls back to showing the raw content and the check output, read-only.
- **No loop state and no traces yet** (the normal state on a fresh machine): every view shows a
  meaningful empty state, not an error.
- **The application is closed or crashes during a run**: the loop and its run continue
  unaffected; reopening the application picks up the current state.
- **A loop or run dies unexpectedly** (killed, reboot, usage limit): the application shows the
  interrupted run and the recovery the next start will do.
- **Files held open**: the application must never keep a file the loop replaces open (an open
  handle made the loop's atomic replace fail in measurement).
- **A very large trace** (tens of MB): reading it streams and can be cancelled; the live view
  stays responsive.
- **Connection to the application lost**: the page says so, keeps showing the last state, and
  disables changes until it reconnects.
- **Another port is taken / the application is already running**: the start command chooses a
  free port or points to the running instance.
- **Requests from elsewhere**: a web page in the same browser, another user of the machine, or a
  request through a rebinding host name must not be able to read or change anything.

## Requirements *(mandatory)*

### Functional Requirements

**Start and access**

- **FR-001**: A single command `bin/start-backlog-app.sh` MUST start the whole application for
  the repository it belongs to, print its address, and open it in the default browser; it MUST
  answer `--help` (purpose, usage, options, exit 0) without needing the application's runtime,
  as every `bin/` script does.
- **FR-002**: The start command MUST prepare what the application needs on first use and after
  its dependencies change, refuse with a clear message when a required runtime is missing or too
  old, and stop the application cleanly on Ctrl+C without stopping a running loop.
- **FR-003**: The application MUST be reachable only from the local machine and only by the user
  who started it: it MUST accept connections only on the loopback interface, reject requests
  whose host name is not the local address it serves, reject changing requests that do not come
  from its own page, and require a secret created at each start that only the opened browser
  page receives.
- **FR-004**: The application MUST load nothing from the network (no remote fonts, scripts,
  icons or analytics) and MUST make no network requests of its own except those the maintainer
  explicitly starts (a GitHub import).
- **FR-005**: A development mode with live reload MUST exist for working on the application
  itself, with the same access rules as FR-003.

**Reading, filtering and querying**

- **FR-006**: The application MUST show every backlog section in the backlog's own order with
  the fields of each item, reading them through the existing backlog tool or its documented
  file formats, never from a second copy of the data.
- **FR-007**: Users MUST be able to filter by section, type, area, severity range, who, effort,
  status, relations (related to, depends on, depended on by) and "needs" markers; sort by any
  column; and combine filters with full-text search over titles and bodies.
- **FR-008**: The allowed values of every field MUST come from the backlog's legend at run time,
  so a new area or type appears without changing the application.
- **FR-009**: Every view, filter, search and open item MUST be addressable by its page address;
  users MUST be able to save named views.
- **FR-010**: The item view MUST show the rendered description, the log, options, steps,
  relations in both directions, evidence files, the feature records that mention the item, and
  the item's change history from version control, including items already closed and removed.
- **FR-011**: The application MUST show which item the next autonomous run would take and the
  skip reason of every item above it.
- **FR-012**: The application MUST show the result of the backlog's consistency check, refreshed
  after every change.

**Live run and loop control**

- **FR-013**: The application MUST show the loop's state in words (running, triage, waiting and
  why, idle, paused, pause pending, stop pending, waiting for a usage limit until a time,
  backing off, stopped for a person, not running, dead with a stale record) and whether the run
  lock is held, by which item and since when.
- **FR-014**: For the run in progress the application MUST show the item, the phase of the
  implementation flow, completed and total tasks, elapsed time, the current tool action, recent
  assistant messages, commits on the run's branch, attempts with their endings, and token usage
  and cost where the run records them; it MUST update while the page is open with a delay of at
  most a few seconds after the run writes.
- **FR-015**: Users MUST be able to start the loop with every option the loop offers (maximum
  items, maximum blocked runs in a row, poll interval, model, until idle, forget an interrupted
  run, auto-triage); the started loop MUST keep running when the application or the browser is
  closed.
- **FR-016**: Users MUST be able to pause, resume and stop the loop, whether the application or a
  terminal started it, using the loop's own control commands, never by writing its state files.
- **FR-017**: Users MUST be able to hard-stop the loop (whoever started it), with typed
  confirmation and a warning when a GUI probe or an auto-triage is in progress; the effect MUST
  be the same as Ctrl+C in the loop's window (the run is recorded as killed, the lock stays,
  the next start continues the run), and the application MUST never kill a run's Claude
  process alone.
- **FR-018**: Users MUST be able to run one chosen item now (a single run of that item, without
  reordering the backlog), subject to the same preconditions as the loop.
- **FR-019**: The application MUST list past runs (from the run journal, the trace index and the
  run records) with item, outcome, feature, start, duration, attempts and cost, filterable by
  outcome and date, and show one run in full: phases, transcript with tool calls, messages and
  subagent work, its commits and the links to its feature records.
- **FR-020**: The application MUST notify the maintainer when a run ends (with its outcome), when
  the loop stops for a person, when it waits for a usage limit and when it resumes, and when it
  has waited on a precheck for more than 10 minutes; in the page always, and as a desktop
  notification when the maintainer allows it, with quiet hours.
- **FR-021**: The application MUST show the run's branch, the size of all traces, an interrupted
  run waiting to be continued, and the recovery steps the loop states for a person.

**Changing the backlog**

- **FR-022**: Every change of backlog data MUST be made by the existing backlog tool; the
  application MUST NOT write backlog files itself (the only exception is restoring its own
  uncommitted change for undo, FR-035).
- **FR-023**: The application MUST allow changes only when it is safe (the "write gate"): the
  run lock is free, the loop is not running or is paused, no auto-triage is running, the working
  tree is on the main line, and no merge is in progress; otherwise changing controls MUST be
  disabled with the reason, and reading MUST keep working.
- **FR-024**: The application MUST apply changes one at a time and MUST refuse a change whose
  source files changed since the user's view was loaded, showing the new state.
- **FR-025**: Text typed by the user MUST reach the backlog tool without passing through a
  command line or a shell, so that no part of it is ever executed and its length is not limited
  by a command line.
- **FR-026**: Users MUST be able to reorder items within Next, Decisions for the maintainer and
  Person steps by drag and drop and by keyboard, and move items between sections at a position,
  under the backlog's admission rules; a reorder MUST NOT flood the item's log with one line per
  single step.
- **FR-027**: Users MUST be able to triage Inbox items one after another with a suggested
  placement computed from the item's fields and the backlog's rules, accepting, adjusting or
  skipping it with single keys.
- **FR-028**: Users MUST be able to change an item's header fields and title with a recorded
  reason, without losing the item's position in its section.
- **FR-029**: Users MUST be able to block, unblock, park, reject, reopen and close items; park,
  reject, reopen and close MUST require a reason and show the dependent items before writing.
- **FR-030**: Users MUST be able to record a decision on a decision item (chosen option and
  sentence, dated) and record results of person-step checklist lines.
- **FR-031**: Users MUST be able to create an item with every field the item format has, and to
  edit the body sections of an existing item; unsaved text MUST survive a page reload.
- **FR-032**: Users MUST be able to import one GitHub issue by number or every new issue with
  the backlog label, with a preview before anything is written.
- **FR-033**: Users MUST be able to apply one change (block, unblock, move, set a field) to
  several selected items, each validated by the tool, with a per-item result.
- **FR-034**: Changes made in the application MUST be recorded in version control on the main
  line, touching only files under `backlog/`, with messages in the repository's style that a
  run's commit attribution never mistakes for its own. Changes MUST collect in a change tray
  (each listed with its files and reason, the count always visible) and be committed by the
  maintainer's click with an editable proposed message; before the loop is started or resumed
  from the application, pending changes MUST be committed automatically (asked once, the answer
  remembered); dirty files outside `backlog/` are listed as not included and never staged. The
  application MUST never leave the loop waiting on its uncommitted changes without saying so.
  *(Clarified 2026-10-30: change tray with an explicit commit, not one commit per change.)*
- **FR-035**: Users MUST be able to undo their last change before it is recorded in version
  control; after it is recorded, the inverse operations are offered instead.
- **FR-036**: A refused change (nothing written) and a change written with consistency findings
  MUST be shown differently; the second MUST NOT offer a retry.

**AI assistance**

- **FR-037**: Users MUST be able to ask questions about the backlog and its runs and get answers
  that link the items they rely on; a question MUST never change the backlog.
- **FR-038**: Users MUST be able to request, through the local Claude command-line tool, a draft
  of a new item from one sentence (Czech or English, recorded in English), a placement check of
  an Inbox item, a verification of an item at the current code, a reviewed auto-triage plan, and
  an assessment of an imported GitHub issue; every result MUST be a preview applied only after
  confirmation, through the backlog tool.
- **FR-039**: AI jobs MUST show their progress, be cancellable, never run two writing jobs at
  once, and be refused while the write gate is closed.

**Experience**

- **FR-040**: The application MUST offer light and dark themes and follow the system setting by
  default; the choice MUST be remembered and applied before the first paint (no flash).
- **FR-041**: Every action MUST be reachable by keyboard (navigation keys, a command palette,
  a shortcut sheet) and through a visible control; drag and drop MUST have a keyboard
  equivalent.
- **FR-042**: Both themes MUST meet WCAG 2.2 AA contrast; information MUST never be carried by
  colour alone; reduced motion MUST be respected.
- **FR-043**: The application MUST be usable from 900 px window width upward without horizontal
  page scrolling, and readable below it.
- **FR-044**: The user interface language MUST be English, like the backlog records, the legend
  and the tool's messages; there is no translation layer. Input fields accept any language, and
  the AI draft of a new item accepts Czech and records English. *(Clarified 2026-10-30.)*
- **FR-045**: Files changed underneath (by a run, a terminal or Claude Code) MUST appear in the
  open views without reloading; an open editor MUST NOT be overwritten and MUST offer to show
  the difference.

**Boundaries**

- **FR-046**: The application MUST NOT push, fetch, tag, check out, reset, merge, publish, post to
  GitHub, release, or change files outside `backlog/` (other than its own settings outside the
  tracked tree); it MUST NOT touch the run lock or the loop's state files except the confirmed
  stale-lock release through the backlog tool.
- **FR-047**: The application MUST never keep open a file that the loop or the backlog tool
  replaces, and MUST run no version-control command that takes a lock while a run is active.
- **FR-048**: The application's dependencies, build output, caches and settings MUST be ignored
  by version control and by the repository's normalisation and encoding tools, so they never
  make the working tree dirty or get rewritten.

**Changes to the existing tools**

- **FR-049**: Where the backlog tool or the loop lacks something the application needs (reading
  one item in a structured form, the check result and the legend in a structured form, taking
  user text from standard input, editing body sections, reordering without one log line per
  step, keeping a position on a field change, a structured result of every change, a single-item
  run, a hard stop, the reason the loop ended), the addition MUST be backward compatible, keep
  the tools' existing dependency rules (standard library only), and come with tests in their
  existing test suites.

**Quality of the application's code**

- **FR-050**: Every source file of the application MUST be documented in English: a file
  overview, documentation comments on every class, function, method, type, exported constant and
  significant variable, and inline comments at important points (protocol rules, safety checks,
  concurrency, parsing of external formats); this MUST be checked automatically.
- **FR-051**: The application MUST have automated tests for its parsing of every external format
  (backlog, items, run journal, loop state, traces), for the write gate and the change path, for
  the access rules of FR-003, and end-to-end tests of the main journeys against a scratch
  repository with a fake runner.

### Key Entities

- **Backlog**: the ordered overview with sections, the legend (allowed values of every field)
  and the date of the last triage.
- **Item**: one planned piece of work: slug, title, type, severity, area, who, effort, status,
  source, relations (related, depends-on), dates, verification stamp, body sections (problem,
  evidence, options, steps, log), evidence files; closed items live on only in version-control
  history.
- **Section**: In progress, Next, Decisions for the maintainer, Person steps, Inbox, Parked,
  Rejected; each with admission rules.
- **Loop**: the process that runs items one after another; state, options, pending pause or
  stop, waiting reason, usage-limit information, heartbeat.
- **Run**: one implementation of one item (or an auto-triage): item, session, phase, attempts,
  outcome, feature number, branch, commits, trace, start, duration, cost.
- **Run lock**: who holds the right to change the backlog during a run, and since when.
- **Trace**: the growing record of a run's events (messages, tool calls, results, usage) and the
  index of finished runs.
- **Run journal**: the backlog's record of every run outcome.
- **Feature record**: the folder of a finished or running feature: specification, tasks,
  fix log, closing report, probes.
- **Change**: one operation the maintainer made in the application, with its files, reason,
  recorded state (pending or committed) and undo snapshot.
- **AI job**: one requested assistance with its kind, progress, preview and outcome.
- **Saved view**: a named filter and sort.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From a fresh checkout, one command brings the application up in the browser in
  under 2 minutes the first time and under 10 seconds afterwards.
- **SC-002**: The maintainer can do a full morning routine - see what the loop did overnight,
  triage 10 Inbox items, reorder Next, and restart the loop - without opening a terminal or
  editor, in under 10 minutes.
- **SC-003**: For 100% of items, the fields and order shown match the backlog tool's own listing;
  for 100% of changes made in the application, the backlog files equal the result of the same
  operation done with the tool directly, and the consistency check reports no new finding.
- **SC-004**: A run's progress (phase, tasks, latest action) appears in the open page within
  5 seconds of the run writing it, over a run of at least 2 hours, without the page slowing.
- **SC-005**: Any item is found by a filter or search in at most 3 interactions, and results for
  the whole backlog (at least 500 items) appear in under 1 second.
- **SC-006**: Over 20 loop runs with the application open, the application causes zero loop
  waits, zero failed atomic replaces and zero changes to the run lock or the loop's state.
- **SC-007**: Requests from another origin, a foreign host name, another machine or without the
  start secret are refused in 100% of the access tests.
- **SC-008**: User text with shell metacharacters, newlines, non-ASCII letters and 20,000
  characters is stored byte-exact in 100% of tests and never executed.
- **SC-009**: Both themes pass automated WCAG AA contrast checks on every screen; every journey
  of stories 1-3 is completed with the keyboard only.
- **SC-010**: The documentation check reports zero undocumented files, classes, functions and
  exported symbols in the application's sources.
- **SC-011**: Closing the application during a run leaves the run and the loop unaffected in
  100% of tests; reopening shows the current state within 5 seconds.

## Assumptions

**Constraints set by the maintainer** (the request names them; they are not open choices):
the application lives in `tools/backlog-app/`, is a Node.js application written in TypeScript
in both its backend and its frontend, is started by `bin/start-backlog-app.sh` (Git Bash), and
the analysis decided the frontend build tool and framework (`analysis/03-tech-stack-security.md`:
a single-page application built with Vite; framework, libraries, versions and licences recorded
there and confirmed in the plan).

**Scope of this feature**: all six user stories are built in this feature (the maintainer chose
the maximum, 2026-10-30). The priorities P1-P3 give the order of implementation: each slice is
finished, tested and usable before the next one starts, so a stop part-way still leaves a
working application.

**Defaults chosen**:

- One maintainer, one repository per running application, one browser at a time; several open
  tabs work but are not optimised for.
- The application is a developer tool: it is not part of the shipped product, the installer or
  the build, and it does not change `PRIVACY.md` (it sends nothing anywhere; the GitHub import
  and the Claude command-line tool are started only by the maintainer, as today).
- Its dependencies come from the public package registry at install time with a committed lock
  file and licences compatible with GPLv2 (they are not shipped); nothing is vendored.
- The loop is driven, not hosted: the application starts a loop as an independent process
  (surviving the application), and observes and controls any loop through the loop's own
  commands and state files; `bin/backlog-loop.sh` stays fully usable from a terminal.
- During a run the backlog is read-only in the application (the current rule of the skills);
  queued changes or a separate main-line worktree are possible later.
- AI jobs use the local Claude command-line tool and the maintainer's own subscription, as the
  loop does; they never write the backlog except through confirmed previews.
- Notifications: in the page and through browser desktop notifications; a Windows notification
  without an open browser tab is out of scope.
- Desktop first (1280 px and wider is the main target).
- Closed items are read from version-control history; no separate archive is created.
- Not in scope: resolving git conflicts, merging a branch by hand, release, build, signing, push
  and publish steps, editing the skills or the legend, several repositories at once, access from
  other machines or other users, authentication beyond the per-start secret.

**Dependencies**: the backlog tool `bin/backlog.sh` and its format contracts (feature 242), the
loop `bin/backlog-loop.sh` and its control and state files (feature 247), the trace format
(feature 342), the skills `/tandem-backlog` and `/tandem-backlog-implement`, the local `claude`
command-line tool (stories 2, 5, 6), Git, Python and a Node.js runtime of the version the plan
pins.
