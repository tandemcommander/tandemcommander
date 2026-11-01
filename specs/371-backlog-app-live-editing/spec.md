# Feature Specification: Backlog app revision - editing while a run is in progress

**Feature Branch**: `371-backlog-app-live-editing`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Detailně prověř a analyzuj webovou aplikaci pro backlog v
./tools/backlog-app. Zdali správně fungují všechny její části a případně oprav. Např. na stránce
Home je In progress vždy 0 i když běží implementace. Dále potřebuji možnost editovat a spravovat
backlog nezávisle na tom, zda aktuálně běží implementace položky - přidávat položku a předřadit ji
na začátek fronty Next i za běhu implementace jiné položky. Systém může vyžadovat pauzu, ale pauza
a resume musí být okamžité; vše musí být bezpečné. Dále editovat pořadí položky přímým zadáním
čísla pozice + tlačítko Zařadit na začátek (pozice 1). Ke každé položce chat s Claude Code v
samostatném okně přes celou plochu stránky, který vypíše vše podstatné k položce. Cílem je celková
revize backlog aplikace a její zlepšení tak, abych mohl pracovat s backlogem i když běží
implementace."

## Background

The backlog app (feature 344, `tools/backlog-app/`) steers development through the backlog. Its
measured state at the start of this feature (branch `main`, commit `f46caca4`):

- The app is read-only whenever the loop is alive and not paused, and for the whole duration of a
  run (hours): the write gate says "pause it to change the backlog" or "a run of X holds the lock".
  A pause takes effect only when the running item finishes, so the maintainer cannot add an item or
  change the order of *Next* while an implementation runs.
- During a run the board is read from the main line, where the running item is still a row of
  *Next* with status `open`: *In progress* shows 0 on Home and in the sidebar, and "Next up" names
  the item that is already being implemented.
- A position can be typed only inside the *Move* dialog; there is no "move to the top" control.
- There is no conversation with Claude about an item; the *Ask* page answers one question at a
  time, without the item's context and without a transcript.
- Two unit tests of the app fail since 2026-10-31: they write a run lock dated `2026-10-30`, which
  is now older than the 24-hour stale rule (time-dependent fixtures). Every other check passes
  (282 of 284 unit tests).

The run flow of `/tandem-backlog-implement` already merges a `main` that moved during the run
(step 9: the maintainer's order and triage win, the run's own backlog changes are re-applied) with
one guard: the item the run works on must not change on `main` meanwhile. That is the foundation
this feature builds on: changes made during a run land on the main line and the run picks them up
at its end; the running item is the only thing that stays frozen.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Change the backlog while a run is in progress (Priority: P1)

The maintainer sees that the loop is implementing an item (a run that may take hours). They open
the app, add a new item from a sentence, place it at the top of *Next*, reorder other rows, triage
the Inbox, block an item, edit a description, record a decision. Every change takes effect at once
on the main line of the repository; the running item and the run itself are not disturbed. When
the run finishes, its result and the maintainer's changes are both on the main line, in the
maintainer's order. The loop's next run takes the item that is first in *Next* at that moment -
the one the maintainer just placed there.

**Why this priority**: this is the request that motivates the feature: working with the backlog
must not depend on whether an implementation runs.

**Independent Test**: start the loop on a fixture repository with a fake run that takes a few
minutes; while it runs, add an item and place it at *Next* #1 through the app; verify the main
line holds the new row at #1 within seconds; let the run finish; verify the main line holds both
the run's close and the new item at #1, and that the next run takes the new item.

**Acceptance Scenarios**:

1. **Given** a run holds the run lock and works on item R, **When** the maintainer adds an item
   and places it at *Next* position 1, **Then** the main line shows it at position 1 within
   10 seconds, the run of R continues undisturbed, and the gate shows the backlog as writable.
2. **Given** a run works on item R, **When** the maintainer opens item R, **Then** every changing
   control of R is disabled with the reason that a run works on it, and R cannot be moved,
   closed, blocked, edited or reordered by any route (also not by a bulk change or a drag).
3. **Given** a run works on item R and the maintainer changed *Next* meanwhile, **When** the run
   ends and moves its result to the main line, **Then** the main line holds the run's outcome
   (R closed or blocked, its journal row) and the maintainer's order of *Next*, and no change made
   through the app is lost.
4. **Given** the loop is alive and waiting between runs (nothing running), **When** the maintainer
   changes the backlog, **Then** the change is applied without pausing the loop, and the loop never
   starts a run on a backlog that is in the middle of a change: either the change completes before
   the run begins, or the run begins before the change and the change lands on the main line as in
   scenario 1.
5. **Given** a change made while the loop is alive or a run holds the lock, **When** the maintainer
   looks at the change tray, **Then** the change is listed as committed with its commit, and the
   tray explains that changes made while the loop lives are committed at once.
6. **Given** a run works on item R and another item X names R in its related list, **When** the
   maintainer closes X (which would rewrite R's description to drop the reference), **Then** the
   app refuses the close with the reason that it would change the running item, and nothing is
   changed.
7. **Given** a run is in the step where it returns to the main line (its last minutes), **When**
   the maintainer makes a change at the same moment, **Then** the two never overlap: the run waits
   for the change in progress, or the change is applied after the run's return, and the run never
   fails because of the app's change.

---

### User Story 2 - The running item is shown as in progress (Priority: P1)

The maintainer opens Home or the backlog while a run works on an item. *In progress* shows that
item with its feature number, Next does not show it, and "Next up" names the item the next run
would take.

**Why this priority**: the maintainer called out "In progress is always 0 while an implementation
runs" as a defect; without it the board lies about the state of the work.

**Independent Test**: with a fake run holding the lock on a fixture, open Home: *In progress* = 1
with the item's title; the Next section does not list it; "Next up" names the next eligible item.

**Acceptance Scenarios**:

1. **Given** a run holds the lock for item R with branch `NNN-slug`, **When** Home is opened,
   **Then** the *In progress* count is 1, the *In progress* section lists R with feature `NNN`
   and status in progress, and *Next* does not list R.
2. **Given** the same, **When** the maintainer opens item R, **Then** its page says it is in
   progress, names the feature and the run, and links to the live run.
3. **Given** the same, **When** the maintainer looks at "Next up", **Then** it names the first
   eligible item of *Next* other than R (or "nothing eligible").
4. **Given** the run ended and the lock is free, **When** the board is read again, **Then**
   *In progress* is empty again and the board shows the main line as it is.

---

### User Story 3 - Set a position directly and move to the top (Priority: P2)

The maintainer opens an item of an ordered section and types the position it should have; or
presses "Move to the top" to put it at position 1. The same two controls are at hand in the
section table, on the row.

**Why this priority**: typing a number is faster than dragging through a long section (Next
holds 46 rows); "to the top" is the most frequent intent.

**Independent Test**: on the item page of Next #20, type 3 and confirm: the row is at #3; press
"Move to the top": the row is at #1; both are visible in the board within 3 seconds.

**Acceptance Scenarios**:

1. **Given** an item at *Next* #20, **When** the maintainer types 3 into the position field and
   confirms, **Then** the item is at #3 and the rows that were at 3-19 are at 4-20.
2. **Given** an item at *Next* #20, **When** the maintainer presses "Move to the top", **Then** the
   item is at #1.
3. **Given** a section of N rows, **When** the maintainer types a number larger than N, **Then**
   the item goes to the last position; **When** they type 0, a negative number or text, **Then**
   nothing changes and the field says what it accepts.
4. **Given** the item is the one a run works on, or the section is *In progress*, or the section
   is not ordered (Inbox, Parked, Rejected), **When** the maintainer looks for the controls,
   **Then** they are absent or disabled with a reason.
5. **Given** a filter or a column sort is active on the section table, **When** the maintainer
   uses the row's position control, **Then** the position still counts in the backlog's own order
   and the change is applied to that order (the control does not depend on what is visible).

---

### User Story 4 - A conversation with Claude Code about one item (Priority: P2)

From an item, the maintainer opens a conversation window: a separate browser window that uses the
whole page, shows everything essential about the item at the top (title, type, severity, area,
who, effort, status and section with position, source, the feature and branch if a run works on
it, its last runs with outcomes, related items, the description sections), and a conversation with
Claude Code below. The maintainer asks questions ("what would you check first?", "which files does
this touch?", "summarise the last run"), Claude answers from the repository, the answer streams in
as it is produced, and the conversation is kept per item so that it continues after a reload or on
another day.

**Why this priority**: the maintainer asked for it explicitly; it builds on the existing Claude
integration and changes nothing in the backlog.

**Independent Test**: open the conversation window of an item on a fixture with the fake Claude;
the window shows the item's essentials; send a message; the reply appears progressively; reload
the window: the exchange is still there; start a new conversation: it is empty.

**Acceptance Scenarios**:

1. **Given** an item page, **When** the maintainer presses "Chat about this item", **Then** a new
   browser window opens that shows only the conversation page (no app sidebar), with the item's
   essentials visible without scrolling on a 1080p screen.
2. **Given** the conversation window, **When** the maintainer sends a message, **Then** the message
   appears in the transcript at once, the reply appears as it is produced (first words within
   30 seconds on a normal connection), tool use of Claude is shown as short progress lines, and
   the input is available again when the reply ends.
3. **Given** a conversation with earlier exchanges, **When** the window is reloaded or opened again
   later, **Then** the earlier exchanges are shown and the next message continues the same
   conversation.
4. **Given** a reply in progress, **When** the maintainer presses "Stop", **Then** the reply ends
   within a few seconds and what was produced so far stays in the transcript.
5. **Given** any conversation, **When** Claude is asked to change the backlog or a file, **Then**
   nothing changes: Claude only reads, and the page says so.
6. **Given** the Claude command-line tool is missing or fails, **When** a message is sent,
   **Then** the page explains it and the transcript is kept.

---

### User Story 5 - The app's parts work (revision) (Priority: P3)

The maintainer runs the app's checks and uses every page; what is broken is fixed.

**Why this priority**: the request is a revision; the two defects already known are covered by
stories 1 and 2, and the test suite must be trustworthy again.

**Independent Test**: the app's check suite (type check, lint, formatting, unit tests) and the
end-to-end suite pass on a clean checkout, on any day.

**Acceptance Scenarios**:

1. **Given** the repository at this feature's end, **When** the check suite runs, **Then** every
   test passes, and no test depends on the current date.
2. **Given** the end-to-end suite, **When** it runs with the fake tools, **Then** every scenario of
   stories 1-4 that can be driven by a browser passes.
3. **Given** every page of the app on a copy of the real repository, **When** each is opened and
   its controls used, **Then** no page fails, and defects found on the way are fixed in this
   feature or recorded in the backlog's Inbox with their evidence.

---

### Edge Cases

- A change arrives while the run is just taking its lock or just releasing it: the app and the
  loop never act on the backlog at the same moment (the edit lock orders them), so the change is
  applied either before the run's step or after it; it is never half applied.
- The run's return to the main line finds the maintainer's changes: the run merges them by its
  existing recipe; a conflict the recipe cannot resolve stops the run with its existing reason and
  the maintainer merges by hand - no change of the app is lost in either case.
- The maintainer changes an item that a run has not started yet but the loop is about to take: the
  loop's own precheck decides again after the change, so it takes the backlog as changed.
- The maintainer changes the backlog from a terminal while a run is in progress: outside the
  app's scope, as today (the skill refuses it).
- The app is restarted while a change was being recorded on the main line: at start the app
  cleans up its own leftovers; the main line is either unchanged or holds the whole change.
- The loop's own auto-triage runs: the backlog stays read-only until it finishes (a few minutes).
- A merge is in progress in the working tree, or the working tree is on another branch with no run
  (the maintainer's manual work): read-only as today, with the reason.
- The position field receives text, 0, a negative number, or a number larger than the section.
- A conversation window is closed while a reply is being produced: the reply completes and is in
  the transcript when the window opens again.
- Two conversation windows of the same item: one reply at a time per item; the second window shows
  the reply in progress.
- The repository's working tree is on a run's branch when a conversation is opened: Claude is told
  which branch the files it reads belong to.

## Requirements *(mandatory)*

### Functional Requirements

**Editing while the loop lives or a run is in progress**

- **FR-001**: The app MUST allow every backlog change (new item, place, reorder, position, move,
  block, unblock, park, reject, reopen, close, decide, record steps, reply state, field and text
  edits, log lines, verify, bulk changes, GitHub import, sync) while a run holds the run lock, and
  while the loop is alive in any of its waiting states, without pausing or stopping the loop.
- **FR-002**: While a run holds the run lock, a change MUST land on the main line of the
  repository (the line the loop takes its items from and the run merges at its end), never in the
  run's working tree, and MUST be visible in the app's board within 10 seconds.
- **FR-003**: The item a run works on MUST NOT be changed by the app while the run holds the lock:
  its own changes are refused with a reason, and any change of another item that would alter the
  running item's description (a reference removed by a close, a related list rewritten) MUST be
  refused before anything is written.
- **FR-004**: The app and the loop MUST never act on the backlog at the same moment: a change in
  progress holds the loop's decision to start a run and the run's return to the main line; the
  loop's start of a run holds the app's change. Neither waits longer than the other's step takes.
- **FR-005**: Changes made while the loop is alive or a run holds the lock MUST be committed at
  once on the main line with the app's commit message form, each change its own commit, and the
  change tray MUST show them as committed; changes made while no loop lives keep today's tray
  behaviour (pending until the maintainer commits, undo of the newest).
- **FR-006**: The write gate MUST tell the maintainer, at every disabled control and in the
  banner, why the backlog is read-only; the remaining read-only states are: the loop's own
  auto-triage, a merge in progress, a working tree on another branch with no run, a stale run lock,
  another app changing the backlog, and a backlog that cannot be read.
- **FR-007**: A change MUST be refused when the view it was made from is older than the main
  line's current state (changed underneath), with the new state, exactly as today.

**The running item**

- **FR-008**: While a run holds the run lock for an item, the board MUST show that item in
  *In progress* (status in progress, the feature number of the run's branch, the run's start) and
  MUST NOT show it in its former section; counts, Home, the sidebar and the item page MUST follow.
- **FR-009**: "Next up" MUST name the first eligible item other than the running one.
- **FR-010**: Once the lock is released, the board MUST show the main line as it is (the closed
  item gone, or the blocked item back in its section).

**Positions**

- **FR-011**: The item page of an item in an ordered section (*Next*, *Decisions for the
  maintainer*, *Person steps*) MUST offer a position field and a "Move to the top" control; the
  section table MUST offer both on each row.
- **FR-012**: A typed position N MUST place the item at N (1 = top; larger than the section = last)
  without a log line per step; invalid input MUST be refused with a hint and change nothing.
- **FR-013**: The controls MUST be absent or disabled with a reason for the running item, for
  *In progress*, for unordered sections, and while the backlog is read-only.

**Conversation about an item**

- **FR-014**: The item page MUST offer "Chat about this item", which opens the conversation page in
  a new browser window without the app's frame, using the whole page.
- **FR-015**: The conversation page MUST show the item's essentials at the top: title, slug, type,
  severity, area, who, effort, status, section and position, source, created and updated days,
  feature and branch when a run works on it, the item's last runs with their outcomes, related and
  dependent items, and the description sections (expandable).
- **FR-016**: Claude MUST receive the item's description, its journal rows, the location of its run
  traces and feature records, and the repository's rules, and MUST be able to read the repository
  (files and git history) and nothing else: no change of any file, no network, no command that
  changes state.
- **FR-017**: Replies MUST stream to the page as they are produced; Claude's tool use MUST be shown
  as short progress lines; a reply in progress MUST be stoppable.
- **FR-018**: The transcript MUST be kept per item on the server (surviving reloads and app
  restarts) and offered again when the page opens; "New conversation" MUST start an empty one.
- **FR-019**: One reply at a time per item; conversations of different items MAY run at the same
  time; a running reply MUST not block the app's other work.
- **FR-020**: A conversation MUST have a cost cap per conversation (a setting with a default), and
  the page MUST show the cost so far when known.

**Revision**

- **FR-021**: No automated test of the app MAY depend on the current date or time.
- **FR-022**: The security rules of feature 344 MUST hold for every new route: local host only, the
  session token, JSON bodies, no user text on a command line, identifiers checked against the
  tool's listing.
- **FR-023**: The app MUST still never write a backlog file itself, never touch the loop's state
  files, never push, tag or publish.

### Key Entities

- **Change during a run**: a backlog change applied to the main line while a run holds the lock;
  carries the operation, the items, the commit it became, and the state of the main line it was
  based on.
- **Running item**: the item named by the run lock, with the feature number and branch from the
  lock and the run's start; shown in *In progress*; frozen for the app.
- **Conversation**: per item; a list of exchanges (the maintainer's message, Claude's reply with
  its progress lines, timestamps, cost); a conversation identity that lets the next message
  continue it; the item's context given at the first message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: While a fake run of several minutes holds the lock, a new item placed at *Next* #1
  through the app is on the main line within 10 seconds, without any pause, stop or wait of the
  run.
- **SC-002**: In 20 fake runs with 3 app changes made during each, every change is present on the
  main line after the last run ends, in the maintainer's order; no run fails because of a change.
- **SC-003**: With a run holding the lock, Home shows *In progress* 1 and names the running item;
  *Next* does not list it; "Next up" names another item.
- **SC-004**: Typing a position or pressing "Move to the top" shows the new order within
  3 seconds.
- **SC-005**: A conversation window shows the item's essentials without scrolling at 1920 x 1080,
  the first words of a reply within 30 seconds on a normal connection, and the transcript after a
  reload.
- **SC-006**: The app's check suite and its end-to-end suite pass on the day of the feature and on
  any later day (no time-dependent test).
- **SC-007**: The loop never starts a run while an app change is in progress, measured with a
  fake loop at a 50 ms tick over 200 app changes: zero runs started on a half-changed backlog.

## Assumptions

- Changes made while the loop lives are committed at once (one commit per change, the app's
  message form `backlog(app): ...`), because the loop needs a committed main line to start its
  next run and a run can only merge what is committed. The maintainer's earlier preference for a
  tray (feature 344, research R11) is kept for the time no loop lives. Undo is not offered for a
  committed change; a counter-change is made instead.
- No pause of a running item is needed for editing, so none is introduced; the loop's existing
  pause (the item finishes, then the loop waits) and stop keep their meaning.
- The run flow's merge of a moved main line (skill step 9, the backlog recipe) is the mechanism
  by which the run picks the maintainer's changes up; this feature adds only what makes the two
  sides never overlap (FR-004) and keeps the running item frozen (FR-003).
- A conversation reads the repository as it is on disk (the run's branch while a run is in
  progress) and is told so; it never runs a command that changes state.
- The conversation keeps one transcript per item until the maintainer starts a new one; old
  transcripts of removed items are pruned after 30 days.
- The app runs on the maintainer's machine only; the browser is Edge or Chrome; the Claude
  command-line tool is installed and signed in, as for the existing AI jobs.
