# 344 - Backlog web app: UX and interaction design

Analysis 04 of feature 344 (the localhost web application for steering development
through the backlog). Scope: the maintainer's side - journeys, screens, interactions,
priorities, and a refute-first pass over what the maintainer does today. The backend,
the CLI internals, the loop internals and the tech stack are analysed elsewhere
(01-03); where this design needs something from them, it says so under
*Needs from the backend*.

Sources read (2026-10-30, `main` at f7faf9ae, working tree on `344-backlog-web-app`):
`CLAUDE.md`; `backlog/BACKLOG.md` (all sections and the legend); items of every type
and status (blocked bug with `evidence/`, decision with options, decision from
`github#6` with `issue.md`, person steps with `- [ ]` steps and a draft GitHub
answer, an Inbox item from `review:341`, parked, rejected); `backlog/RUNS.md`;
`backlog/RELEASE.md`; `.claude/skills/tandem-backlog/SKILL.md` + `reference.md`;
`.claude/skills/tandem-backlog-implement/SKILL.md` + the stop-rule table;
`bin/backlog.sh --help`, `bin/backlog-loop.sh --help`, `status` and `status --json`;
`specs/242-backlog-system/contracts/cli.md`; `specs/247-backlog-run-loop/contracts/loop-cli.md`;
`specs/342-backlog-agent-traces/contracts/traces.md`; FEATURE-HISTORY entries 242, 247,
342; `specs/341-ftp-upload-cache-alias/` (closing report, fix-log, tasks);
`tools/release/release.py status`; `git log` of the backlog commits.

---

## 0. How the maintainer works today (the baseline the app must not lose)

### 0.1 The data

- **One overview, one folder per item.** `BACKLOG.md` has seven sections in a fixed
  order. On 2026-10-30: *In progress* 0, *Next* 133, *Decisions* 17, *Person steps*
  78, *Inbox* 3, *Parked* 12, *Rejected* 14 (257 items). **Row order is the priority**;
  every cell except the row's place is derived from the item.
- **An item** is `items/<slug>/desc.md`: a 15-key header (title, type, status,
  severity, area, source, who, created, updated, verified, effort, feature, related,
  depends-on, reason) and fixed body sections that depend on the type: work items
  have *Problem / Evidence / Expected* (+ *Approach*, *Notes*), decisions have
  *Question / Options / Recommendation*, person steps have *Steps* (`- [ ]` lines).
  Every item ends with *Log* (`- YYYY-MM-DD — text`). Optional: `issue.md` (a
  verbatim GitHub issue), `reply.md` (a draft answer, `state: not-sent`),
  `evidence/` (probes, results, audits).
- **The legend is the vocabulary**: the types, statuses, severity bands, 18 areas,
  sources, who, effort. The app reads it; it never hard-codes it.
- **A finished item is deleted**, not marked done. Its record is the git history,
  the `RUNS.md` row (with the feature), `specs/NNN-*/closing-report.md` and the
  FEATURE-HISTORY entry. An item closed by `remove --reason` keeps its reason only
  in dependents' logs and in the commit message.
- **`RUNS.md`** - one row per autonomous run: date, item, outcome (`closed`,
  `blocked`, `not-reproduced`, `split`, `nothing-to-do`), feature, branch, number of
  Inbox items added, what is owed to a person, a note.
- **`.agent-traces/`** - per run: `trace.jsonl` (claude's stream), `stderr.log`,
  `meta.json` (phase, outcome, commits, attempts, limits); `index.jsonl` one line per
  ended run. The loop's live state is in `.git/tandem-backlog-loop/` (`loop.json`,
  `run.json`, `pause`, `stop`) and the run lock in `.git/tandem-backlog-run.lock`.

### 0.2 The actions, and who does them

The maintainer today talks to Claude Code (in Czech) and Claude runs the tool.
What happens, by operation:

| Operation | Today | Mechanical or judgement |
|---|---|---|
| list / show / "what next?" | `/tandem-backlog list`, `show`, `BL next --json` | mechanical |
| add an item | `/tandem-backlog add <text>`: Claude looks for duplicates, reads the code for exact *Evidence* (`file:line` at a commit), decides type / severity band / area by the decision tables, writes the English body | **judgement (AI)** + mechanical `BL new` |
| import GitHub issues | `BL import-github` (one or all labelled `ai backlog`), then Claude judges each (severity from the text, English rewrite) | mechanical + **judgement** |
| triage Inbox | interactive (one question per item, recommendation first) or `auto-triage` (rules A-E of reference.md §4.1, `--dry-run`, `--commit`); the loop runs auto-triage between runs | the placement rules C/D/E and the position rule are **mechanical**; rule A (code not shipped) and rule B (uncertain) and the severity re-check are **judgement** |
| reorder | `BL move --section --position`, or the maintainer reorders rows by hand and runs `BL sync` | mechanical |
| update fields / title / body | `BL set ... --log`, body by the Edit tool + `BL log` | mechanical (text) |
| verify at HEAD | Claude locates the *Evidence* sites at HEAD, runs a short probe, `BL verify --note` | **judgement (AI)** |
| decide | `BL log 'maintainer decision ...'`, then convert to work (rewrite *Problem / Expected*, `set type`, move), or close (`remove --reason 'decided ...'`), or park; dependents handled one by one | the choice is the **maintainer's**; the rewrite is text work |
| park / reject / reopen | `BL move --section parked/rejected --reason '<why>; maintainer YYYY-MM-DD'`; reject first handles dependents | mechanical, reason required |
| block / unblock | `BL block --reason`, `BL unblock --note` | mechanical |
| close (already fixed / obsolete) | verify first, then `BL remove --reason`; a `github#N` item reminds that the issue needs an answer | judgement for the evidence, mechanical remove |
| check | `BL check` (18 rules), fixes by reference.md §6 | mechanical, a few need a decision |
| run one item | `/tandem-backlog-implement [<slug>]` in a Claude session | autonomous |
| run the loop | `bin/backlog-loop.sh start [--auto-triage --max-items --max-blocked --poll --model --until-idle --forget-run]` in a Git Bash window; `pause` / `resume` / `stop` / `status` from another window; Ctrl+C = hard stop | mechanical control |
| after a run | read `RUNS.md`, the closing report, the new Inbox items, the person steps; for a stopped run read its branch's `fix-log.md`; "merge by hand" when step 9 failed | reading + judgement |
| commit backlog changes | Claude commits on `main` with a summary subject (`backlog: close 10 blocked items that were done, obsolete or split; reject one ...`); never pushes | mechanical, the message is a summary |
| release | closing pass (builds, saltests, probes), `/tandem-release x.y.z` on the day, then build + sign + tag + GitHub release + winget (all the maintainer's) | person + skill |
| answer a GitHub issue | a person step with the draft answer; the maintainer posts it | person only |

### 0.3 The hard rules the app inherits

1. **Agents only add to Inbox; the maintainer triages and orders.** In the app, every
   write is the maintainer's own click. An AI job the app starts acts only for the
   operation the maintainer clicked, and anything it *creates* lands in Inbox unless
   the maintainer places it in the same dialog.
2. **No push, no tag, no publish, no GitHub post, no winget.** The app has no button
   for any of them (it may *show* that `main` is ahead of `origin/main` and give a
   command to copy).
3. **No change while a run holds the lock or the loop runs unpaused** (`/tandem-backlog`
   §0.2). During a run the working tree is on the *feature branch*, so the files on
   disk are the branch's view of the backlog.
4. **One changing command at a time** - the tool has no lock of its own; the app must
   serialise its writes and still expect a terminal session to write in between.
5. **Exit 1 has two forms**: `refused:` (nothing written - may retry after a fix) and
   `check after the change found problems:` (written - **never repeat**).
6. **Never put item text on a command line** (backticks run as code, backslashes
   collapse). Header values are one line, no backslash. Body text goes into the file.
7. **The loop needs a clean tree on `main`** for its precheck. Uncommitted backlog
   changes made by the app make the loop wait silently ("precheck failed").
8. **Editing the item that is being run, on `main`, makes the run stop** at step 9
   ("the item changed on main during the run - merge by hand").
9. **The record is English**; the maintainer may type Czech.

---

## 1. User goals and journeys

Numbered J1-J40, grouped. Each line: the goal - the path in the app - today's equivalent.

### A. Orientation

- **J1 Morning check / "what did the loop do last night?"** - Home shows *Since your
  last visit*: runs ended (closed / blocked / not-reproduced / split) with feature
  links, new Inbox items, new person steps and decisions created by runs, loop stops
  that need a person, check findings. Deterministic (RUNS.md + index.jsonl + git log),
  no AI. Today: reading RUNS.md and `git log`.
- **J2 What needs me now** - Home *Attention* list: decisions, Inbox, blocked items in
  *Next* (revisit at every triage), runs stopped for a person (phase `failed` / `lost`,
  `merge by hand`, blocked streak), uncommitted app changes holding the loop, check
  findings, owed notes from RUNS.md *Person steps* column.
- **J3 What will the loop take next?** - the *Next* list marks the first eligible row
  ("next up") and shows why rows above it are skipped (`status blocked`, `depends-on`
  open) - `BL next --json`.
- **J4 Browse and read the backlog** - sections as tabs or one long grouped table;
  item detail with rendered Markdown.
- **J5 Find something** - quick filter chips + a filter query language + full-text
  search over all item texts (title, body, `issue.md`, evidence names).
- **J6 Ask a free question** - first answered by filters / search ("encoding bugs,
  agent, effort S" is a filter); for real questions an optional read-only Q&A via the
  local claude CLI that answers with item links and the filter it used (J33).

### B. Triage and ordering

- **J7 Triage the Inbox** - a focused triage screen: one item at a time, the app's
  recommendation (target section + position + severity, computed by rules C/D/E and
  the position rule; rule A/B flagged as "needs a look"), keys for each target,
  reason dialogs for park / reject. Today: `/tandem-backlog triage`.
- **J8 Auto-triage the Inbox with review** - run the AI auto-triage as `--dry-run`,
  see the plan table, tick the rows to apply, apply (P4). Today: `auto-triage
  [--dry-run]`.
- **J9 Reorder *Next*** (and *Decisions*, *Person steps*) by drag and drop, by
  keyboard (Alt+Up/Down, to top, to position), and "move above/below item X".
- **J10 Move between sections** - drag to a section tab or a *Move to...* menu; the
  app knows which sections admit the item (reference.md §5) and offers the fix when
  not ("change type to person-step and move").
- **J11 Revisit blocked items** - a *Blocked* view across sections: reason, the stopped
  run's branch, its fix-log; actions unblock / close / reject / keep. Today the
  maintainer did this in bulk ("close 10 blocked items ...", "unblock five resumable
  items").
- **J12 Bulk changes** - multi-select: move, park, block / unblock, set a field, close
  or reject with one reason (P5).

### C. Recording decisions and person work

- **J13 Decide a decision item** - read *Question*, pick an option card (A / B / C
  parsed from *Options*, the *Recommendation* highlighted), write the decision in one
  sentence, choose the consequence: convert to work (type, who, severity, position;
  rewrite *Problem / Expected* by hand or with AI), answered - close, or later - park;
  then handle each dependent (keep / reject).
- **J14 Do a person step and record the result** - the *Steps* checklist is
  interactive: per step pass / fail / cannot (+ a note); each writes `- [x]` and a log
  line; a failed step offers "record a bug from this" (new item, `related` to the step,
  prefilled); all done offers close with a reason. GitHub-answer steps get *Copy
  answer* and *Open issue on GitHub* (the app never posts).
- **J15 Pick person steps I can do today** - filters by area and saved text filters
  ("real server", "real keyboard", "Mac", "Windows 7") because there is no equipment
  field.

### D. Creating and maintaining items

- **J16 Create an item by hand** - a type-aware form (title with live slug and
  duplicate search, fields with the legend's meanings, body templates per type),
  created in Inbox or placed directly.
- **J17 Create an item from one sentence (AI draft)** - "Describe it" box (Czech or
  English) -> claude drafts title, fields with one-clause reasons, *Problem /
  Evidence / Expected* with `file:line` at HEAD, and lists possible duplicates; the
  maintainer edits the draft and creates it (P4).
- **J18 Import GitHub issues** - list of open issues labelled `ai backlog` with
  would-import / skipped lines, import one or all; each imported item gets "judge with
  AI" (severity from the text, English rewrite) or manual edit (import P3, judging P4).
- **J19 Edit an item** - inline header fields (via `BL set`, with a log reason), title,
  body section by section in a Markdown editor, related / depends-on with slug
  autocomplete.
- **J20 Verify an item at HEAD** - "Verify" starts an AI job that does reference §2.8
  and stamps `verified`; the detail shows "verified 2026-10-23 at ae49a67d - 57 commits
  ago" (P4).
- **J21 Close an item that is already done / obsolete** - close dialog: reason
  (fixed by feature NNN / commit / obsolete), dependents and relations listed, the
  GitHub reminder and an offer to create the "Answer GitHub issue #N" person step.
- **J22 Park / reject / reopen / block / unblock** - one dialog each, reason required
  where the tool requires it, `; maintainer YYYY-MM-DD` appended by the app; reject
  handles dependents first.
- **J23 Fix check findings** - the *Check* page lists `BL check` findings with the
  reference §6 explanation and a one-click fix where it is mechanical (`sync`, the
  orphan's move); others link to the item.
- **J24 Split an item** by hand (P5) - create N parts `related` to it, then close it
  with `split into: <slugs>`.

### E. Running and watching

- **J25 Start the loop** - a start dialog with the loop's options (auto-triage,
  max items, max blocked, model, until idle, forget a failed run); the app commits its
  pending backlog changes first (with confirmation).
- **J26 Pause / resume / stop** - always visible in the top bar while a loop exists;
  shows "pause requested - the running item finishes first".
- **J27 Run one chosen item now** - from an item: eligibility check (`BL next --slug`),
  then run it (needs the backend to start a single run or `--only <slug>`, section 6).
- **J28 Watch the live run** - phase timeline, elapsed time per phase, tasks progress
  from `tasks.md`, the current tool call, the last messages, subagents (reviewers),
  commits on the branch, attempts (usage limit / error / stall continuations), the
  usage gauges.
- **J29 Be notified** - when a run ends (outcome), when the loop stops for a person,
  when it starts waiting for a usage limit, when it waits on a dirty tree, when a run
  adds a decision or a person step.
- **J30 Recover from a stopped loop** - the *todo* line of `status` turned into
  actions: forget the run and start, open the trace, release a stale lock
  (dangerous, confirm), the merge-by-hand instructions with commands to copy.
- **J31 Review past runs** - run history (RUNS.md joined with `index.jsonl`): outcome,
  duration, attempts, limits, model, feature, commits, the transcript viewer, triage
  runs too.

### F. Features, history, release

- **J32 See which feature closed an item / read its closing report** - an item that no
  longer exists is found in the *Closed* archive (removals in git + RUNS rows); the
  feature page renders `closing-report.md`, `fix-log.md`, `spec.md`, `tasks.md`
  progress, probe result files, the commits, the run trace, the items it created.
- **J33 Ask in natural language** (P4) - read-only claude Q&A over the backlog, RUNS,
  traces and specs; answers cite slugs / features as links; shows the filter it used
  when the question was a filter.
- **J34 Item history** - the timeline of the item: its *Log* lines merged with the
  commits that changed `desc.md` (field changes shown as "severity 4 -> 6"), its runs
  and stopped branches.
- **J35 Release readiness at a glance** - unreleased changelog entries, features since
  the last tag, gating person steps from RELEASE.md, open decisions, `release.py
  status` refusals and warnings, `main` vs `origin/main`, the release command to copy.
  Read-only (P5).
- **J36 Check the state of the repository** - branch, clean or not (which files),
  ahead of origin, lock holder, traces size - the status bar.

### G. Working style

- **J37 Keyboard-only operation** - every journey above without a mouse; a command
  palette (Ctrl+K) for navigation, actions on the selected item, and filters.
- **J38 Saved views** - named filters ("small encoding bugs", "person: real server",
  "blocked in Next"), pinned in the sidebar, addressable by URL.
- **J39 Theme and density** - system / light / dark, compact / comfortable,
  remembered.
- **J40 Narrow window** - the app beside a terminal or an editor: one pane, the
  same functions.

---

## 2. Information architecture

### 2.1 Navigation

Left sidebar (collapsible to icons), top bar, main area, optional detail pane.

```text
Sidebar                         Top bar (always)
-------------------------       -------------------------------------------------------------
 Home                    g h    [Loop: running - implement 31m - item #2]  [Pause][Stop]
 Live run            *   g l    usage 5h 42% | 7d 18%   main clean  +3 ahead   [2 uncommitted]
 Backlog                 g b    [Ctrl+K  Search or command...]                 [theme] [?]
   Next          133     g n
   Decisions      17     g d
   Person steps   78     g p
   Inbox           3  !  g i
   Parked         12
   Rejected       14
   Blocked         1     (view)
   Closed          -     (archive)
 Runs                    g r
 Features                g f
 Release                 g e
 Check           0       g c
 Ask                     g a
 -- Saved views --
   Small encoding bugs
   Person: real server
```

- The **top bar** carries the loop's state everywhere (the most time-critical
  information), the usage gauges, the repository state, and the change tray counter.
- **Counts** in the sidebar update live; Inbox shows a dot when it has items not seen
  since the last visit.

### 2.2 URL-addressable state

| URL | State |
|---|---|
| `/` | Home |
| `/live` | the current run (or the loop's state when none) |
| `/backlog/next?q=area:encoding+who:agent&sort=position&sel=<slug>` | a section, a filter, the selected row (detail pane open) |
| `/backlog/all?q=...` | every section, grouped |
| `/items/<slug>` | item detail, full page; `#log`, `#files`, `#history`, `#runs` tabs |
| `/items/<slug>/edit` | the edit form |
| `/triage` , `/triage/<slug>` | Inbox triage, at an item |
| `/decisions/<slug>` | the decision screen (also reachable as `/items/<slug>`) |
| `/new?type=bug&from=<slug>` | the new-item form (prefilled: related to an item, from a failed step) |
| `/runs?outcome=blocked&from=2026-10-20` | run history |
| `/runs/<trace-dir>` | one run (meta, attempts, transcript, commits) |
| `/features/<NNN>` , `/features/<NNN>/<file>` | feature page, a file of `specs/NNN-*/` |
| `/closed?q=<text>` | archive of removed items |
| `/release` | release readiness |
| `/check` | check findings |
| `/ask?q=<question>` | Q&A |
| `/views/<name>` | a saved view (a named URL) |

Every filter, sort, tab and selection is in the URL, so the back button, bookmarks and
"copy link" work. The detail pane open on a row is `?sel=<slug>`; the full page is
`/items/<slug>`.

### 2.3 Saved views

A saved view = name + URL + optional pin + optional "notify when non-empty" (P5).
Stored by the app outside the tracked tree (in `.git/tandem-backlog-app/` or the
user's profile - backend's choice), never in `backlog/`. Built-in views (not
deletable): *Next up*, *Blocked*, *Agent-doable small*, *Severity 7+*, *GitHub
items*, *Not verified*, *Created by runs this week*.

### 2.4 The filter language

One text box, chips for the common keys, the same syntax in the URL and the palette:

```text
type:bug,improvement   sev>=5   sev:4..6   area:encoding   who:agent   effort:S,M
status:blocked   section:next   source:review:*   source:github   is:github
has:evidence   has:reply   verified:none   verified<2026-10-01   created>=2026-10-20
depends:open   related:<slug>   needs:<slug>   feature:341
"code page"   -"not reproduced"   (free words = full-text over title + body + issue.md)
```

Unknown keys are shown as an error under the box, never silently ignored. The values
come from the legend (autocomplete). Full-text search highlights the hit in the row
(a snippet line under the title) and in the detail.

---

## 3. Screens (wireframes)

The wireframes use 100-120 columns; the real UI is denser and uses icons where the
wireframe writes words.

### 3.1 Home (dashboard)

```text
+--------------------------------------------------------------------------------------------------+
| Home                                                                    Thu 30 Oct 2026 09:12    |
+-----------------------------------------------+--------------------------------------------------+
| NEEDS YOU                                  7   | LOOP                                              |
|  ! Run stopped for a person: 341 failed         |  running since 01:02 (pid 8812) - auto-triage on   |
|      "the reviewer was killed 3x"  [Open] [Fix] |  item  iso-plug-in-an-hfs-folder-whose-id-...     |
|  ! 3 uncommitted backlog changes hold the loop  |  phase implement  31m   attempt 1   tasks 9/14     |
|      [Review & commit]                          |  done today: closed 3, blocked 1, not-repr. 0      |
|  * Inbox 3 new (2 since your last visit) [Triage]|  usage 5h [####------] 42% resets 11:00            |
|  * Decisions 17  (2 created by runs)   [Open]   |        7d [##--------] 18% resets Mon             |
|  * Blocked in Next 1                   [Review] |  [Pause] [Stop] [Live view]                        |
|  * Person steps 78  (3 new)            [Open]   +--------------------------------------------------+
|  * Check: 0 findings                            | NEXT UP (the loop takes the first eligible)        |
+-----------------------------------------------+   1  Drive Information turns a volume ...  skipped: blocked
| SINCE YOUR LAST VISIT (Wed 29 Oct 22:40)        | > 2  ISO: an HFS+ folder whose ID is lower ...  S5 M
|  01:02-01:49  closed      345 ISO NRG CUEX ...  |   3  ISO: an NRG CUEX chunk under 16 bytes ...  S5 S
|                 +2 Inbox, person step: check... |   4  ISO: a track of a CCD or NRG image ...     S5 S
|  01:50-03:10  blocked     346 ... stop rule 3   |   5  ISO: NRG ETNF / ETN2 ...                   S5 M
|  03:11-03:12  auto-triage 2 placed, 0 parked    |   [Open Next]                                      |
|  03:12-...    running     implement (see Live)  +--------------------------------------------------+
|  [All runs]                                     | RELEASE  0.2.0 published 25 Oct (v0.2.0)          |
|                                                 |  unreleased changelog entries: 4   features: 3     |
|                                                 |  gating person steps: none   [Release readiness]   |
+-----------------------------------------------+--------------------------------------------------+
```

- *Needs you* is ordered by urgency: loop stopped > uncommitted changes holding the
  loop > check findings > Inbox > decisions > blocked > person steps.
- *Since your last visit* uses a "last seen" timestamp kept by the app; "mark all
  seen" resets it.

### 3.2 Backlog (table, the main working screen)

```text
+--------------------------------------------------------------------------------------------------------+
| Backlog  [Next 133] [Decisions 17] [Person 78] [Inbox 3] [Parked 12] [Rejected 14] [All]   Last triaged 24 Oct |
| Filter: [area:encoding who:agent  "code page"                          ] [x]  Saved: [Small encoding v] [Save] |
| chips: type v  sev v  area v  who v  effort v  status v  source v        23 of 133   density [compact v]  |
+----+-----+--------------------------------------------------------------+-----+----------+-----+---+------+
|  # |  =  | Item                                                         | Sev | Area     | Who | E | Stat |
+----+-----+--------------------------------------------------------------+-----+----------+-----+---+------+
|  1 | ::  | Drive Information turns a volume label outside the code page | 5   | encoding | both| ? | BLKD |
|    |     |   not reproduced at ae49a67d: the premise is wrong ...       |     |          |     |   |      |
|> 2 | ::  | ISO plug-in: an HFS+ folder whose ID is lower than its parent| 5   | archives | agt | M | next |
|  3 | ::  | ISO plug-in: an NRG CUEX chunk under 16 bytes makes a huge...| 5   | archives | agt | S |      |
| 10 | ::  | Read the 78 findings of check_encoding.py --plugins one by...| 4   | encoding | agt | L |      |
|    |     |   ... "code page" ... (search hit)                           |     |          |     |   |      |
| .. |     |                                                              |     |          |     |   |      |
+----+-----+--------------------------------------------------------------+-----+----------+-----+---+------+
| Selected: 1   [Move to... m] [Block b] [Park] [Reject] [Run now] [Open o]           Drag :: to reorder    |
+--------------------------------------------------------------------------------------------------------+
```

- Columns follow the section (`BACKLOG.md`'s own columns) plus optional ones (source,
  created, verified, related count); the user chooses columns per section.
- **Reordering while filtered**: dragging in a filtered list moves the item *above the
  row it is dropped on* in the full order (the positions shown are the full-order
  positions; the drop indicator says "above #10"). Sorting by any column other than
  `#` disables dragging (the handle greys out with the tooltip "sort by # to
  reorder").
- **Next-up marker** (`>` / a badge) on the first eligible row; skipped rows above it
  carry the skip reason.
- **Severity** is a number in a band-coloured badge (9-10, 7-8, 4-6, 1-3, 0) - the
  number is always printed, so colour is never the only signal.
- With the detail pane open (wide window), the table narrows to # / Item / Sev /
  Status.

### 3.3 Item detail

```text
+------------------------------------------------------------------------------------------------------+
| < Next #2                     ISO plug-in: an HFS+ folder whose ID is lower than its parent lists ...  |
| [bug] [sev 5 - a function does not work] [archives] [agent] [effort M] [open] [source review:332]     |
| created 2026-10-23  updated 2026-10-24  verified -  feature -     slug iso-plug-in-an-hfs-folder-... [copy] |
| Actions: [Run now] [Verify (AI)] [Move...] [Block] [Park] [Reject] [Close...] [Edit] [...]           |
+------------------------------------------------------------------------------------------------------+
| [Description] [Log 3] [Files 2] [Relations 1] [History] [Runs 0]                                      |
+----------------------------------------------------------------+-------------------------------------+
| ## Problem                                          [edit]      | Relations                           |
| An HFS+ folder whose catalog ID is lower than ...               |  related                            |
|                                                                 |   iso-plug-in-hfs-hard-links ... #29 |
| ## Evidence                                         [edit]      |  depends on: -                      |
| - `src/plugins/uniso/hfs.cpp` `CHFS::BuildTree` ...             |  needed by: -   (BL list --needs)   |
|   (code spans, links to files open in the editor)               | Files                               |
| ## Expected                                         [edit]      |  evidence/hfs_probe.ps1   (view)    |
| ...                                                             |  issue.md - github #12 (view, open) |
| ## Log                                                          |  reply.md - not-sent    (view, copy) |
| - 2026-10-23 - created (source review:332)                      | Runs of this item                   |
| - 2026-10-23 - moved to Next position 4                         |  -                                  |
+----------------------------------------------------------------+-------------------------------------+
```

- **Markdown** rendered with GitHub-flavoured tables, code spans, fenced code with
  highlighting, task lists (interactive only in *Steps*), and links: a slug in text
  links to the item; `specs/NNN-...` paths link to the feature page; `file:line`
  paths link to "open in editor" (a `vscode://file/...` link, configurable) and to a
  read-only file viewer at HEAD.
- **History tab** (J34): one timeline merging *Log* lines and the commits touching
  `desc.md` (header diffs shown as field changes), plus RUNS rows and the stopped-run
  branches named in *Log* / *reason* (each with "read its fix-log" - `git show
  <branch>:specs/<branch>/fix-log.md`).
- **The type decides the action bar**: decisions get *Decide...*, person steps get
  *Record result...*, Inbox items get *Triage...*, parked / rejected get *Reopen...*,
  an in-progress item gets *Live view* and nothing that writes.

### 3.4 Decision screen

```text
+------------------------------------------------------------------------------------------------------+
| Decision 2 of 17   Keep Video CD images after a whole unpack until their video extracts whole?   sev 7 |
+------------------------------------------------------------------------------------------------------+
| Question                                                                                             |
|   Until Video CD video files extract whole, should a whole unpack ... keep the image, or delete it?  |
| Options                                                                                              |
|  ( ) A - keep as now.  Real Video CDs unpack whole and are deleted; ...                              |
|  (o) B - fail closed until the fix.  Every Form 2 stream track marks the listing ...    RECOMMENDED* |
|  ( ) C - fix the cut first (the related item) and leave this decision unneeded.                      |
|  ( ) Other: [                                                     ]                                  |
| Recommendation: C if it can be scheduled next; otherwise B - ...                                     |
| Related: iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may (Next #6)  [open]                     |
+------------------------------------------------------------------------------------------------------+
| Your decision (one sentence, English):                                                               |
| [B until the Form 2 fix lands; then the fix removes it                                     ]         |
| Consequence:  (o) Convert to work -> type [bug v] who [agent v] sev [7] -> Next at [#3 (sev rule) v]  |
|               ( ) Answered - nothing to change / will not be done (closes the item)                   |
|               ( ) Later - park, because [                                     ]                       |
|   Converted text:  [Rewrite Problem/Expected myself]  [Draft the rewrite with AI]                    |
| Dependents (BL list --needs): none                                                                   |
|                                          [Cancel]   [Record decision  Ctrl+Enter]                    |
+------------------------------------------------------------------------------------------------------+
```

- The option cards are parsed from the *Options* list (`- **A — ...**` / `- A - ...`);
  if parsing fails, the section is shown as text and only *Other* is offered.
- "Record decision" writes the log line first (`maintainer decision YYYY-MM-DD: ...`),
  then the consequence. For *Convert to work*, the item keeps *Question / Options /
  Recommendation* as the record; the app opens the editor on *Problem / Expected*
  before the move when they still describe the question (a convert without rewritten
  text is allowed but warned).
- Dependents get one row each: keep / reject (reject opens the reject dialog).

### 3.5 Person step screen

```text
+------------------------------------------------------------------------------------------------------+
| Person step 15 of 78   Backlog loop: Ctrl+C in Git Bash and the first real usage limit     tooling   |
+------------------------------------------------------------------------------------------------------+
| Problem (collapsed)  Evidence (collapsed)  Expected: Ctrl+C in the loop window behaves as ...          |
| Steps                                                                                                |
|  [x] 1 Git Bash: start while nothing is eligible ... press Ctrl+C -> stopped (Ctrl+C) ...   PASS 29 Oct |
|  [ ] 2 Git Bash, while an item runs: press Ctrl+C. Note which of the two happened ...                |
|        Result: (o) pass  ( ) fail  ( ) cannot now     Note: [(b) silent return; status running  ]    |
|  [ ] 3 The first time a run meets a usage limit ...                                                  |
|                                                    [Save step result]  [Record a bug from this...]   |
| Log                                                                                                  |
|  - 2026-10-29 - step 1 pass: "stopped (Ctrl+C) - no item of this loop was running"                   |
+------------------------------------------------------------------------------------------------------+
| [Copy answer] [Open issue #9 on GitHub]   (only for "Answer GitHub issue" steps)                     |
| [Close: all steps done...]  [Block: waits for...]  [Park]                                            |
+------------------------------------------------------------------------------------------------------+
```

- A step result writes `- [x]` (pass) or keeps `- [ ]` (fail / cannot) and appends a log
  line `step N <pass|fail|cannot>: <note>`; nothing is posted anywhere.
- *Record a bug from this* opens the new-item form with `related` = this step,
  source `manual` (or `probe:NNN` when the step names a feature), *Problem* prefilled
  with the step text and the note.
- *Close* is offered when every step is ticked; the reason is prefilled `done
  YYYY-MM-DD: <the step notes>; maintainer`.

### 3.6 Inbox triage

```text
+------------------------------------------------------------------------------------------------------+
| Triage Inbox   item 1 of 3 (oldest first)                          [Auto-triage plan (AI)]  [Exit]   |
+-------------------------------+----------------------------------------------------------------------+
| Inbox                         | FTP: an upload as another user or on another port of one server ...    |
| > ftp-upload-cache-other-...  | bug | sev 7 (data loss, narrow) | ftp | source review:341 | who agent | S |
|   ftp-opened-file-lock-...    | The FTP plug-in keeps a lock ... (first two sentences of Problem)       |
|   ftp-panel-refresh-misses... | [Read all]                                                            |
|                               +----------------------------------------------------------------------+
|                               | Recommended:  Next at #11 (first row with lower severity than 7)       |
|                               |   rule E: who agent, not a decision or person step                     |
|                               |   ! rule A/B not checked by the app (code sites)  [Check with AI]      |
|                               | Next, around #11:                                                      |
|                               |   10 Read the 78 findings of check_encoding.py ...          sev 4      |
|                               |   -> here                                                              |
|                               |   11 A path typed in another case into an archive ...        sev 4      |
|                               | Severity: [6] [7*] [8]     band 7-8: data loss in a narrow scenario     |
|                               +----------------------------------------------------------------------+
|                               | [N] Next at #11   [D] Decisions   [P] Person steps   [K] Park...        |
|                               | [X] Reject...   [L] Leave in Inbox   [S] Skip   [E] Edit fields          |
+-------------------------------+----------------------------------------------------------------------+
```

- The recommendation is computed by the app from the legend and reference.md §4.1:
  rule C (decision), D (person step / who person), E (otherwise), and the position
  rule (first row of lower severity, blocked rows count, after an item it
  depends on). Rule B is partly mechanical (a `(to be written)` placeholder, *Notes*
  / *Log* saying "possibly fixed by" / "may duplicate") - flagged. Rule A (code not
  shipped) needs reading the code - the app only shows a warning when *Evidence*
  names a path under a plug-in that `plugins.cfg` has `off`, and offers *Check with
  AI*.
- A placement that does not fit the item's type / who (e.g. *Person steps* for a
  `bug / agent`) asks for the type / who change in the same dialog, and then for the
  *Steps* text when the tool adds placeholder sections.
- The position is editable before applying (number field or "drag the arrow").
- After the last item: a summary table `Item -> Section, Position, Severity` (the
  skill's report) and "commit these changes" in the change tray.

### 3.7 New item

```text
+------------------------------------------------------------------------------------------------------+
| New item                                                         [Describe in one sentence (AI)]     |
+------------------------------------------------------------------------------------------------------+
| Title [FTP: two operations under two names of one server can open one file       ] 78/80             |
|   slug: ftp-two-operations-under-two-names-of-one-server-can-open (free)                             |
|   Similar: ftp-opened-file-lock-two-names... (Inbox) | ftp-server-path-compare... (Next #14)          |
|            rejected: ftp-user-address-path-not-widened - "feature 116 ..."  [open]                   |
| Type [bug v]  Severity [6]  band 4-6: a function does not work; a workaround exists                  |
| Area [ftp v]  (the FTP plug-in)      Who [agent v]   Effort [S v]   Source [review:341 v]            |
| Related [ftp-server-path-compare-code-page-fold x] [+]    Depends on [+]                             |
+------------------------------------------------------------------------------------------------------+
| ## Problem     [write | preview]                                                                     |
| [                                                                                         ]          |
| ## Evidence    (file:line at a commit; "not verified" goes to Notes)                                  |
| ## Expected                                                                                          |
| ## Approach (optional)   ## Notes (optional)                                                         |
+------------------------------------------------------------------------------------------------------+
| Place: (o) Inbox  ( ) Next at [#..]  ( ) Decisions  ( ) Person steps      [Cancel] [Create Ctrl+Enter] |
+------------------------------------------------------------------------------------------------------+
```

- The body sections switch with the type (decision: *Question / Options /
  Recommendation*; person step: *Steps* as a checklist editor with one row per check).
- Validation mirrors the tool: title <= 80 characters, no trailing period, no
  backslash, one line; header values one line and no backslash; every placeholder
  written. Body text may contain backslashes and backticks - the app writes it into
  the file, never onto a command line.
- English is expected; a Czech title or body shows a hint "the backlog is English" and
  (P4) a *Translate* button.
- **AI draft** (P4): the one-sentence box (Czech or English) starts a draft job; the
  form fills in as the draft arrives, each decided field showing its one-clause reason
  ("Severity 6: band 4-6 because ..."); the *Similar* list comes from the job's
  duplicate search too. Nothing is created until *Create*.

### 3.8 Live run

```text
+------------------------------------------------------------------------------------------------------+
| LIVE  * running   ISO plug-in: an HFS+ folder whose ID is lower than its parent ...   Next #2  sev 5   |
| feature 345  branch 345-uniso-hfs-folder-order  session 1f3a..  model opus  attempt 1 (start)          |
| started 01:02  elapsed 47:12      loop: running, auto-triage, max-blocked 3     [Pause] [Stop] [...]   |
+------------------------------------------------------------------------------------------------------+
| measure  specify  clarify  plan  tasks  analyze  IMPLEMENT  review  close  merge                       |
|   3m  -   2m   -   1m  -  4m  -  2m  -   3m   -   31m...  -   o    -   o   -   o                         |
+---------------------------------+--------------------------------------------------------------------+
| Tasks  9 / 14   [#######....]   | Now   Bash  .\build.cmd                         running 1m 12s     |
|  [X] T001 fix-log: measurement  | Subagents  review-1 (general-purpose)          not started        |
|  [X] T006 ...                   +--------------------------------------------------------------------+
|  [ ] T010 encoding guard        | Activity                                         [Follow] [Filter]  |
|  [ ] T011 build, saltests       |  01:46  assistant  The probe shows HFS-ORDER FAIL before the change |
| Commits on the branch (5)       |  01:47  Edit       src/plugins/uniso/hfs.cpp (+18 -4)               |
|  01:09 [345] start: backlog ... |  01:48  Bash       python tools/check_encoding.py --strict  -> 0    |
|  01:15 [Spec Kit] Add spec...   |  01:49  Bash       .\build.cmd ...                                   |
|  01:31 [345] plan               |  [Full transcript]  [stderr]  [fix-log.md]  [spec.md]               |
| Inbox items added: 0            |                                                                    |
| Owed to a person: -             |                                                                    |
+---------------------------------+--------------------------------------------------------------------+
| usage 5h 42% (resets 11:00)  7d 18% (resets Mon)   limits this run 0  errors 0  stalls 0  idles 0     |
+------------------------------------------------------------------------------------------------------+
```

- **Phases**: the requested eight (specify, clarify, plan, tasks, analyze, implement,
  review, close) plus **measure** (step 3, before any branch - a run can end there as
  `not-reproduced`, `blocked`, `split`) and **merge** (step 9, the fast-forward or the
  merge of `main`). Derived from the trace (Skill calls `speckit-*`, the review Agent
  call) and the commit subjects (`[NNN] start`, `[Spec Kit] Add ...`, `[NNN] review
  N`, the final `[NNN] <change>`, `[NNN] merge main`). A phase is *done*, *current*,
  *pending* or *skipped*; a run that ends early shows its end marker on the phase
  where it stopped (`blocked at analyze`, `not reproduced at measure`).
- **States of the page** (one banner each):
  - *Running* (above).
  - *Waiting for a usage limit* - a countdown to `resets_at + 2 min`, "claude waits
    in-process" vs "the loop waits", the attempt count (limit n of 10).
  - *Backoff after an error* - countdown, error n of 6.
  - *Auto-triage running* - its activity and, when done, its result line.
  - *Idle* - "nothing eligible in Next" + why (all blocked / depends-on) + the
    *Next* top 3.
  - *Waiting: precheck failed* - which check (lock held by another item, not on
    `main`, tree not clean - the files listed, `check` findings) + the action that
    fixes it (commit the app's changes, open Check).
  - *Paused* - [Resume]; *Pause requested* - "the running item finishes first".
  - *Stopped for a person* (phase `failed` / `lost`, blocked streak, dirty tree after a
    triage) - the `todo` text and the recovery actions (J30).
  - *No loop* - the last run's summary, [Start loop...].
- **Activity** shows assistant text (first lines), tool calls as one line each (tool,
  a short argument, result size or exit), subagent start / end, task notifications,
  wakeups. *Follow* keeps it scrolled to the end; scrolling up stops following.
- **Full transcript** is the run page (3.9) at this run.

### 3.9 Run history and one run

```text
+------------------------------------------------------------------------------------------------------+
| Runs   outcome [all v]  kind [items+triage v]  from [2026-10-20]  q [         ]       183 runs        |
+------------------+-------------------------------------------+--------------+------+-------+--------+
| Ended            | Item                                      | Outcome      | Feat | Dur   | Att.   |
+------------------+-------------------------------------------+--------------+------+-------+--------+
| 24 Oct 15:46     | ftp-an-upload-to-a-server-named-another...| closed (*)   | 341  | 2h56m | 4      |
|                  |   run failed on killed reviewers, finished by hand                         |
| 24 Oct 12:49     | iso-plug-in-an-nrg-session-count-above... | closed       | 340  | 33m   | 1      |
| 24 Oct 12:48     | auto-triage                               | 2 placed     |  -   | 2m    | 1      |
| 20 Oct 06:08     | check-encoding-plugin-findings            | blocked      | 255  | 54m   | 1      |
|                  |   stop rule 3: review 2 MUST - ...       Inbox +11                         |
+------------------+-------------------------------------------+--------------+------+-------+--------+
| Totals for the filter: closed 61, blocked 9, not-reproduced 6, split 3 | median 41m | limits 2       |
+------------------------------------------------------------------------------------------------------+
```

One run (`/runs/<dir>`): header (outcome, item - linked even when the item no longer
exists, to the *Closed* archive -, feature, branch, model, harness version), an
attempt timeline (start / continue with the reason, endings, `resets_at`), the
commits, the RUNS row (Inbox count, person text, note), and the transcript viewer:
collapsible turns, tool calls with input and output (long outputs folded), Skill
calls as phase headers, a search box, "jump to the first error". Imported runs (before
342) show "attempts not recorded".

### 3.10 Feature page

`/features/341`: title from `spec.md`, the item it closed (from `closing-report.md`
*Backlog item:* or the RUNS row), outcome, branch, merged into `main` or not; tabs
*Closing report* (default), *Fix log* (with an outline of its headings), *Spec*,
*Plan*, *Tasks* (progress), *Probe* (files under `probe/`, result files shown as
text), *Commits* (subjects, stats; a diff viewer is P5), *Run* (link to the trace),
*Created items* (the *New Inbox items* / *Owed to a person* sections linked to their
items, or to the archive when closed since). A feature not on `main` (a stopped run's
branch) is read with `git show <branch>:<path>` and marked "on branch, not merged".

### 3.11 Release readiness (P5, read-only)

- The last release (from RELEASE.md *Current release* and the tag), the proposed next
  version (MINOR when the `[Unreleased]` section exists and carries features, PATCH
  when fixes only - shown as a hint; the maintainer decides).
- The `[Unreleased]` changelog entries rendered, with the feature numbers linked.
- Features since the last tag (`git log v0.2.0..main`, subjects `[NNN] ...`).
- Gating person steps (RELEASE.md *Gating person steps*) and open decisions whose text
  names the release.
- `release.py status <x.y.z> --offline` refusals and warnings, verbatim.
- `main` vs `origin/main` (ahead / behind), the working tree.
- "Prepare the release: run `/tandem-release <x.y.z>` in Claude Code on the release
  day" with a copy button. **No** build / tag / push / publish buttons.

### 3.12 Check page

`BL check` output parsed into rows `rule | slug or file | message`, each with the
reference §6 meaning and fix. Mechanical fixes as buttons: `derived` -> *Sync*;
`orphan` of a `new` item -> *Move to Inbox*; `section` -> *Move to <S>* or *Set
type*. Fixes that need a person (conflict markers, malformed header) show the steps
and the `git diff` of the file. `TOTAL: 0` is a calm green line, not a page.

### 3.13 Ask (P4)

A question box with examples; the answer streams in with item / feature links, a
"how I answered" fold (the filters and files used) and *Open as filter* when the
answer is a list. Read-only by construction (the job has no write tools). Shows the
usage gauges and warns above 80 % of the five-hour limit while the loop runs (the
loop and the app share the subscription).

### 3.14 Command palette (Ctrl+K)

One box, three kinds of results: **go** (screens, sections, saved views, an item by
title / slug / number - `#12` is Next #12, `d3` Decisions #3, `p15` Person #15,
`f341` feature 341), **do** (actions on the selected item or selection - "move to
top", "block...", "park...", "verify", "run now"; global - "pause loop", "commit
changes", "new bug", "toggle theme"), **filter** (typing `area:` switches to the
filter syntax and applies it to the current section). Recent commands first.

---

## 4. Interaction rules

### 4.1 The write gate (when the backlog may be changed)

The app computes one **write state** from `loop.json`, `run.json`, the run lock,
the branch, the tree, and the check result, and shows it in the status bar. Every
write control reads it.

| State | Condition | Writes | What the user sees |
|---|---|---|---|
| **Free** | no loop (or loop `paused` and lock free), lock free, branch `main` | allowed | nothing special |
| **Loop between runs** | loop running, state `idle` / `waiting` (not `triage`), lock free | allowed via *brief pause*: the app requests pause, waits for `state: paused` and `lock: free`, applies the change, commits, resumes | the first write asks once per session: "The loop is waiting. Pause it for this change and resume after?" [Pause, change, resume] [Cancel]; a small "paused by the app" pill while it happens |
| **Run holds the lock** | lock held (a loop run or a manual run) | refused (v1); queued (P5, 4.6) | top banner "Read-only: a run of <item> holds the lock (branch <b>). The files show the branch's view." [Pause loop after this item] [Live view]. Write buttons disabled with that tooltip |
| **Auto-triage running** | loop state `triage` | refused | "Read-only while the loop's auto-triage runs (about 2 minutes)" |
| **Not on main** | branch is not `main` | refused | "The working tree is on <branch>. Backlog changes are made on main." No switch button (checking out is the maintainer's step in the terminal; the app never checks out) |
| **Merge or conflict** | `MERGE_HEAD` exists, or conflict markers in `BACKLOG.md` / a `desc.md` | refused | "A merge is in progress / BACKLOG.md has conflict markers: keep both rows, remove the markers, run sync." + the reference §6 steps |
| **Check not clean** | `BL check` has findings | allowed, but each write is preceded by the findings dialog ("the skill fixes findings first") with the mechanical fixes offered; the user may proceed | Check badge red |
| **Stale lock** | lock older than 24 h, no run | refused | "Stale lock of <item> (<age>). Release it only if no run is alive." [Release lock...] (typed confirmation) |

Read-only operations (list, show, filter, search, history, check, runs, Ask) are
always allowed, also during a run.

### 4.2 How a change is applied

- **One queue.** The server applies writes one at a time; the client shows a spinner on
  the control that started it and greys the same item's other controls.
- **Preconditions.** Every write carries the hash of each file it reads (the item's
  `desc.md`; `BACKLOG.md` for moves). The server compares before calling the tool; a
  difference refuses with *changed underneath* (4.4) - this also catches a terminal
  session that wrote in between.
- **Confirmed by default.** Everything that changes an item waits for the tool's
  answer and then re-reads the files; the UI shows the re-read state, never its own
  guess.
- **Optimistic only for reorders inside a section** (drag and drop, Alt+Up/Down):
  the row moves at once, shows a faint "saving" mark, and snaps back with a toast on a
  refusal. Several quick Alt+Down presses are coalesced into one `move --position`.
- **Refused** (`refused: ...`, nothing written): an inline error at the control (not a
  disappearing toast) with the tool's text verbatim, a plain-language line from the
  reference §6 table, and the fix as a button when there is one (`belongs in
  'Person steps'` -> [Change type to person-step and move]; `needs --reason` -> the
  reason field focused; `already exists` -> [Open the existing item]).
- **Written with check problems** (`check after the change found problems:`): a
  warning (not an error) "The change was written; the check found: ..." - **no retry
  button**; the Check badge turns red and the fixes are offered.
- **Reasons and dates.** Reason fields take the *why*; the app appends `; maintainer
  YYYY-MM-DD` (and `maintainer decision YYYY-MM-DD:` for decisions) - shown in the
  preview line under the field, so the maintainer sees the exact stored text.
- **Every write leaves a log line** with a short why: the edit dialogs have a "why"
  field prefilled from the action ("triage: severity 7").

### 4.3 The change tray, commits and undo

- App changes stay **uncommitted** until the maintainer commits them - like a session
  today. The top bar counter "N uncommitted" opens the tray: the operations in order
  (one line each, the skill's report format: `slug: Inbox -> Next #11`), the files
  touched, and a commit message the app proposes in the repository's style
  (`backlog: triage - 3 placed; park unchm item; Next reordered`), editable.
- **[Commit]** runs `git add backlog` (paths under `backlog/` only) and commits on
  `main` with the session's attribution lines. Other dirty files are listed as "not
  included" and never staged.
- **Automatic commit points** (each asks once, "always" remembered): before *Start
  loop* / *Resume* (a dirty tree makes the loop wait), after a finished triage
  session, and when the tray is older than 30 minutes and the loop is running and
  waiting on a dirty tree.
- **Undo** (Ctrl+Z, and the tray's per-operation undo for the *last* operation only):
  before commit, undo restores the `backlog/` files to the snapshot taken before the
  operation - only if nothing else changed them since (hash check); it leaves no log
  line. After a commit there is no undo; the inverse operations exist (move back,
  unblock, reopen) and leave their log lines. A close (`remove`) is undoable only
  before commit - the confirmation says so.
- The commit message records the reasons of `remove --reason` closes (they live
  nowhere else).

### 4.4 Files changing underneath

The server watches `backlog/`, `.git/HEAD`, the lock, `.git/tandem-backlog-loop/`,
`.agent-traces/index.jsonl` and the trace being followed, and pushes events.

- **Lists** refresh in place; a row that moved flashes once; the selection and the
  scroll position are kept (by slug); a selected item that disappeared shows "this
  item was closed / removed - [open in archive]".
- **Detail being read** refreshes in place with a one-line notice "updated just now
  (by a commit 'backlog: ...' / by an uncommitted change)".
- **Detail being edited** (a section editor open) does not refresh: a banner "This item
  changed on disk while you edit it" with [Show the change] (a diff of the section) /
  [Reload and lose my text] / [Keep editing] - saving then is refused by the hash
  check until the user reloads; the unsaved text is kept in a local draft (4.10) so
  nothing typed is lost.
- **A drag in progress** when the order changes: the drop is applied against the new
  order *by the target's slug* ("above <slug>"), not by number; if the target is gone,
  the drop is cancelled with a notice.
- **Branch switch** (a run checked out its branch, or the maintainer did): a
  non-blocking banner "Now on <branch> - showing the branch's backlog", the write
  state changes, open editors keep their drafts.

### 4.5 Destructive actions and confirmations

| Action | Confirmation |
|---|---|
| close (`remove`) | dialog: the reason (required: fixed by feature / commit / obsolete + evidence), the dependents and relations that will be logged, the files that will be deleted (`evidence/` count), the `github#N` reminder with [Create the "Answer GitHub issue" person step], the verified stamp (a warning when not verified recently: [Verify first (AI)] / [Close anyway]) |
| reject | reason required ("must let a future reader judge whether a new argument is new" - shown as the hint); dependents first, one row each: reject too / drop the dependency |
| park | reason required ("what would bring it back") |
| reopen | the new reason required; the old reason shown above it ("the new reason must answer something the old one did not") |
| hard stop of the loop (P5) | typed confirmation; says the run is killed and the next start continues it, and that an interrupted GUI probe may leave the registry changed |
| release a stale lock | typed confirmation of the item slug; refused while `run.json` names a live claude process |
| forget a failed / lost run (`--forget-run`) | confirmation naming the session and its trace |
| moving the item a run is working on | not offered (the item is in *In progress*; on `main` it is open but the write gate is closed) |

No confirmation for moves, block / unblock, field changes, log lines - they are undoable
before commit.

### 4.6 Changes during a run (P5)

Two possible designs, for the maintainer to choose (section 6):

1. **Queued changes**: while a run holds the lock, operations are recorded as intents
   in the tray ("queued"), applied in order when the write state becomes *Free* or
   *Loop between runs*; each is re-validated then (an item the run closed or blocked
   meanwhile refuses its intent, shown in the tray). Edits to the running item are
   never queued.
2. **A main worktree**: the app writes in a separate worktree of `main` and commits
   there; a run that finishes merges the moved `main` (SKILL.md step 9 supports it,
   with the guard that the run's item must not change). Changes become visible
   immediately; the backend must prove it does not race the loop's precheck.

v1 has neither: the backlog is read-only during a run (the current rule).

### 4.7 Notifications

- **Channels**: in-app toasts and the *Needs you* list (always); the tab title prefix
  and favicon badge (`(2) Tandem backlog`); browser notifications (opt-in, asked once
  with an explanation; localhost is a secure context, so the Notification API works
  on Windows as a system toast). Optional: a Windows toast from the server, so that a
  closed tab still notifies (decision, section 6).
- **Events** (each switchable in Settings):
  - run ended - "closed 345: <change>" / "blocked: <reason>" / "not reproduced" /
    "split into n"; click opens the run page;
  - loop stopped for a person (phase `failed` / `lost`, blocked streak reached, tree
    dirty after triage, `refused-own`) - high priority, stays until opened;
  - loop waits for a usage limit (with the reset time) and resumed after it;
  - loop waiting on a precheck for more than 10 minutes (often the app's own
    uncommitted changes);
  - a run added a decision or a person step; a run added Inbox items;
  - check findings appeared.
- **Quiet hours**: no browser notifications between configurable hours (the loop
  runs at night); the morning digest (J1) carries them.

### 4.8 Empty, loading and error states

- **Empty**: Inbox empty -> "Inbox is empty. Nothing to triage." with the last
  triage date; *In progress* empty -> "No run. The loop would take: <next>"; a filter
  with no hit -> the filter shown with "clear" and the closest saved views; Runs empty ->
  "No runs yet - start the loop".
- **Loading**: skeleton rows for the first load only; later refreshes are silent.
  Long reads (git history of an item, a 50 MB trace) stream with a progress line and
  can be cancelled.
- **Errors**: server unreachable -> a top banner "Connection lost - retrying" with the
  last update time, all writes disabled, reading from the last state continues;
  Python missing / `bin/backlog.sh` failing -> a full-width error with the command and
  its output; a malformed `BACKLOG.md` (the parser fails) -> *degraded mode*: the raw
  file rendered, the check output, writes disabled.
- **AI jobs** (P4): a job card with its state (starting, working - the last tool call,
  done, failed), elapsed time, [Cancel]; a failed job shows its stderr and keeps the
  partial draft.

### 4.9 Keyboard

| Keys | Action |
|---|---|
| Ctrl+K | command palette |
| `/` | focus the filter box |
| `g` then `h l b n d p i r f e c a` | go to Home, Live, Backlog, Next, Decisions, Person steps, Inbox, Runs, Features, Release, Check, Ask |
| `j` / `k`, Up / Down | next / previous row |
| Enter / `o` | open detail pane / full page |
| Esc | close pane, dialog, or clear selection |
| `x`, Shift+`j` / `k` | select row, extend selection |
| Alt+Up / Alt+Down | move the item one row (Next, Decisions, Person steps) |
| Alt+Shift+Up / Down | move to top / bottom |
| `m` | move to... (section and position) |
| `b`, `u` | block..., unblock |
| `e` | edit; `t` triage this item (Inbox) |
| `c` | new item; Shift+`c` new item related to the selected |
| `v` | verify (AI, P4) |
| Ctrl+Enter | submit the dialog |
| Ctrl+Z | undo the last operation (before commit) |
| `?` | the shortcut sheet |
| triage screen: `n d p k x l s` | Next at recommended, Decisions, Person, Park, Reject, Leave, Skip; `1`-`9`/`0`, `+`/`-` severity |

Single-letter keys work only when focus is not in a text field. Every action is also
in the palette and in a visible menu - no key-only function.

### 4.10 Local drafts

Unsaved text in any editor (new item, section edit, decision sentence, reasons) is kept
in the browser's storage per item and field, restored with a notice "restored your
unsaved draft from 09:40", and discarded on save or explicitly. Never sent to the
server until saved.

### 4.11 Theming, density, accessibility, responsiveness

- **Theme**: *System* (default, follows `prefers-color-scheme` live), *Light*, *Dark*;
  the choice is remembered (local storage, read by an inline script before the first
  paint - no flash). Both themes from one set of colour tokens; severity bands,
  statuses and outcomes have a token per theme, all at WCAG AA contrast (4.5:1 text,
  3:1 for badges and focus rings) in both.
- **Density**: *Compact* (default for tables; about 32 rows of *Next* on a 1080p
  screen) and *Comfortable*; per-section column choice remembered.
- **Accessibility**: real table semantics for the lists (sortable headers announced),
  `aria-live="polite"` for the run activity (rate-limited) and toasts, `assertive`
  only for "loop stopped for a person"; drag and drop always has the keyboard
  equivalent and a *Move to...* menu; visible focus everywhere; dialogs trap focus
  and return it; no information by colour alone (severity numbers, status words,
  outcome icons with text); reduced motion respected (no row flash, no pulse).
- **Responsiveness**: desktop first. >= 1280 px: sidebar + table + detail pane.
  900-1279 px: sidebar collapsed to icons, the detail opens as a page or an overlay
  drawer. < 900 px: one column, tables become two-line cards (title; sev, area, who,
  status), drag handles replaced by *Move to...* (touch drag is unreliable), the loop
  controls stay in the top bar as one menu. No horizontal page scroll at any width;
  wide code blocks scroll inside themselves.

---

## 5. Priority slices

Each slice is shippable alone and useful alone; later slices only add.

| Slice | Contents | Rationale |
|---|---|---|
| **P1 - Observe and steer the loop** | read model of `BACKLOG.md` / items / legend / RUNS / traces; Home (*Needs you*, *Since your last visit*, loop card, Next up); Backlog table for every section with chips, the filter language, full-text search, deep links; item detail (rendered Markdown, log, files, relations, runs); loop control (start with options, pause / resume / stop, status, recovery text); Live run (phases, tasks, activity, commits, attempts, usage); Run history and one run with the transcript; notifications (in-app, title badge, browser opt-in); live refresh; theme + density; keyboard navigation; palette for navigation | The loop runs for hours at night; today its state is a terminal window and RUNS.md. Seeing it and stopping it is the first value, and it carries no risk to the data: every write here is the loop's own existing CLI. |
| **P2 - Order and triage** | the write gate; the change tray with commit and pre-commit undo; drag and drop and keyboard reordering; move between sections with the admission rules; Inbox triage screen with the deterministic recommendation; block / unblock / park / reject / reopen with reasons and dependents; field and title edits with a log reason; Check page with mechanical fixes; *Blocked* view | Ordering is the maintainer's daily job and the loop takes exactly what this order says. These operations are mechanical (`BL move / set / block / unblock`), so they need no AI and can be made exact. |
| **P3 - Decide and record** | decision screen (options, consequence, dependents); person-step checklists with results, *record a bug from this*, close when done, GitHub answer copy + open; section-by-section body editing with drafts; new item form (manual); close dialog; GitHub import (mechanical part); item History tab; *Closed* archive; feature pages (closing report, fix-log, spec, tasks, probe files, commits) | Completes "drive development without the terminal" for everything that does not need code reading; the closing reports are what the maintainer reads after every night. |
| **P4 - Assist (local claude CLI)** | AI draft of a new item from one sentence (Czech or English); *Check with AI* in triage and the reviewed auto-triage plan; verify at HEAD; judge an imported GitHub issue; draft the rewrite of a converted decision; translate to English; Ask (read-only Q&A); the AI job card; usage warnings | These are the judgement steps the skills do today; they consume the same subscription as the loop and take minutes, so they come after the deterministic app works and is trusted. |
| **P5 - Oversee and power use** | release readiness (read-only); *main* ahead of origin; run one chosen item now; hard stop and stale-lock release; bulk operations; split by hand; saved views with "notify when non-empty"; queued changes or the main worktree during a run (4.6); commit diff viewer on feature pages; Windows toasts without an open tab | Valuable but rarer (a release every one to three weeks, bulk passes after a review of blocked items) or needing backend work and a decision first. |

The user's list put DnD, triage, decisions and person steps among the core journeys;
they are P2 and P3 here only because P1 is the zero-risk foundation everything else
reads from. If the maintainer wants one MVP, **P1 + P2** is it: watch, control,
order, triage.

---

## 6. Refute-first pass: what the design does not cover, and decisions

### 6.1 Things the maintainer does today and where they land

| # | Today | In the design? | Decision / reason |
|---|---|---|---|
| 1 | Reorder rows of `BACKLOG.md` by hand, then `BL sync` | yes - DnD / keys (P2) | replaces it; hand edits in an editor stay possible and are picked up by the watcher |
| 2 | Resolve a git conflict in `BACKLOG.md` (keep both rows) | no - detected, read-only, steps shown | **out of v1**: conflict resolution is git work in the terminal |
| 3 | "Merge by hand" a finished branch whose step 9 failed | instructions + commands to copy | **out of v1** - person's step (or a Claude session). A guided AI job is possible later but merging into `main` is exactly what the stop rule hands to a person |
| 4 | Read a stopped run's branch fix-log, carry its work over | read: yes (item History, feature page via `git show`) | carry-over itself is a run's step (4.6 of the implement skill) |
| 5 | `lock release --force` for a stale lock | yes, P5, typed confirmation | the tool says "the maintainer releases it"; the app makes that the maintainer's explicit click |
| 6 | `--forget-run` after a failed / lost run | yes, in the start dialog (P1) | |
| 7 | Ctrl+C hard stop in the loop window | P5, only for a loop the app started; for a terminal-started loop: "press Ctrl+C in its window" | the app cannot signal a mintty window reliably (247 trap) |
| 8 | Start the loop in a Git Bash window | the app can start it, or attach to one started in a terminal (status files are the truth) | **decision 6.2-4** |
| 9 | `/tandem-backlog-implement <slug>` for one chosen item | P5 "Run now" | needs the backend: a single-run entry point or a loop `--only <slug>`; the "move to top + `--max-items 1`" workaround changes the order and is not proposed |
| 10 | `/tandem-backlog-implement --dry-run` | yes, deterministic: the Next-up marker with skip reasons (`BL next --json`) | the dry run's "would check" line needs AI - not needed |
| 11 | Commit backlog changes with a summary message | yes - change tray (P2) | **decision 6.2-1** |
| 12 | Push `main` | **never** | shows "ahead of origin by n" and the command to copy (P5) |
| 13 | Answer / close a GitHub issue | **never posts** | Copy answer + Open issue (P3); the person step records it was done |
| 14 | `/tandem-release`, build, sign, tag, GitHub release, winget | **never** (no buttons) | readiness is read-only (P5); the skill stays in Claude Code; the publish steps stay the maintainer's |
| 15 | The closing pass before a release (builds, saltests, probes on the hidden desktop) | no | **out** - build and probe tooling, PowerShell and the hidden desktop; the readiness page links to RELEASE.md's list |
| 16 | Person steps themselves (real keyboard, servers, hardware, Mac images, Windows 7) | the app records results only | **person's step** by definition |
| 17 | Registry restore after an interrupted GUI probe ("import tc335_state_after_probes.reg") | shown as an attention line from the RUNS *Person steps* text / the loop's hint | **person's step**; the app never touches the registry |
| 18 | Writing in Czech, records in English | form hint + AI translate / draft (P4) | the UI language is **decision 6.2-7** |
| 19 | Amending the skills, the loop, CLAUDE.md, FEATURE-HISTORY, the constitution | no | **out** - development work in Claude Code |
| 20 | Adding a value to the legend (a new area) | no - the app reads the legend dynamically | **out of v1**; an edit of `BACKLOG.md`'s legend by hand still works |
| 21 | Bulk passes ("close 10 blocked items", "unblock five") | P5 bulk operations; meanwhile the *Blocked* view (P2) makes the one-by-one pass fast | |
| 22 | Split an item by hand | P5 | runs split today; the maintainer rarely does |
| 23 | Discuss an item with Claude before deciding | P4 *Ask* scoped to the item (read-only); "Copy a prompt for Claude Code" | a full chat with write access is **out** - that is Claude Code |
| 24 | Inspect a feature's diff (`git diff main...branch`) | P5 commit / diff viewer; earlier: "open in editor" links | |
| 25 | Watch `.agent-traces` size | status bar (P1) | |
| 26 | The loop's own auto-triage (`--auto-triage`) | a start option (P1); its result shown on Home and Runs | the reviewed plan (P4) is the app's addition, not a replacement |
| 27 | Running `BL check` and fixing findings | P2 Check page | fixes that need git (conflicts, malformed header restore) stay in the terminal |
| 28 | Checking out branches, `git restore` of a broken item | no | **out** - the app never checks out, resets or restores outside its own pre-commit undo of `backlog/` files |
| 29 | Several repositories / `--root` | no | **out of v1** - one repository chosen at start |
| 30 | Usage-limit observation (person step `backlog-loop-person-checks`) | the Live page shows which of the two limit behaviours happened (claude waited in-process vs the loop waited) | helps the person step; does not replace it |

### 6.2 Decisions for the maintainer to confirm

1. **Commit policy.** Proposed: app changes accumulate in a change tray and are
   committed on `main` by an explicit *Commit* (paths under `backlog/` only), with
   automatic commit points before *Start* / *Resume* and after a triage session; undo
   only before commit. Alternative: one commit per operation (simpler, noisier
   history, no undo).
2. **Writes only on `main`.** Proposed: on any other branch the backlog is read-only
   in the app (today this very checkout is on `344-backlog-web-app`). Alternative:
   allow writes on any branch with a warning - then app commits would land in a
   feature branch.
3. **During a run.** Proposed for v1: read-only, as the skill says, with *Pause after
   this item*. Later: queued changes or a separate `main` worktree (4.6) - choose one.
4. **Who owns the loop process.** Proposed: the app can start the loop as its own
   background process (it then also offers hard stop) **and** attaches to a loop
   started in a terminal (control by the existing pause / resume / stop flags). If the
   app's server stops, a loop it started keeps running (the backend must detach it).
5. **AI jobs act in maintainer mode** for the one operation clicked (verify, the
   auto-triage plan, judging an import, a draft), use the local claude CLI and the same
   subscription as the loop. Proposed: drafts and plans are previews the app applies
   with the tool after the maintainer's confirmation; AI never writes the backlog
   directly from the app. AI-created items always land in Inbox unless the maintainer
   places them in the same dialog.
6. **Run one chosen item** needs a backend entry point (a single run, or loop
   `--only <slug>`); confirm it is wanted for v1 or P5.
7. **UI language.** Proposed: English UI (the records, the tool's messages and the
   legend are English; no translation layer); Czech input accepted in the AI draft box.
   Alternative: Czech UI chrome with English records.
8. **Notifications without an open tab** (a Windows toast from the server) - wanted,
   or browser notifications only?
9. **Person-step results are written into the item** (`- [x]` and a log line per
   step). Confirm this is how results should be recorded (today they are mostly
   recorded when the step is closed).
10. **The app never pushes, tags, publishes, posts to GitHub, checks out branches,
    resets, or touches files outside `backlog/`** (except reading specs, traces,
    git). Confirm there is no exception wanted (e.g. a "push main" button) - the
    proposal is none.

### 6.3 Steps that must stay a person's or a skill's

- **Person only**: deciding a decision (the app records it); ordering and triage (the
  app executes the maintainer's choice; the recommendation is advice); every person
  step's real check; answering GitHub issues; merging by hand; resolving git
  conflicts; releasing (build, sign, tag, GitHub release, winget); pushing; restoring
  the registry after a cut probe; releasing a stale lock (the click is the person's).
- **Skill / AI only** (the app launches, never imitates): implementing an item
  (`/tandem-backlog-implement`, through the loop); verifying at HEAD; rule A of
  auto-triage (code not shipped) and the severity re-check; writing *Evidence* from
  code; judging a GitHub issue; `/tandem-release` (stays in Claude Code).
- **Mechanical, the app does it itself through `bin/backlog.sh`**: list, show, next,
  check, sync, new, set, log, move, block, unblock, remove (close with a reason the
  maintainer wrote), import-github (the mechanical part), commit of `backlog/`.
  Never `start`, `run-log`, `lock acquire/update`, `remove --feature` - those belong
  to runs.

---

## 7. Needs from the backend (for analyses 01-03)

- A watcher over `backlog/`, `.git/HEAD`, `MERGE_HEAD`, the run lock,
  `.git/tandem-backlog-loop/*`, `.agent-traces/index.jsonl` and the followed
  `trace.jsonl`, pushing events (SSE or WebSocket).
- A serialised write queue that runs `bin/backlog.sh` with hash preconditions, never
  puts item text on a command line, and reports the two exit-1 forms distinctly.
- A pre-operation snapshot of the touched `backlog/` files for undo before commit.
- Parsing: `BACKLOG.md` sections and legend, the 15-key header, body sections,
  *Options* (A/B/C), *Steps* checklists, RUNS rows, `meta.json` / `index.jsonl`,
  `tasks.md` checkboxes, the stream-json trace into phases / tool calls / messages /
  subagents, `loop.json` / `run.json` (state, phase, `wait_until`, usage figures,
  `todo`).
- Git reads: history of an item's `desc.md` (also after deletion), removals of items,
  commits of a run, `git show <branch>:<path>`, ahead / behind `origin/main` (no
  fetch), tags.
- Loop control: start detached with the options, pause / resume / stop flags, status
  JSON, hard stop of a loop it started; a single-run entry point if decision 6.2-6 is
  yes.
- An AI job runner over the local claude CLI: read-only jobs (Ask, drafts, plans) with
  restricted tools, maintainer-mode jobs (verify), progress streamed, cancellable,
  never two writing jobs at once, refused while the write gate is closed.
- Bind to localhost only; the app starts processes with bypassed permissions, so it
  must not be reachable from the network.
