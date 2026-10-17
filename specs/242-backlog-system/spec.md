# Feature Specification: Backlog System Outside `specs/`

**Feature Branch**: `242-backlog-system`
**Created**: 2026-10-17
**Status**: Draft
**Input**: User description: "Nyni postavime cely novy system pro backlog tak jak jsme jej probrali v kontextu. Detaily a zbyvajici body vyresime v ramci clarify faze. Jednotlive kroky Spec Kit flow nyni budu spoustet manualne ja."
(Build the whole new backlog system as discussed in the conversation; details and remaining points are settled in the clarify phase; the maintainer runs the Spec Kit steps by hand.)

## Context

Planned work is today spread over seven places: `specs/NEXT-WORK.md` (2,226
lines mixing the backlog, the release checklist, a revision diary, the history
of done items and decisions), five `specs/NNN-*/REMAINING-WORK.md` files, the
"Left by" / "Owed to a person" lists of fix-logs, the former `issues/` and
`features/` folders (deleted by the maintainer, deletion not yet committed),
`temp/` and the assistant's memory. Done items are struck through instead of
removed (about 120 strike-throughs), items have no stable identity (they are
referenced by position, e.g. "item 5, first entry", "5j"), fields such as
severity are free text, and new findings are appended inside older items,
producing chains up to eight features deep.

The maintainer wants one formal backlog that does not touch `specs/` (which is
reserved for features being implemented), is readable by a person at a
glance, and can feed the Spec Kit flow so that one backlog item can later be
implemented autonomously.

## Clarifications

### Session 2026-10-17

- Q: What happens after migration to `specs/NEXT-WORK.md` and the five `specs/*/REMAINING-WORK.md` files? → A: `NEXT-WORK.md` is deleted (git and the migration ledger keep its content); each `REMAINING-WORK.md` stays and gets a one-line note at its top that its open items moved to `backlog/` on the migration date.
- Q: From which branch does an autonomous run start and where does finished work end up? → A: The feature branch is created from local `main`; on success (tests and review passed) it is fast-forwarded into local `main`, never pushed. On a stop the branch stays unmerged, but the item's status change (`blocked` with reason) is also committed to `main` so the next run does not pick it again.
- Q: How does an autonomous run create its branch and commit? → A: The branch is created by the Spec Kit git extension (`speckit-git-feature`); the run executes the extension's commit hooks after each Spec Kit step as configured (commits "[Spec Kit] …"), and ends with one commit in the project's style `[NNN] <summary>`.
- Q: Where does an autonomous run write its summary for the maintainer? → A: In the feature's `closing-report.md` when a feature was created, and in every case as one line in the run journal `backlog/RUNS.md` (date, item, outcome, feature number, branch, number of new *Inbox* items, steps owed to a person).
- Q: Does an autonomous run refuse to start while another run is in progress? → A: Yes. A run holds an unversioned lock (under `.git/`) naming its start time, item and branch, and removes it at its end; a run that finds the lock ends with "another run in progress". A lock older than the stale limit is reported as stale and released by the maintainer, never by a run.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record a new item and see it in the overview (Priority: P1)

The maintainer (or an agent finishing a review) has a new bug, idea or
leftover. They record it once, with its title, source, area, date, severity
and description, and it appears in the overview's *Inbox* with a link to its
own description. A check confirms the backlog is consistent.

**Why this priority**: Without a place to put new work and a defined item
format, nothing else in the system has content. This is the minimal viable
backlog.

**Independent Test**: Starting from an empty backlog, add three items of
different types; the overview lists all three in *Inbox* with correct derived
columns, each links to an existing description, and the consistency check
reports no findings.

**Acceptance Scenarios**:

1. **Given** an empty backlog, **When** the maintainer adds an item "Packing a
   folder with a too long name fails silently" (bug, severity 6, area
   archives, source manual), **Then** a folder `backlog/items/<slug>/` with a
   complete description exists and the overview's *Inbox* has one row linking
   to it, with status `new`.
2. **Given** an item whose slug already exists, **When** another item with the
   same derived slug is added, **Then** the addition is refused or a distinct
   slug is chosen; no existing item is overwritten.
3. **Given** an agent reviewing feature 250 finds a defect, **When** it records
   it, **Then** the item lands in *Inbox* with source `review:250` and the
   agent changes nothing else in the overview's order.
4. **Given** an item with a missing mandatory field, **When** the check runs,
   **Then** it names the item and the field and reports failure.

---

### User Story 2 - Triage, order and maintain items (Priority: P2)

The maintainer reviews *Inbox*, sets severity, decides each item's section
(*Next*, *Decisions*, *Person steps*, *Parked*, *Rejected*) and its position,
updates fields, records decisions and re-verifies items. The order in the
overview is the priority. They can list and filter items and open one item's
detail.

**Why this priority**: The backlog only becomes a plan once it is ordered;
this replaces the hand-maintained "Open items at a glance".

**Independent Test**: With ten items in *Inbox*, triage them into sections and
order *Next*; the overview shows the new order with consistent numbering, each
item's status matches its section, and the check passes.

**Acceptance Scenarios**:

1. **Given** items in *Inbox*, **When** the maintainer triages one into *Next*
   at position 2, **Then** its status becomes `open`, it appears second in
   *Next*, later rows are renumbered, and its log records the triage with the
   date.
2. **Given** an item in *Next*, **When** it is parked or rejected, **Then** a
   reason is required and recorded, and the item moves to the matching
   section.
3. **Given** a `decision` item, **When** the maintainer decides it, **Then** the
   decision is recorded in the item's log and the item either becomes a work
   item in the appropriate section or is rejected with the decision as reason.
4. **Given** the maintainer asks for all open items in area `ftp` with
   severity ≥ 5, **Then** only matching items are listed, in backlog order.
5. **Given** an item, **When** it is re-verified at the current commit,
   **Then** its verification stamp shows the date and commit.

---

### User Story 3 - Migrate today's backlog and retire `NEXT-WORK.md` (Priority: P3)

Every open entry of the current scattered backlog is moved into the new
system, and the project's documents point to the new backlog instead of
`specs/NEXT-WORK.md`.

**Why this priority**: The system is only trusted if it holds all open work;
two parallel backlogs would drift immediately.

**Independent Test**: A migration ledger lists every open entry of the old
sources with its destination (item slug, merged into an item, release
checklist, or "already done — not migrated"); no open entry is unaccounted
for, and no project instruction still directs work to `NEXT-WORK.md`.

**Acceptance Scenarios**:

1. **Given** the open entries of `NEXT-WORK.md` (sections *Before 0.1.10*, A,
   B, C, D and *Recorded, deliberately not on the list*) and of the five
   `REMAINING-WORK.md` files, **When** migration completes, **Then** each open
   entry maps to exactly one destination in the ledger.
2. **Given** a "decided — not to do" entry, **When** migrated, **Then** it
   becomes a `rejected` item that keeps its reason and the decision date.
3. **Given** an entry struck through as done, **When** migrated, **Then** it is
   not turned into an item; only its open leftovers are.
4. **Given** the release preparation steps (version bump, tag, release with
   installer, winget), **When** migrated, **Then** they live in a release
   checklist document of the backlog, not as backlog items.
5. **Given** migration completed, **When** `CLAUDE.md`, `FEATURE-HISTORY.md`
   and the architecture reference are read, **Then** they direct "what to work
   on next" and "where to record a finding" to the new backlog.

---

### User Story 4 - Implement one backlog item autonomously (Priority: P4)

The maintainer starts an autonomous run that takes one eligible item (the top
of *Next*, or a named one), runs the full Spec Kit flow with the item's
description as the input of `specify`, follows the project's working rules,
and ends with either a finished feature or a recorded stop. One run handles
one item and ends; repeating runs is a later layer.

**Why this priority**: It is the goal the structure serves, but it depends on
stories 1–3 existing and being populated.

**Independent Test**: With a small, eligible test item at the top of *Next*,
one run creates the feature, completes the flow, removes the item from the
backlog, records leftovers in *Inbox*, and reports a summary; with an
ineligible item on top (a `decision`), the run skips it.

**Acceptance Scenarios**:

1. **Given** the top of *Next* is an eligible item, **When** a run starts,
   **Then** the item gets the next free feature number, its status becomes
   `in-progress` with that number, and the Spec Kit flow starts with the
   item's description as input.
2. **Given** an item whose defect no longer reproduces at the current commit,
   **When** the run measures it first, **Then** no feature is created and the
   item is updated with the finding (and left for the maintainer to close).
3. **Given** the flow meets a question that belongs to the maintainer (a
   public claim, the plug-in interface, installer behaviour, an explicit
   product decision), **When** clarification would need that answer, **Then**
   the run stops, the item becomes `blocked` with the reason, and a `decision`
   item is added to *Inbox*.
4. **Given** the run finishes the feature, **When** it closes, **Then** the item
   is removed from the backlog, leftovers and review findings become new
   *Inbox* items with sources `leftover:NNN` / `review:NNN`, and the run ends
   without pushing or publishing.
5. **Given** items whose `who` is `person`, whose type is `decision`, which are
   `blocked`, in *Inbox*, or whose dependencies are not done, **When** a run
   picks the next item, **Then** those items are skipped.

---

### User Story 5 - Import a GitHub issue as an item (Priority: P5)

The maintainer imports a GitHub issue by number; the item keeps the original
issue text and a place for the drafted reply, with source `github#N`.

**Why this priority**: GitHub reports are a regular source (issues #3–#8 were
handled in features 124–128), but they can also be added by hand through
story 1.

**Independent Test**: Import an existing issue; the item has the issue text,
an empty reply draft, source `github#N`, and sits in *Inbox*. Importing the
same issue again is refused.

**Acceptance Scenarios**:

1. **Given** issue #N exists, **When** imported, **Then** an item with the
   issue's original text, a reply draft placeholder and source `github#N` is
   created in *Inbox*.
2. **Given** an item with source `github#N` already exists, **When** #N is
   imported again, **Then** the import is refused and names the existing item.

---

### Edge Cases

- An item folder without a description, or a description whose folder is not
  listed in the overview (orphan), or an overview row whose folder does not
  exist (dangling) — the check reports each.
- The same item listed twice in the overview, or in a section that does not
  match its status — the check reports it.
- `related` / `depends-on` naming an item that does not exist; a dependency
  cycle — the check reports it.
- `blocked`, `parked` or `rejected` without a reason; `in-progress` without a
  feature number, or with a number that has no `specs/NNN-*` folder — the
  check reports it.
- A severity outside 0–10, an area, type, status or source not in the allowed
  vocabulary, a date that is not a date — the check reports it.
- A slug renamed by hand (the old slug is referenced elsewhere) — references
  become dangling and the check reports them; slugs are never renamed.
- Two sessions add items to *Inbox* at the same time — in the same working
  tree the tool is not safe for concurrent writers (measured in review:
  rows lost), so the skills run one changing command at a time; on two git
  branches both rows are appended at the same place and git reports a
  conflict, resolved by keeping both rows and running `sync`. Neither
  session reorders other sections.
- An autonomous run is started while another one is active — it ends with
  "another run in progress" and changes nothing; a crashed run leaves a lock
  that is reported as stale after 24 hours and released by the maintainer.
- *Next* is empty or contains no eligible item — an autonomous run reports
  "nothing to do" and changes nothing but its journal line (FR-038).
- An item turns out too large for one feature during the run — the run stops
  and proposes a split as new *Inbox* items instead of starting a feature it
  cannot finish.
- A rejected item gets a new reason to be done — it is re-opened with the new
  reason recorded in its log.
- Titles and descriptions contain non-ASCII text (Czech names, paths with
  accents) — they are stored and shown intact; slugs stay ASCII.

## Requirements *(mandatory)*

### Functional Requirements

**Location and structure**

- **FR-001**: The backlog MUST live in the top-level folder `backlog/`, with
  the overview `backlog/BACKLOG.md` and one folder per item
  `backlog/items/<slug>/`. Backlog management MUST NOT create or modify
  anything under `specs/`.
- **FR-002**: An item's slug MUST consist of lowercase ASCII letters, digits
  and single hyphens, MUST NOT carry an order number, MUST be unique, and
  MUST NOT change after the item is created.
- **FR-003**: Each item folder MUST contain `desc.md`. It MAY contain
  `issue.md` (original GitHub issue text), `reply.md` (draft reply to the
  issue thread, with its sent/not-sent state) and `evidence/` (captures,
  probe output).

**Item description (`desc.md`)**

- **FR-004**: `desc.md` MUST begin with a metadata header holding these
  fields: `title`, `type`, `status`, `severity`, `area`, `source`, `who`,
  `created`, `updated`, `verified`, `effort`, `feature`, `related`,
  `depends-on`, `reason`.
- **FR-005**: Allowed values MUST be fixed:
  - `type`: bug, feature, improvement, tech-debt, decision, person-step;
  - `status`: new, open, blocked, in-progress, parked, rejected (done items
    are removed, FR-020);
  - `severity`: integer 0–10;
  - `who`: agent, person, both;
  - `effort`: S, M, L, ? (optional);
  - `source`: `manual`, `github#N`, `review:NNN`, `leftover:NNN`,
    `measure:NNN`, `probe:NNN`, `next-work` (migrated entries whose origin
    cannot be identified);
  - `area`: build-release, translations, encoding, long-paths, file-ops,
    data-safety, panels-ui, viewer, archives, plugin-api, webview,
    privacy-security, ftp, sftp, pictview, other-plugins, help-docs, tooling.
  New values MAY be added only by changing the legend of the overview (FR-010).
- **FR-006**: `verified` MUST hold the date and the commit at which the
  described state was last confirmed, or `-` when never confirmed.
- **FR-007**: `reason` MUST be filled for `blocked`, `parked` and `rejected`;
  `feature` MUST be filled for `in-progress`.
- **FR-008**: The body MUST have the sections *Problem*, *Evidence*,
  *Expected* and *Log*; *Approach* and *Notes* are optional. `decision` items
  MUST add *Question*, *Options* and *Recommendation*; `person-step` items
  MUST add *Steps* as a checklist and name the feature or guide they come
  from. *Log* holds dated one-line entries of every status change, decision
  and verification.
- **FR-009**: The severity scale MUST be defined with anchors: 9–10 data loss
  or crash in a common scenario; 7–8 data loss in a narrow scenario or crash in
  an unusual one; 4–6 a function does not work, a workaround exists; 1–3
  cosmetic or wording; 0 trivial. For `feature` and `improvement` the number
  expresses importance on the same scale.

**Overview (`BACKLOG.md`)**

- **FR-010**: `BACKLOG.md` MUST contain a short header with the ordering rules
  and the date of the last triage, the sections *In progress*, *Next*,
  *Decisions for the maintainer*, *Person steps*, *Inbox*, *Parked*,
  *Rejected*, and a *Legend* defining the vocabularies and the severity scale.
- **FR-011**: Each section MUST be a table with one row per item linking to
  its `desc.md`. In *In progress*, *Next*, *Decisions* and *Person steps* the
  row order is the priority and rows are numbered.
- **FR-012**: Every column except the number and the item link MUST be derived
  from the items' metadata by a synchronisation step; people change only an
  item's section and position (or do it through the management skill).
- **FR-013**: Section and status MUST correspond: *In progress* ↔
  `in-progress`; *Next* ↔ `open` or `blocked`, `who` agent or both, type
  neither `decision` nor `person-step`; *Decisions* ↔ type `decision`,
  `open` or `blocked`; *Person steps* ↔ `who` person or type `person-step`,
  `open` or `blocked`; *Inbox* ↔ `new`; *Parked* ↔ `parked`; *Rejected* ↔
  `rejected`.
- **FR-014**: Only the maintainer triages and reorders. Agents MAY add items
  to *Inbox* and MAY update an item's `verified`, `updated` and *Log*; they
  MUST NOT move items between sections or change the order, except for the
  status transitions of an autonomous run (FR-030 – FR-036).

**Consistency check**

- **FR-015**: A check tool MUST be runnable from the command line without the
  assistant and MUST report, per finding, the item and the rule: missing
  `desc.md`; missing or invalid fields and values (FR-004 – FR-008); orphan
  item folders; dangling overview rows; items listed more than once;
  section/status mismatch (FR-013); dangling or cyclic `related` /
  `depends-on`; `in-progress` items whose feature folder does not exist;
  derived columns that differ from the items; slugs violating FR-002;
  duplicate `github#N` sources.
- **FR-016**: The check MUST end with a non-zero exit status when it has
  findings and zero when it has none. It is not part of the product build.
- **FR-017**: A synchronisation step MUST rewrite the derived columns and the
  row numbers of the overview from the items without changing the order or
  the section of any row.

**Management skill `/tandem-backlog`**

- **FR-018**: A project skill `tandem-backlog` MUST offer the operations
  *add*, *import-github*, *list* (with filters by area, type, status, `who`,
  minimum severity), *show*, *triage*, *move*, *update*, *verify*, *decide*,
  *park*, *reject*, *reopen* and *check*, accepting instructions in Czech or
  English, and MUST run the check after every operation that changes the
  backlog.
- **FR-019**: *add* MUST derive a slug from the title, refuse collisions,
  ask for missing mandatory values (or, when run by an agent, fill them and
  mark the item `new`), and place the item in *Inbox*.
- **FR-020**: When a feature implementing an item is closed, the item's
  folder and its overview row MUST be removed; the feature's spec MUST name
  the item it came from. Leftovers MUST become new items, never edits of the
  removed one.
- **FR-021**: *import-github* MUST store the issue's original text in
  `issue.md`, create a `reply.md` placeholder, set source `github#N`, and
  refuse an issue that is already imported.
- **FR-022**: Backlog files MUST be written in English (instructions to the
  skill may be Czech); text MUST be stored as UTF-8 without loss of non-ASCII
  characters.

**Autonomous implementation skill `/tandem-backlog-implement`**

- **FR-030**: A project skill `tandem-backlog-implement` MUST process exactly
  one item per run and then end.
- **FR-031**: Without an argument it MUST take the first eligible item of
  *Next*; with a slug it MUST take that item if eligible. Eligible means:
  status `open`, `who` agent or both, type not `decision` / `person-step`,
  every `depends-on` item no longer in the backlog. Otherwise it MUST report
  why and change nothing.
- **FR-032**: Before creating a feature the run MUST confirm at the current
  commit that the described defect or gap still exists; if it does not, it
  MUST record the finding (verification stamp and log) and end without a
  feature.
- **FR-033**: Starting MUST assign the next free feature number, set the item
  to `in-progress` with that number, log it, and run the Spec Kit flow
  `specify → clarify → plan → tasks → analyze → implement` with the item's
  description, evidence and related items as the input of `specify`. The
  feature branch and number MUST come from the Spec Kit git extension
  (`speckit-git-feature`); the run MUST execute the extension's commit hooks
  after each step as the extension's configuration enables them (commits
  "[Spec Kit] …", treating optional hooks as accepted), and MUST end the
  feature with one commit in the project's style `[NNN] <summary>`.
- **FR-034**: In the clarify step the run MUST answer questions itself and
  record each answer as an explicit assumption in the spec, except questions
  that belong to the maintainer (public claims such as `PRIVACY.md`, the
  plug-in interface, installer behaviour, product decisions); for those it
  MUST stop, set the item `blocked` with the reason, and add a `decision`
  item to *Inbox*.
- **FR-035**: The run MUST follow the project's working rules (running
  fix-log in the feature folder, the unit tests and the encoding check, GUI
  probes on the hidden desktop with the registry backed up and restored, an
  independent refute-first review) and MUST NOT push or publish.
- **FR-035a**: The run MUST create its feature branch from local `main`. On
  success it MUST fast-forward local `main` to the feature branch; if a
  fast-forward is not possible it MUST stop as in FR-036. On a stop the
  feature branch MUST stay unmerged and the item's status change (`blocked`,
  reason, log line) MUST also be committed to local `main`.
- **FR-036**: The run MUST stop, set the item `blocked` with the reason and
  log it when: the build or tests keep failing, the review rejects the fix
  repeatedly, the work needs a real keyboard, clipboard or other person step
  (recorded as a `person-step` item), or the item proves too large (split
  proposed as *Inbox* items).
- **FR-037**: On success the run MUST close the item per FR-020, add the
  feature's entry to `specs/FEATURE-HISTORY.md`, record leftovers and review
  findings as *Inbox* items, write the feature's `closing-report.md`, and end
  with a summary: outcome, feature number, branch, steps owed to a person,
  new *Inbox* items.
- **FR-038**: Every run, whatever its outcome (feature closed, item blocked,
  defect no longer present, nothing to do), MUST append one line to the run
  journal `backlog/RUNS.md`: date, item slug, outcome, feature number and
  branch (or `-`), number of new *Inbox* items, steps owed to a person. The
  line MUST reach local `main` (with the fast-forward on success, with the
  status commit on a stop, as its own commit otherwise). Exceptions — runs
  that change nothing and report only in their final message: a run refused
  by the lock (FR-039), a run whose preconditions fail (not on `main`, a
  dirty tree, `check` not clean), and a run given an ineligible slug.
- **FR-039**: Only one run MAY be active at a time. A run MUST create an
  unversioned lock under `.git/` holding its start time, item slug and branch
  before it changes anything, and MUST remove it at its end, whatever the
  outcome. A run that finds a lock MUST end with "another run in progress"
  (naming the lock's item, branch and age) without changing the repository —
  not even the run journal, because a commit to `main` would break the active
  run's fast-forward. A lock older than 24 hours MUST be reported as stale; it
  is released only by the maintainer.

**Migration and project integration**

- **FR-040**: Every open entry of `specs/NEXT-WORK.md` (*Before 0.1.10*,
  sections A, B, C, D, *Recorded, deliberately not on the list*) and of the
  five `specs/*/REMAINING-WORK.md` files MUST be migrated to an item, merged
  into an item, moved to the release checklist, or recorded as already done;
  a migration ledger in the feature folder MUST list each entry and its
  destination.
- **FR-041**: Small related leftovers MUST be grouped so that one item is one
  feature's worth of work.
- **FR-042**: "Decided — not to do" entries MUST become `rejected` items with
  their reasons and decision dates; recorded maintainer decisions MUST appear
  in the items' logs.
- **FR-043**: The release procedure (version bump, tag, GitHub release with
  the installer attached, winget, the checks owed at a release) MUST be kept
  as a release checklist document inside `backlog/`, outside the item list.
- **FR-044**: After migration `specs/NEXT-WORK.md` MUST be deleted, and each
  `specs/*/REMAINING-WORK.md` MUST keep its content and gain a one-line note at
  its top stating that its open items moved to `backlog/` on the migration
  date. `CLAUDE.md` (*Where things are*, the standing rule on
  serious defects found on the way, *Status*), `specs/FEATURE-HISTORY.md`
  and `architecture/12-project-reference.md` MUST direct planned work and new
  findings to the backlog.
- **FR-045**: The deletion of the former `issues/` and `features/` folders
  MUST be committed as part of this feature.

### Key Entities

- **Backlog item**: one unit of planned work — a slug (identity), metadata
  (FR-004/005), a description with sections, optional issue text, reply draft
  and evidence. Lives from creation until its feature closes or it is
  rejected.
- **Overview**: the ordered list of all items by section; holds the priority
  (order) and the placement (section); everything else in it is derived.
- **Section**: a named group of the overview bound to a set of statuses
  (FR-013).
- **Log entry**: a dated line in an item recording a status change, decision
  or verification.
- **Feature**: a `specs/NNN-*` folder created from an item by an autonomous
  run or by the maintainer; refers back to its item's slug.
- **Migration ledger**: the record mapping each old open entry to its
  destination.
- **Release checklist**: the repeated release procedure, kept beside the
  backlog but not as items.
- **Run journal**: `backlog/RUNS.md`, one line per autonomous run, newest
  last; the place where the maintainer sees what runs did since the last
  look.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The maintainer records a new item with all mandatory fields in
  one instruction and under 2 minutes.
- **SC-002**: The next item to work on is identifiable in under 30 seconds:
  it is the first row of *Next*; the overview contains no done or
  struck-through items.
- **SC-003**: 100 % of the open entries of the old sources are accounted for
  in the migration ledger; 0 are lost.
- **SC-004**: The consistency check detects 100 % of a seeded set of defects
  (one per rule of FR-015) and reports 0 findings on the migrated backlog.
- **SC-005**: Backlog management operations create or modify 0 files under
  `specs/`.
- **SC-006**: Every autonomous run ends in a recorded outcome (feature closed,
  item blocked with reason, defect no longer present, or "nothing to do");
  0 runs end without a line in the run journal, except runs refused by the
  lock, which change nothing and report in their final message.
- **SC-007**: After migration, 0 project instructions direct planned work or
  new findings to `specs/NEXT-WORK.md` or to `REMAINING-WORK.md` files.
- **SC-008**: Reordering *Next* or moving an item between sections never
  breaks a reference: 0 dangling references after any operation.

## Assumptions

Defaults chosen from the conversation; the open points reserved for the
clarify phase are settled in *Clarifications*.

- The backlog is a tool for the maintainer and agents in this repository; it
  has no user-visible effect on the product, so it needs no `CHANGELOG.md`
  entry and no `PRIVACY.md` change.
- The check tool uses the scripting runtime the build already requires and
  is not wired into `build.cmd` for now.
- Done items are removed, not kept in a *Done* section; git history,
  `FEATURE-HISTORY.md` and the feature's spec keep the record.
- The stale limit of the run lock is 24 hours (a long run with GUI probes
  takes hours, not a day).
- The steps owed to a person are migrated as `person-step` items grouped by
  feature or topic, not one item per row.
- The assistant's own memory pointer to `NEXT-WORK.md` is updated as part of
  this feature (it lives outside the repository).
- GitHub import reads the public issue through GitHub's public interface
  (the GitHub CLI is not installed here — measured in planning, research R6);
  an issue's reply is never posted by the system — posting stays the
  maintainer's step.
