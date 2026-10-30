# 344 analysis 01 — Backlog data and operations

Scope: what a person can do with the backlog today, with which command, under
which preconditions, which files change, and how a localhost web app can do
the same safely. Not covered here: the run loop internals and the technology
stack (other analyses). Measured at `f7faf9ae` (branch `344-backlog-web-app`,
tree = `main` + this folder), 2026-10-30.

Sources read: `backlog/BACKLOG.md`, `backlog/RUNS.md`, items of every type
and status, `specs/242-backlog-system/contracts/{cli,item-format,overview-format,skills}.md`,
`specs/242-backlog-system/data-model.md`, `tools/backlog/backlog.py` (whole),
`tools/backlog/loop.py` (precheck, status, triage, pause), `tools/backlog/traces.py`
(commit attribution), `.claude/skills/tandem-backlog/{SKILL,reference}.md`,
`.claude/skills/tandem-backlog-implement/SKILL.md` (preconditions, step 9/10),
`specs/FEATURE-HISTORY.md` entries 242, 247, 342, `CLAUDE.md`. Every
`bin/backlog.sh <cmd> --help` was run; behaviour claims marked *measured* were
run on a scratch copy (`--root <scratch>`), never on the real backlog.

---

## 1. Files and who owns them

| File | Content | Changed by today | Rule |
|---|---|---|---|
| `backlog/BACKLOG.md` | overview: intro text, `Last triaged: YYYY-MM-DD`, 7 section tables, *Legend* (7 tables = the vocabularies) | only the tool; the maintainer may reorder rows by hand, then `sync` (SKILL.md:115-117) | every cell except a row's **position and section** is derived from the items (`BACKLOG.md:6-9`, `backlog.py:610-662`) |
| `backlog/items/<slug>/desc.md` | 15-key header + body | header: only the tool; body: the editor (Claude's Edit tool) (SKILL.md:28) | the only source of an item's data |
| `backlog/items/<slug>/issue.md` | verbatim GitHub issue + comments | `import-github` | first line `number: N` (check rule `github`) |
| `backlog/items/<slug>/reply.md` | draft answer to the issue | `import-github` creates; editor afterwards | first line `state: not-sent` / `state: sent YYYY-MM-DD` (`backlog.py:116`, 1002-1006) |
| `backlog/items/<slug>/evidence/` | any files (probes, captures) | by hand / agents | no format; only existence allowed by `layout` |
| `backlog/RUNS.md` | journal of autonomous runs, one table, append-only | only `run-log` (implement skill) | outcomes `closed, blocked, not-reproduced, split, nothing-to-do` |
| `backlog/RELEASE.md` | free Markdown, release procedure | the maintainer / `/tandem-release` | only existence checked |
| `<git-common-dir>/tandem-backlog-run.lock` | run lock (`started`, `slug`, `branch`, `host`) | `lock acquire/update/release` | unversioned; stale after 24 h (`backlog.py:123`, 1161-1174) |
| `<git-common-dir>/tandem-backlog-loop/{loop.json,run.json,triage.json,pause,stop}` | loop state and control flags | `bin/backlog-loop.sh` | unversioned (`loop.py:244-256`) |

Nothing else may exist at the top level of `backlog/` or in an item folder
(check rule `layout`, `backlog.py:937-957`) — including leftover `*.tmp~`
files of an interrupted atomic write.

Current size (measured): 257 items, 1.2 MB, 625 KB of `desc.md` text, 12,713
lines, largest `desc.md` 5.6 KB / 80 lines; sections Next 133, Person steps 78,
Decisions 17, Rejected 14, Parked 12, Inbox 3, In progress 0; statuses open
227, rejected 14, parked 12, new 3, blocked 1; 72 items with `related`, 1 with
`depends-on`; 380 unchecked `- [ ]` step lines, 0 checked; 2 `issue.md`, 1
`evidence/` folder; 112 item folders removed in git history (closed items).

---

## 2. Data model

### 2.1 Item header (`item-format.md:9-49`, `backlog.py:56-60, 338-397, 791-853`)

Exactly these 15 keys, this order, `key: value`, between `---` lines; no
comments, blank lines, quotes. Lists in flow form `[a, b]`.

| Key | Allowed values (today) | Set by |
|---|---|---|
| `title` | one line, non-empty, not `-`, no control chars; ≤ 80 chars is a *writing rule* (reference.md:113), not checked | `new`, `set title=` (also rewrites the body's `# ` line, `backlog.py:1452-1453`) |
| `type` | legend *Types*: `bug`, `feature`, `improvement`, `tech-debt`, `decision`, `person-step` | `new`, `set` |
| `status` | legend *Statuses*: `new`, `open`, `blocked`, `in-progress`, `parked`, `rejected` (no `done`) | **never `set`** (refused, `backlog.py:1439-1440`); only `move`/`block`/`unblock`/`start` |
| `severity` | integer 0–10 (stored as text; `list --json` emits it as a **string**, measured) | `new`, `set` |
| `area` | legend *Areas*: `build-release`, `translations`, `encoding`, `long-paths`, `file-ops`, `data-safety`, `panels-ui`, `viewer`, `archives`, `plugin-api`, `webview`, `privacy-security`, `ftp`, `sftp`, `pictview`, `other-plugins`, `help-docs`, `tooling` | `new`, `set` |
| `source` | legend *Sources* forms: `manual`, `github#N`, `review:NNN`, `leftover:NNN`, `measure:NNN`, `probe:NNN`, `next-work` (NNN = 3 digits; regex built from the legend, `backlog.py:782-788`) | `new` (`--source`), `import-github`, `set` |
| `who` | `agent`, `person`, `both`; a `person-step` must be `person` | `new`, `set` |
| `created` | `YYYY-MM-DD` | `new` only |
| `updated` | `YYYY-MM-DD` ≥ created | every changing command (`touch`, `backlog.py:457-460`) |
| `verified` | `-` or `YYYY-MM-DD <7–40 lowercase hex>` | `verify` (or `set verified=`, not refused by the code) |
| `effort` | `S`, `M`, `L`, `?`, `-` | `new`, `set` |
| `feature` | `-` or 3 digits; required **iff** `in-progress` | `start`; `set` would be refused by `required` |
| `related` | `[]` or existing slugs, not self | `new`, `set`; pruned by `remove` |
| `depends-on` | `[]` or existing slugs, not self, not `rejected`, no cycle | `new`, `set`; pruned by `remove` |
| `reason` | `-` or one line; required **iff** `blocked`/`parked`/`rejected` | `move` (parked/rejected), `block`; cleared by `unblock`/`move` |

Slug = folder name, `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤ 60 chars
(`backlog.py:110-111`), derived from the title by NFKD + ASCII fold
(`backlog.py:224-234`), **never renamed**. A title without ASCII letters gives
no slug → `--slug` required.

There is **no** `see` / `blocked-by` field (0 items, measured). Relations are
only `related` (symmetric-ish, informational) and `depends-on` (hard: an
item with a dependency still in the backlog is ineligible for a run,
`backlog.py:1108-1110`). `reason` is free text ("waits for …").

### 2.2 Item body (`item-format.md:51-85`, `backlog.py:91-99, 856-902`)

```
# <title>                       (first non-empty line, equal to header title)
## Problem      required
## Evidence     required
## Expected     required
## Approach     optional
## Notes        optional
## Question     required for decision
## Options      required for decision
## Recommendation  required for decision
## Steps        required for person-step; ≥ 1 "- [ ] …" / "- [x] …" line
## Log          required; ≥ 1 entry "- YYYY-MM-DD — text" (em dash U+2014), dates non-decreasing
```

Only these ten `## ` headings, each at most once, in this order; other
structure as `###` or lists. Headings inside ``` / ~~~ fences are ignored.
Present today: *Notes* in 167 items, *Approach* in 58. The *Log* is appended
by every changing command (`append_log`, `backlog.py:437-454`) and is the
item's in-file history (creation, triage moves with position, status changes
with reason, verification with commit, run start/stop, decisions).

### 2.3 Overview sections (`overview-format.md:84-108`, `backlog.py:62-88, 762-779`)

| Section | Ordered | Columns | Admits (precedence top-down) | Status set by `move` |
|---|---|---|---|---|
| In progress | yes | # Item Type Sev Area Feature | `in-progress` | only `start` |
| Next | yes | # Item Type Sev Area Who Effort Status | `open`/`blocked`, who agent/both, type ≠ decision/person-step | `open` (a `blocked` item stays `blocked`) |
| Decisions for the maintainer | yes | # Item Sev Area Status | type `decision`, `open`/`blocked` | `open` / stays `blocked` |
| Person steps | yes | # Item Area Status | who `person` or type `person-step`, `open`/`blocked` | `open` / stays `blocked` |
| Inbox | no — sorted by `created`, slug | Item Type Sev Area Source Created | `new` | `new`, reason cleared |
| Parked | no — sorted by `area`, slug | Item Area Reason | `parked` | `parked` + reason |
| Rejected | no — sorted by `area`, slug | Item Area Reason | `rejected` | `rejected` + reason |

The section is a **function of the header** (`expected_section`): type +
who + status decide it; the person owns only the order within the four
ordered sections. Row = `[escaped title](items/<slug>/desc.md)`; `|`, `[`, `]`,
`\` in titles are escaped (`backlog.py:245-250`; measured: `Test a \| pipe \[x\] title`).
A hand-written row without an item link is kept verbatim but is an
`overview` finding and makes `sync` refuse (`backlog.py:640-662`, 1343-1345).

**Surprise:** on `main` the *In progress* section is (almost) always empty.
A run does `start` **on its feature branch** (implement SKILL.md:245, 558-559:
"On `main` the item is still `open` without a feature number — the start
happened on the branch"). The running item is known on `main` only through
the run lock / loop status, not through `BACKLOG.md`.

### 2.4 Statuses and transitions (data-model.md:39-63, measured)

| From → To | Command | Refusals |
|---|---|---|
| (none) → `new` | `new`, `import-github` | slug exists; title gives no slug; invalid values |
| `new` → `open` (Next/Decisions/Person) | `move --section S [--position N]` | section does not admit type/who (`belongs in '<S>'`) |
| `new` → `parked`/`rejected` | `move --section parked|rejected --reason R` | no reason |
| `open` ↔ `blocked` | `block --reason R` / `unblock [--note]` (row stays) | `block` only from `open`; `unblock` only from `blocked` |
| `open`/`blocked` → other ordered section or position | `move` (blocked stays blocked, logged "still blocked: …") | admission |
| `open`/`blocked` → `new` | `move --section inbox` (measured: blocked → new, reason cleared) | — |
| `parked`/`rejected` → any other section | `move --section S --reason <new reason>` (logged "reopened: …") | no reason |
| `open` → `in-progress` | `start --feature NNN` (runs only) | not eligible (`eligibility`, `backlog.py:1099-1111`) |
| any → removed | `remove --reason R` (not `in-progress`); `remove --feature NNN [--force]` (runs) | in-progress with `--reason`; wrong feature without `--force` |
| `in-progress` → anything via `move` | refused ("a run ends it", `backlog.py:1509-1510`) | — |

`decide` (skill) = log line + either `set type=<work type>` (row moves) + `move`,
or `remove --reason 'decided …'`, or `move parked` (SKILL.md:526-544).

Run eligibility (`next`): first row of *Next* with status `open`, who
agent/both, type not decision/person-step, no `depends-on` slug still
present (`backlog.py:1099-1129`). `next --json` →
`{"slug": s|null, "skipped": [{"slug","reason"}]}`; with `--slug` ineligible →
exit 1 `{"slug": null, "refused": s, "reason": r}` (measured).

### 2.5 Legend (`BACKLOG.md:308-401`)

First column of each legend table = the vocabulary, read at every call
(`parse_legend`, `backlog.py:590-607`); "adding a value = adding a row". The
*Severity* table is anchors only (9–10 data loss/crash common; 7–8 narrow;
4–6 function does not work; 1–3 cosmetic; 0 trivial). *Statuses* must stay
within the six the code knows (`backlog.py:815-816`). The legend is the only
place a web app should take its dropdown values from (via a tool command —
see gap G6).

### 2.6 Run journal (`overview-format.md:110-123`)

`| Date | Item | Outcome | Feature | Branch | Inbox | Person steps | Note |`,
newest last, append-only via `run-log`. Today 109 rows (90 closed, 7
blocked, 7 not-reproduced, 5 split). Useful for an item's run history and
for "what did the loop do" views.

---

## 3. The tool (`bin/backlog.sh` → `tools/backlog/backlog.py`)

- `bin/backlog.sh` only `exec`s `${PYTHON:-python} tools/backlog/backlog.py "$@"`
  with `TANDEM_BACKLOG_PROG` set (`bin/backlog.sh:8-51`); arguments pass through
  unchanged.
- Exit codes: `0` ok; `1` = **two different things**: output starting with
  `refused:` (nothing written) or output containing
  `check after the change found problems:` (**the change was written**; never
  repeat — SKILL.md:47-53); `2` usage error. Any other exception (e.g.
  `PermissionError` from `os.replace`) is **not caught** — only `Refused` is
  (`backlog.py:2012-2017`) → Python traceback, exit 1.
- Output: UTF-8, LF. Read commands with `--json`: only `list` and `next`.
  Changing commands print human text (first line of `new` / `import-github`
  = the slug; `set` may print `added the sections … with placeholders - write them`
  and `moved to '<S>' (type / who changed)`).
- Write sequence of every changing command: validate → write item(s) once
  atomically (temp `*.tmp~` + `os.replace`, `backlog.py:172-185`) → rewrite
  `BACKLOG.md` once (`save_overview`, 728-731) → full `check` (`finish`,
  1082-1092).
- **No write lock of its own** (cli.md:22-25, skills.md:49-50): two changing
  commands at once can lose rows (measured in 242). The run lock is **not**
  consulted by any changing command (no call of `lock_path` outside
  `cmd_lock`, `backlog.py:1665`); "not during a run" is enforced only by the
  skill's instructions (SKILL.md:69-84).
- Cost (measured): `list --json` 0.20 s, `check` 0.24 s, through bash 0.30 s
  — every changing command re-parses all 257 items and checks twice.
- Test hooks: `--lock-dir`, `TANDEM_BACKLOG_NOW` (the tool's clock) — the web
  app must never set them.

### 3.1 The 18 check rules (`cli.md:69-90`, `backlog.py:926-1073`)

`layout`, `slug`, `desc-missing`, `header`, `value`, `required`,
`feature-missing`, `body`, `ref`, `cycle`, `github`, `orphan`, `dangling`,
`duplicate`, `section`, `derived`, `overview`, `runs`. Output
`<path>:<line>: <rule>: <message>` then `TOTAL: <n>`; exit 1 iff n > 0. A
`header` finding makes the tool refuse to touch that item
(`backlog.py:710-716`). The fix table is reference.md:335-365.

---

## 4. Operation catalog

Legend for the columns:
**Tool** = existing command (`BL` = `bin/backlog.sh`), *JSON* = machine output exists.
**Lock/loop** = may it run while the run lock is held or the loop runs
unpaused? (R = read-only, always fine; W = write: only when lock `free`,
loop not running or `state: paused`, branch `main` — SKILL.md:69-84).
**Mode** = who may do it (maintainer M; agent A — SKILL.md:90-110). The web
app is used by the maintainer, so it acts in maintainer mode; but it must not
do the operations reserved to runs.
**Web** = how the web app should do it.

### 4.1 Reading and querying (R)

| # | Operation | Inputs | Tool today | Web app |
|---|---|---|---|---|
| R1 | Board: all sections, rows in order, derived columns | — | `BL list --json` (all header fields + `section`, `position`; *JSON*). Misses: `Last triaged`, hand-written rows, rows of unreadable items (silently skipped, `backlog.py:1362-1364`), body, files | call `list --json`; get `Last triaged` and findings elsewhere (G1, G2) |
| R2 | Filter by section/area/type/status/who/min severity/needs/related-to | values from the legend | `BL list --section --area --type --status --who --min-severity --needs --related-to --json` (single value each; AND) | client-side filtering over one `list --json` is cheaper and allows multi-value / OR / text; the tool flags are not needed |
| R3 | Show one item: header, section, position, body sections, Log, files present, `reply.md` state | slug | **none** — `show` is a skill operation (SKILL.md:345-351) assembled from `list --json` + reading `desc.md` by hand | gap G1: add `BL show <slug> --json` (header, section, position, parsed sections in order, log entries, files, `issue.md`/`reply.md` heads, findings of that item) |
| R4 | Full-text search over titles and bodies | text / regex | none (skill uses `grep -ril … backlog/items --include=desc.md`, SKILL.md:196-202) | read `desc.md` files directly (read-only is safe) or from G1's bulk output; 625 KB fits in memory |
| R5 | What would a run take next, and why rows above are skipped | — / slug | `BL next [--slug S] --json` (*JSON*) | call it; show skip reasons on the board |
| R6 | Consistency check | — | `BL check` (line format, no JSON) | gap G2: `check --json`; parse lines meanwhile (`^(.+?):(\d+): ([a-z-]+): (.*)$`, last line `TOTAL: n`) |
| R7 | Dependents / referrers of an item | slug | `list --needs S`, `list --related-to S` | derive from `list --json` (`depends-on`, `related`) — also reverse edges and a graph view |
| R8 | Run journal | — | none (read `RUNS.md`); `check` validates it | parse the one table; filter by slug / outcome / feature |
| R9 | Run lock and loop state | — | `BL lock status` (text only); `bin/backlog-loop.sh status --json` (*JSON*: `loop`, `live`, `run`, `triage`, `paused`, `stop`, `lock`, `lock_text`, `trace`, measured) | poll `backlog-loop.sh status --json`; it is the gate for every write (§6) |
| R10 | History of an item | slug | none; `git log --format=… -- backlog/items/<slug>/desc.md` (0.07 s measured) | `git log` / `git show <c>:backlog/items/<slug>/desc.md`; the in-file *Log* covers the semantic history |
| R11 | Closed (removed) items | — | none; `git log --diff-filter=D --name-only -- 'backlog/items/*/desc.md'` (112 found, 0.13 s) | a "Done" view from git: removing commit, its subject (`[NNN] …` = feature), last content via `git show <c>^:…` |
| R12 | Links to features | item | none | `feature` header (in-progress only); `source: review:NNN|leftover:NNN|measure:NNN|probe:NNN`; "feature NNN" in Log/Evidence (482 mentions); `specs/NNN-*` paths in bodies (166 distinct) → resolve to `specs/NNN-*/` folders and `FEATURE-HISTORY.md` `^- NNN-` |
| R13 | GitHub issue text / reply draft | slug | none (files) | read `issue.md`, `reply.md` directly; display read-only (issue) |
| R14 | Legend vocabularies | — | none (parsed internally) | gap G6: `BL legend --json`; meanwhile parse `## Legend` tables (first column, backticks stripped) |
| R15 | Section state as seen on `main` while a run has the tree on its branch | — | none: the tool reads only the working tree | gap G9 (read from a ref) — or show the branch state labelled as such |

### 4.2 Creating (W)

| # | Operation | Inputs | Preconditions / refusals | Files | Tool today | Mode | Web app |
|---|---|---|---|---|---|---|---|
| C1 | Add an item (always to *Inbox*) | title, type, severity, area, [source=manual], [who=agent], [effort], [related], [depends-on], [slug], [problem/evidence/expected] | slug exists → refused naming it; title gives no slug; values outside legend; header text with control chars (`one_line`, 188-192) | new `items/<slug>/desc.md`, `BACKLOG.md` (Inbox row) | `BL new …` (prints slug; no JSON) | M, A | call `new` with an argument array (no shell). Body texts may span lines (measured: multi-line `--problem` with backticks and `$` stored verbatim when no shell is involved), but long texts hit the 32,767-char Windows command line → gap G3 (`--problem-file` / JSON on stdin). Then the body editor (C2/E4) replaces `(to be written)` placeholders |
| C2 | Complete the body after creation (all `(to be written)`) | section texts | — | `desc.md` body | none (Edit tool) | M, A (own items) | gap G4 (`body` command) |
| C3 | Import one GitHub issue | number, area, [type], [severity=5], [slug] | already imported; PR; network error; comment count mismatch (nothing written) | `desc.md`, `issue.md`, `reply.md` (`state: not-sent`), `BACKLOG.md` | `BL import-github N --area A …` | M, A | call it (network to api.github.com, through `gh` when installed, `backlog.py:1181-1193`); the skill's judging step (§2.2 C: rewrite body in English, set type/severity/title) is AI work — offer "ask Claude" or leave the defaults visibly marked |
| C4 | Import all new issues with a label | label (skill uses `ai backlog`), [area], [severity], [--dry-run] | skips PRs, held issues, `fixed/duplicate/invalid/wontfix`, issues whose item was removed (git history) | as C3 per issue | `BL import-github --label L [--dry-run]` (per-line text output) | M, A | dry-run first, show the plan, then run once; parse `imported #N <slug>` / `skipped #N: …` / `failed #N: …` lines |
| C5 | Split an item into several | parent, children | — | several | none (implement run does it; a person: `new` ×n + `remove --reason 'split into …'`) | M | composite: G5 (batch) |

### 4.3 Editing fields and text (W)

| # | Operation | Inputs | Refusals | Files | Tool today | Mode | Web app |
|---|---|---|---|---|---|---|---|
| E1 | Change header fields (title, type, severity, area, source, who, effort, related, depends-on, verified) | `key=value…`, [`--log`] | `status`/`updated` refused; unknown key; invalid value; self/missing/rejected/cyclic refs; multi-line value | `desc.md`; `BACKLOG.md` (derived cells; row moves to the **end** of the new section when type/who change the section, `backlog.py:1456-1462`) | `BL set <slug> k=v … [--log T]` | M; A only own items | call `set`; show the printed `moved to …` / `added the sections …` notices (needs G2-style JSON result, G7). Note `set type=decision` on an Inbox item adds placeholder sections but stays in Inbox (measured) |
| E2 | Rename (title) | new title | one line | `desc.md` header + `# ` line, `BACKLOG.md` | `BL set <slug> 'title=…'` | M | as E1; slug never changes |
| E3 | Add a log line | text (line breaks flattened to spaces, measured) | — | `desc.md` (+ `updated`), `BACKLOG.md` rewritten | `BL log <slug> TEXT` | M, A | call `log`. Useful as a "comment" feature |
| E4 | Edit body sections (Problem, Evidence, Expected, Approach, Notes, Question, Options, Recommendation, Steps) | section text | must keep: title line, headings set/order, fences, *Log* format; header untouched | `desc.md` body | **none** — Edit tool by hand, then `BL log <slug> '<what changed>'` (SKILL.md:502-503) | M; A only own items | gap G4: `BL body <slug> --section S --file F` (replace one section; validates `body_findings` before writing; appends a log line; keeps header byte-identical). Writing `desc.md` from Node would make the web app a second owner of the format |
| E5 | Tick a person-step checklist line | slug, line | — | `desc.md` *Steps* | none (by hand) | M | via G4 (or a small `step <slug> N --done`) |
| E6 | Edit `reply.md` / mark it sent | text / date | first line `state: …` | `reply.md` | none (by hand) | M | gap G8 (`reply <slug> --state sent YYYY-MM-DD`); never post to GitHub (SKILL.md:119) |
| E7 | Add / remove evidence files | files | only inside `evidence/` (`layout`) | `evidence/*` | none | M, A | write into `evidence/` directly is format-safe (no rules on content); log a line with `log`. Mind binary size in git |
| E8 | Verify at HEAD (stamp) | [commit], [note] | commit not 7–40 lowercase hex | `desc.md` (`verified`, log), `BACKLOG.md` | `BL verify <slug> [--commit C] [--note T]` (HEAD = `git rev-parse --short HEAD`, `backlog.py:1477`) | M, A | the stamp is mechanical; the **judgement** (is it still true at HEAD — reading code, running probes, SKILL.md:508-524) is AI work → offer "ask Claude to verify" (needs a session), or let the maintainer stamp with a note |

### 4.4 Ordering, sections and status (W, maintainer only)

| # | Operation | Inputs | Refusals | Files | Tool today | Web app |
|---|---|---|---|---|---|---|
| O1 | Triage an Inbox item into Next / Decisions / Person at a position | slug, section, position | section does not admit type/who → change type/who first | `desc.md` (status, log "moved to S position N"), `BACKLOG.md` (row, numbering, **`Last triaged` = today**) | `BL move <slug> --section next|decisions|person --position N` | call `move`. The *recommended* target, position (reference.md:303-310: above the first row of lower severity, below its dependency) and severity are AI/heuristic — the position rule is mechanical and could be computed in the app; rule A (not shipped) and B need reading code/text (AI) |
| O2 | Reorder within a section (drag and drop) | slug, new position | position < 1; position past end = end | `desc.md` (+1 log line "moved to Next position N", `updated`), `BACKLOG.md` (`Last triaged` = today) | `BL move <slug> --section <same> --position N` (measured: works; the row is taken out first, then inserted at item-row N) | works per drag, but every drag adds a log line and touches `updated` in the item. A multi-row reorder = n commands, n log lines, ~0.3 s each. Gap G5: `reorder --section S slug…` (one write, optional no-log). Hand-reorder + `sync` is the documented maintainer exception (SKILL.md:115-117) but bypasses validation of the order and is not atomic with the app's view |
| O3 | Move up / down / to top / to bottom | slug, delta | as O2 | as O2 | as O2 (`--position` omitted = end) | as O2 |
| O4 | Park | slug, reason (`'<why>; maintainer YYYY-MM-DD'`, SKILL.md:140-145) | no reason; in-progress | `desc.md` (status, reason), `BACKLOG.md` (Parked, sorted by area, slug; `Last triaged`) | `BL move <slug> --section parked --reason R` | call it; prefill the reason suffix |
| O5 | Reject | slug, reason | as O4; **dependents** must be handled first (`depends-on` a rejected item is a `ref` finding) — the tool does **not** refuse the move itself, the check after it fails (validate checks only the moved item's own refs) | as O4 → Rejected | `BL list --needs S` then per dependent `set depends-on=…` or reject it; then `move --section rejected --reason R` (SKILL.md:552-564) | composite: show dependents, require a choice per dependent, then run the commands in order |
| O6 | Reopen from Parked/Rejected | slug, target, [position], **new** reason | no reason | `desc.md`, `BACKLOG.md` | `BL move <slug> --section S --reason R` | call it; whether the reason is really new is the maintainer's judgement |
| O7 | Back to Inbox | slug | in-progress | status `new`, reason cleared | `BL move <slug> --section inbox` (does **not** touch `Last triaged`) | call it |
| O8 | Block / unblock | slug, reason / note | block only `open`; unblock only `blocked` | `desc.md`, `BACKLOG.md` (Status cell; row stays) | `BL block <slug> --reason R` / `BL unblock <slug> [--note N]` | call them |
| O9 | Convert type/who (e.g. bug → person-step, → decision) | slug, type, who | person-step needs who person | `desc.md` (+ placeholder sections), row to **end** of the fitting section | `BL set <slug> type=… who=…` | then O2 to place it; then E4 to write the new sections |
| O10 | Record a decision (`decide`) | slug, decision text, outcome (convert / answered / later) | type must be `decision` (skill rule) | per outcome | composite of `log` + (`set`+`move`) / `remove --reason` / `move parked` (SKILL.md:526-544) | composite operation in the app; the wording of the converted *Problem/Expected* is AI or the maintainer's text (E4) |

### 4.5 Closing (W, maintainer only)

| # | Operation | Inputs | Refusals | Files | Tool today | Web app |
|---|---|---|---|---|---|---|
| X1 | Close an already fixed / obsolete / answered item | slug, reason | in-progress (`backlog.py:1617-1618`); need exactly one of `--feature` / `--reason` | **deletes `items/<slug>/` with `evidence/`** (read-only files too, `backlog.py:1593-1601`), row removed, slug pruned from every other item's `related`/`depends-on` with a log line there | `BL verify <slug> --note …` then `BL remove <slug> --reason R` (SKILL.md:585-598) | confirm dialog listing dependents/related (R7) and a `github#N` reply owed; irreversible except by git (§7). Duplicates / mistakes are **rejected**, not removed (SKILL.md:120-122) |
| X2 | Close by a feature | slug, NNN | — | as X1 | `BL remove <slug> --feature NNN [--force]` | **run-only** (implement skill); the maintainer's equivalent is X1 with reason "fixed by feature NNN". Expose `--force` only for the documented recovery of an `in-progress` item merged by hand (reference.md:348) |

### 4.6 Run-only commands (not for the web app's edit UI)

`next` (read is fine), `start`, `remove --feature`, `run-log`, `lock
acquire|update|release` belong to `/tandem-backlog-implement`
(SKILL.md:85-88). Exceptions a maintainer UI may offer, each behind a
confirmation: `lock release --force` for a STALE lock (`describe_lock`,
`backlog.py:1172-1173`) and the recovery recipe `bin/backlog-loop.sh status`
prints for a `lost`/`failed` run (`loop.py:1496-1503`). Loop control
(`pause`, `resume`, `stop`, `start`) is another analysis' scope but is the
gate for writes (§6).

### 4.7 Maintenance

| # | Operation | Tool | Web app |
|---|---|---|---|
| M1 | Check | `BL check` | show findings per item / file (R6) |
| M2 | Sync derived cells and numbering | `BL sync` (refuses on rows without items, items without rows, duplicates, `overview` findings) | expose as "repair" only when `derived` findings exist |
| M3 | Fix findings | reference.md:335-365 — many need `git diff`/`git restore` or hand edits of `BACKLOG.md` | show the fix text; automate only `derived` (sync) and `orphan` (`move --section <implied>`), leave the rest to the maintainer / a Claude session |
| M4 | Edit the legend (add an area, type, source form, effort) | none (hand edit of `## Legend`) | rare; gap G6 if wanted (`legend add <table> <value> <meaning>`); removing a value in use creates `value` findings |
| M5 | Resolve a git conflict in `BACKLOG.md` | keep both rows, `sync`, `check` (SKILL.md:123-125) | out of the app's scope: detect conflict markers / unmerged state and refuse to write |

### 4.8 AI-only operations (need a Claude session, not just the tool)

| Operation | Why AI | Tool part the app could still do |
|---|---|---|
| `add` from free text (SKILL.md:185-251) | splitting into items, choosing type/area/severity/who (reference.md §3), finding duplicates, writing exact *Evidence* (`file:line` at a commit) | the form-based C1 with the maintainer's own values |
| `triage` recommendation (§2.5) | target, severity band, rule A (not shipped: `plugins.cfg`, `.vcxproj` greps), rule B (text contradicts fields) | the mechanical part of *Position* (reference.md:303-310) |
| `auto-triage [--dry-run|--commit]` (§2.5a) | as above, without questions; commits `backlog: auto-triage - …` | trigger `claude -p '/tandem-backlog auto-triage --dry-run'` and show the plan, or run it with `--commit` while the loop is paused/stopped |
| `verify` judgement (§2.8) | reading code at HEAD, running probes | the stamp (E8) |
| judging an imported issue (§2.2 C) | English rewrite, severity from the described consequence | C3/C4 defaults |
| `decide` wording, `reject` reasons | the maintainer's words (no AI needed) | O10 |
| implementing an item | `/tandem-backlog-implement` | "run this item" = start the loop / a run (other analysis) |

---

## 5. Filters, facets and querying

Facets the data supports directly (all in `list --json`): `section`,
`position`, `type` (6), `status` (6), `severity` (0–10; bands 0 / 1–3 / 4–6 /
7–8 / 9–10), `area` (18), `who` (3), `effort` (S/M/L/?/-), `source` kind
(`manual`, `github`, `review`, `leftover`, `measure`, `probe`, `next-work`)
and its feature number, `created` / `updated` (date ranges, "stale since"),
`verified` (never / date / commit; "not verified since commit X"),
`feature` (in-progress only), `reason` text (blocked/parked/rejected),
`related` / `depends-on` (has any, names X, reverse), eligibility for a run
(`next` skip reasons: `status blocked`, `who person`, `type decision`,
`depends-on X`).

Derived from bodies: has *Approach* / *Notes*; `(to be written)`
placeholders left (auto-triage rule B); person-step checklist progress
(`- [ ]` vs `- [x]`); Log facts — last triage move, times moved, "not
reproduced at", "maintainer decision", last log date; `evidence/` present;
`issue.md` / `reply.md` state (`not-sent` = an answer owed).

"Querying" therefore means: (1) structured filters/sorting over the 15
header fields + section/position; (2) full-text and regex over title + body
sections (per-section search, e.g. only *Evidence* for a file name such as
`dialogs3.cpp` to find every item touching a file); (3) relations —
`depends-on` graph (cycles impossible by `cycle`), `related` neighbours,
reverse links, items mentioning another slug in text; (4) feature links —
`source` NNN, `feature`, "feature NNN" mentions → `specs/NNN-*`,
`FEATURE-HISTORY.md` entry, `RUNS.md` rows with that feature; (5) git —
per-item history, removed items ("Done"), who/when last changed, what a run
changed in the backlog (commits after its `base` with `[NNN]` or
`backlog: <slug> ` subjects, `traces.py:244-249`); (6) time series — Inbox
inflow (`created`), closures (git deletions), run outcomes (`RUNS.md`).
Saved queries could be plain URL query strings; nothing needs to be stored in
`backlog/` (anything stored there is a `layout` finding).

---

## 6. Concurrency hazards and the rules the web app must obey

### 6.1 Who else writes the backlog files

1. **An autonomous run** (`/tandem-backlog-implement`, alone or under the
   loop) — holds the run lock; the working tree is on its feature branch
   for most of the run; at the end it switches to `main`, fast-forwards,
   or stops and commits on `main`.
2. **The loop's auto-triage** (`claude -p '/tandem-backlog auto-triage --commit'`,
   `loop.py:105, 1196-1244`) — no lock; loop `state: triage`; commits on
   `main` everything under `backlog/` that `git status` lists (SKILL.md:441-445).
3. **An interactive Claude session** of the maintainer (`/tandem-backlog`) or
   any agent adding Inbox items (agent mode is allowed during runs —
   SKILL.md:81-82).
4. **The maintainer by hand** (editor, `git restore`, `git pull`, branch switch).

### 6.2 Hazards (each verified in code or docs)

| Hazard | Evidence | Consequence |
|---|---|---|
| Two changing tool commands at once | cli.md:22-25; no lock in `backlog.py` | lost rows in `BACKLOG.md` (last writer wins on the whole file) |
| A web write while a run holds the lock | SKILL.md:73-76 | the change lands on the run's feature branch and in its commit, or breaks the run's `git merge --ff-only` into `main` |
| A web write to the running item on `main` (e.g. while the run is between branch commits, or via another worktree) | implement SKILL.md:459-466 (guard `git diff $(merge-base main BRANCH) main -- backlog/items/<SLUG>`) | the run refuses to merge and stops: "the item changed on main during the run" |
| A web write while the loop runs unpaused (also `idle`/`waiting`) | SKILL.md:76-80; `loop.py:1351-1381` | the loop can start a run between two writes of one operation; the run's precondition `git status --porcelain` empty fails, or the write lands on the new branch |
| A web write during the loop's auto-triage | `loop.py:1207`; SKILL.md:441-445 | concurrent `BL` commands lose rows; the triage's `git add backlog` commits the web app's uncommitted edits under `backlog: auto-triage …` (and `traces.py:246` attributes that commit to the triage) |
| An uncommitted web edit when the loop is resumed | `loop.py:1121-1141` (`git status --porcelain` non-empty → `waiting: the working tree is not clean`) | the loop waits (re-checks every poll) until the tree is clean; after an auto-triage a dirty tree **stops** the loop (`loop.py:1238-1244`) |
| Untracked files of the app in the repo | `git status --porcelain` lists `??`; `.gitignore` ignores only `/.agent-traces/` of the app-relevant paths (`git check-ignore tools/backlog-app/node_modules/x` → not ignored, measured) | `node_modules/`, a build `dist/`, a log or state file under the tree makes the loop and every run precondition wait / refuse. They must be ignored or live under `<git-common-dir>` like the loop's state |
| Branch is not `main` | `loop.py:1131-1132`; implement precondition SKILL.md:100 | backlog edits belong on `main`; editing on another branch (this feature's branch now) creates backlog conflicts at merge |
| Stale view | none in the tool | the maintainer drags a row based on a list that a triage/run already changed → wrong position or moving an item that is gone / in another section. The tool has no "expected state" guard (gap G7) |
| Windows file sharing on atomic replace | `os.replace` in `write_text` (`backlog.py:179`); exceptions other than `Refused` are uncaught | a reader holding `desc.md`/`BACKLOG.md` open without delete-sharing makes the write fail with a traceback; Node's `fs` (libuv) opens with read/write/delete sharing, but watchers/editors/antivirus may not — keep reads short, retry, run `check` after any non-`refused` failure |
| Interrupted write | items first, `BACKLOG.md` last (`backlog.py:720-722`) | a killed tool can leave an item without row (`orphan`) or a `*.tmp~` (`layout`); the app must not kill a running tool command, and must show findings |
| Tree on the run's branch while the app reads | §2.3 | the app shows the branch's `BACKLOG.md` (item *In progress*, the run's new Inbox items), not `main`'s — label it, or read `main` from git (G9) |

### 6.3 Rules for the web app

1. **One writer**: all changing tool commands go through one serial queue in
   the app; never two at once, never in parallel requests.
2. **Write gate**, checked immediately before **every** changing command (not
   once per page load): `bin/backlog-loop.sh status --json` → `lock` is null,
   and (`live` false **or** `loop.state == "paused"`), and no `triage`
   record alive; `git rev-parse --abbrev-ref HEAD` = `main`; no merge in
   progress / unmerged paths. Otherwise the UI is read-only with the reason
   (the skill's own rule, SKILL.md:69-84). The TOCTOU window (the maintainer
   resumes the loop between the gate and the write) is closed only if the
   app holds something the loop respects for the duration of the
   transaction: the loop waits on the **run lock** (`loop.py:1123-1125`) and
   the run precondition refuses on it — gap G10 (an edit lock the loop and
   runs respect, or reuse of the run lock with `slug: -`, `branch: backlog-app`,
   which needs a contract amendment because the lock means "a run" today).
   Pausing the loop is the maintainer's action (resume too), not something
   the app does silently.
3. **Agent writes are not preventable** (agent mode adds Inbox items during
   runs): the app must re-read after every command and on file-change
   notifications (watch `backlog/` and `.git/HEAD`, `.git/refs/heads/main`,
   the loop dir), and refuse a stale operation (G7).
4. **Clean tree before the loop continues**: every web operation (or a
   short batch) ends in a commit on `main` (§7); the app shows "uncommitted
   backlog changes" prominently and offers commit / discard
   (`git restore backlog` + `git clean` for new item folders — destructive,
   confirm).
5. **Never pass item text through a shell.** Spawn `python
   tools/backlog/backlog.py` (or `bash bin/backlog.sh`) with an argument
   array, `shell: false`. 242 records that item text on a command line runs
   as shell code (backticks) and that the Bash tool collapses `\\`; neither
   applies to a direct argv spawn, but long texts still exceed the Windows
   command line, so bodies go through a file/stdin (G3, G4).
6. **Run-only commands are not offered** (§4.6), and the app never edits a
   header, `BACKLOG.md` tables, `RUNS.md` or the lock by itself.
7. After every command: exit 0 → refresh; `refused:` → show, nothing
   written; `check after the change found problems:` → the change **was
   written**, show findings, never retry; other exit 1 → show stderr, run
   `check`.

---

## 7. Commits, history and undo

**How backlog changes are committed today** (measured on `git log -- backlog`,
395 commits): `[NNN] …` by runs (start on the branch, close / stop), and
`backlog: …` subjects — `backlog: auto-triage - <n> placed, <n> parked, <n> left in Inbox`
(the loop's triage, SKILL.md:441-445), `backlog: <slug> blocked (<NNN>)` /
`… not reproduced at …` / `… split into …` / `backlog: run found nothing to do`
(runs, implement SKILL.md:130, 178-179, 592-593), and the maintainer's own
`backlog: <summary>` (e.g. `f7faf9ae backlog: winget items after #426090 was
merged - 2 closed, 1 unblocked, 1 rewritten`). The `/tandem-backlog` skill
itself **does not commit** in maintainer mode except `auto-triage --commit`;
the maintainer commits by hand. A web edit therefore leaves the tree dirty
until someone commits — which blocks the loop and any run (§6.2).

Rules for web commits:

- Commit on `main` only, only paths under `backlog/` (check
  `git status --porcelain` first, like SKILL.md:441-442; anything else
  dirty → do not commit, say so). With `core.autocrlf=true` (this
  repository) a CRLF→LF rewrite by the tool is not a content change; only
  real edits show (measured on a scratch repo).
- One commit per user operation (or per explicit "save" of a batch); subject
  `backlog: <operation> <slug|summary>` — **but never a subject starting with
  `backlog: auto-triage` or `backlog: <slug> ` for an item a run may be
  working on**: `traces.py:244-249` attributes commits after a run's `base`
  to that run by exactly these prefixes. A distinct prefix (e.g.
  `backlog(web): …`) avoids misattribution; to be decided.
- Attribution trailers: the web app is not a Claude session; the
  maintainer is the author. No push (CLAUDE.md: publishing is the
  maintainer's step).

**Undo**: the tool has none. Options: uncommitted → `git restore backlog`
(+ remove new item folders) — discards **all** uncommitted backlog changes,
including an agent's; committed → `git revert <web commit>` when no later
commit touched the same files (else a conflict in `BACKLOG.md`; resolve by
the recipe "keep both rows, sync, check"), followed by `check`. `remove`
deletes `evidence/` too; only git brings it back. An inverse-command undo
(move back to the old position, `set` the old values) is possible for
`set`/`move`/`block`/`unblock` but adds log lines; not for `remove`/`new`.

**History**: per item `git log -- backlog/items/<slug>` + the *Log*
section; per board `git log -- backlog/BACKLOG.md`; removed items via
`--diff-filter=D` (R11).

---

## 8. Encoding and line ends

- Item files, `BACKLOG.md`, `RUNS.md`: **UTF-8 without BOM** — a BOM is a
  `header` / `overview` finding (`backlog.py:346-348, 529-531`); invalid
  UTF-8 is a finding, not a crash. Item text is English (SKILL.md:16-17) but
  any Unicode is allowed in titles and bodies (em dash in log lines is
  required: `U+2014`, `backlog.py:115, 130`).
- Line ends: the tool reads `\r\n` as `\n` (`read_text`, `backlog.py:166-169`)
  and writes **LF** (`write_text`, 177). Git stores LF (`* text=auto`,
  `.gitattributes`), and this checkout has `core.autocrlf=true`, so the
  working tree holds **CRLF** for 258 of 266 backlog files and LF for the 8
  files the tool rewrote since the last checkout (measured with
  `git ls-files --eol` and a byte scan). Both are fine for the tool and git.
  The web app must accept both when it reads, and — if it ever writes a
  file itself (`evidence/`, `reply.md`) — write UTF-8 without BOM, LF.
- Header values and `--reason`/`--title` must be one line without control
  characters (also tab); log texts and journal cells are flattened
  (whitespace runs → one space, `backlog.py:195-197`) — measured: a log
  text with a line break is stored as one line.
- Table cells escape `|`; link text escapes `\`, `[`, `]` (`backlog.py:245-250`).
  The app must unescape when it shows `BACKLOG.md` cells — better, take
  titles from `list --json`, which returns the raw header.
- Backslashes in texts are safe through an argv array and through files; the
  `\\` collapse is a property of the Bash tool used by Claude, not of the
  tool.
- Item text may contain backticks, `$`, Markdown and HTML-like text — render
  it as Markdown with HTML **escaped** (untrusted content from GitHub issues
  is in `issue.md` and in *Problem* of imported items).

---

## 9. Tool gaps the web app needs (proposed additions to `backlog.py`)

Principle: the tool stays the single owner of the format and of the 18
rules; the web app never writes `desc.md`, `BACKLOG.md` or `RUNS.md` itself.

| # | Gap | Proposal |
|---|---|---|
| G1 | No "show one item" and no bulk read of bodies | `show <slug> --json`: header, section, position, ordered sections `{name, text}`, parsed log entries, step lines with state, files (`issue.md` head, `reply.md` state, `evidence/` names), the item's own findings. Optionally `list --json --with-body` for search indexing in one call |
| G2 | `check` has no JSON; `list --json` hides `Last triaged`, hand-written rows and unreadable items | `check --json` (`[{path, line, rule, message}]`); `board --json` (or `list --json` envelope) with `last_triaged`, sections incl. note rows and unreadable rows |
| G3 | Body texts only via argv (`--problem/--evidence/--expected`) | `--problem-file`, … or `--json-stdin` for `new` (and for G4); no length limit, no quoting |
| G4 | No command edits body sections; every body change is an Edit-tool hand edit | `body <slug> --section S (--file F | --stdin) [--log T]`: replace/add/remove one optional section, validate with `body_findings` before writing, keep header and *Log*; a `step <slug> <n> --done/--undone` for checklists |
| G5 | No multi-row reorder or batch | `reorder --section S <slug…>` (full new order of the section, one write, one log line or none, one `Last triaged`); `batch --stdin` (a JSON list of commands applied under one validation, one `BACKLOG.md` write, all-or-nothing) for triage-many, reject-with-dependents, split |
| G6 | No legend read | `legend --json` (vocabularies with meanings, severity anchors) — the app's dropdowns and validation hints |
| G7 | No optimistic concurrency | `--expect-updated YYYY-MM-DD` is too coarse (same-day edits); better `--expect-hash <sha of desc.md>` / `--expect-section S --expect-position N` on changing commands, refused when the state moved |
| G8 | `reply.md` state not settable | `reply <slug> --state not-sent|sent [--date]` (and body via file) |
| G9 | The tool reads only the working tree | `--ref main` for read commands (read through `git show`), so the app can show `main` while a run has the tree on its branch |
| G10 | No write lock; changing commands ignore the run lock | an advisory lock file in the git common dir taken by every changing command (serialises the app, Claude sessions and runs; fixes the measured lost-rows hazard for everyone), and an "edit session" lock that the loop's `tree_state` and the run precondition treat like the run lock |
| G11 | Changing commands report in prose | `--json` result for changing commands: `{ok, refused, slug, section, position, notices: [...], findings: [...]}` |
| G12 | No undo / no commit support | stays outside the tool: the app commits per operation and reverts its own commits (§7); optionally `BL commit-message` helpers are not needed |

Each new command needs tests in `tools/backlog/test_backlog.py`, an update of
`contracts/cli.md` (feature 344 amendment) and of the skills where they
replace hand edits (G4 would let `/tandem-backlog` stop using the Edit tool
for bodies, too).

---

## 10. Surprises and notes

- The run lock does not protect the backlog: no changing command checks it;
  only the skills' instructions do. Combined with "no write lock", the
  backlog's integrity under concurrency rests entirely on discipline — a web
  app is the first writer that is not a Claude skill and must be gated
  explicitly (§6.3).
- *In progress* is empty on `main` by design; the running item is visible
  only via the lock / loop status.
- `move` within the same section is the reorder command, but it logs a line
  in the item and sets `Last triaged` every time (measured) — a drag-and-drop
  UI would flood item logs.
- `set` moves a row to the **end** of the new section when type/who change
  the section — the position the maintainer wanted is lost; a second `move`
  is needed.
- Rejecting an item that others depend on is not refused by `move`; the
  check after it reports `ref` and the change is already written (exit 1
  "check after the change found problems").
- `list --json` returns `severity` as a string and silently omits items whose
  header is malformed.
- A web app's `node_modules/` or build output inside `tools/backlog-app/`
  would block the loop and every run unless ignored (not ignored today).
- 112 closed items exist only in git history — a "Done" view is cheap and
  valuable, and `import-github --label` already relies on that history.
- The task's "`see`" relation does not exist in the item format; it existed
  only in the 242 migration ledger.
