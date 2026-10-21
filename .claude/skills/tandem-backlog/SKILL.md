---
name: "tandem-backlog"
description: "Manage the Tandem Commander backlog in backlog/ (feature 242): add an item (bug, idea, leftover, review finding, person step, decision), import a GitHub issue, list or show items, triage the Inbox (triage with questions, auto-triage without), reorder, update fields or text, verify an item at HEAD, record a maintainer decision, park, reject, reopen, block, unblock, close an already fixed item, check consistency. Use whenever planned work is recorded, looked up or changed. Never write planned work into specs/."
argument-hint: "<add|import-github|list|show|triage|auto-triage [--dry-run|--commit]|move|update|verify|decide|park|reject|reopen|block|unblock|close|check> [arguments]"
compatibility: "Requires backlog/ and tools/backlog/backlog.py (feature 242)"
user-invocable: true
disable-model-invocation: false
---

## User Input

```text
$ARGUMENTS
```

The input may be Czech or English. **Everything written into `backlog/` is
English.** Answer the maintainer in the language they used.

---

## 0. Ground rules (read before any operation)

### 0.1 What the backlog is

| File | Role | Who changes it |
|---|---|---|
| `backlog/BACKLOG.md` | Overview. **Row order = priority** (top first). Sections in fixed order: *In progress*, *Next*, *Decisions for the maintainer*, *Person steps*, *Inbox*, *Parked*, *Rejected*, then *Legend* (the allowed values). | Only the tool. Every cell except a row's position and section is derived from the items. |
| `backlog/items/<slug>/desc.md` | One item: a metadata header (15 keys, fixed order) + body sections. **The only source of the item's data.** | Header: only the tool. Body: the Edit tool. |
| `backlog/items/<slug>/issue.md`, `reply.md`, `evidence/` | GitHub issue text (verbatim), draft reply, captures | `import-github` / the Edit tool |
| `backlog/RUNS.md` | Journal of autonomous runs | Only `/tandem-backlog-implement` |
| `backlog/RELEASE.md` | Release procedure | The maintainer |

Formats are binding: `specs/242-backlog-system/contracts/item-format.md`,
`overview-format.md`, commands `contracts/cli.md`. Templates, decision
tables (type, area, severity, who, effort, source), writing rules and the
fix table: **[reference.md](reference.md) — read the part an operation
points to before doing it.**

### 0.2 The tool

All commands run from the repository root with the **Bash** tool:

```text
BL = python tools/backlog/backlog.py
```

- **Exit codes.** `0` = done. `2` = wrong usage (fix the command).
  `1` has **two forms**:
  - output starting with **`refused:`** → nothing was written; fix the
    cause (reference.md §6) and repeat;
  - output containing **`check after the change found problems:`** →
    **the change was written**; never repeat the command (a repeat makes
    duplicates); fix the listed findings (reference.md §6).
- Never "fix" a refusal by editing a header or `BACKLOG.md` by hand.
- **Texts on the command line**: in **single quotes** (backticks and `$`
  stay literal); a single quote inside is written `'\''`. Header values
  (`--title`, `--reason`, `set key=value`) are one line — the tool refuses
  line breaks. **Never put a backslash inside a text on the command line**:
  the Bash tool collapses `\\` to `\` even inside single quotes (measured),
  so UNC paths (`\\server\share`), `\\?\` prefixes and Windows paths would
  be stored wrong. (A `\` at the end of a line, continuing a command, is
  fine.) Texts with backslashes or longer than a paragraph: create the item
  with a short placeholder text, write the real text into the body with the
  Edit tool, then `grep` it back to confirm. Titles: write paths with
  forward slashes or name them in words.
- **One changing command at a time.** The tool has no lock of its own; two
  changing commands at once can lose rows. Never run changing `BL` commands
  in parallel tool calls or in parallel agents.
- **Not during a run** (maintainer mode). Before the first changing
  operation run `BL lock status` and `python tools/backlog/loop.py status`.
  A lock other than `free` means an autonomous run
  (`/tandem-backlog-implement`) owns the working tree — it is on the run's
  feature branch, and a change made now would land in the feature's commit
  or break its fast-forward of `main`. A loop that is running and not
  `paused` (`loop: running`, `state:` other than `paused`) can start a run
  between two commits of this operation (feature 247). In either case
  change nothing; tell the maintainer to run `tools/backlog/loop-pause.sh`
  and wait until `tools/backlog/loop-status.sh` shows `state: paused` and
  `lock: free` (or to let a manual run finish), then continue; resuming the
  loop (`loop-resume.sh`) is the maintainer's step. Read-only operations
  (`list`, `show`, `check`) are fine. Agent mode inside a run is
  unaffected. **The loop's own triage** (`loop-start.sh --auto-triage`,
  §2.5a *From the loop*) is the exception: it runs while the loop waits
  for it, and the loop starts no run meanwhile.
- Commands of this skill: `check`, `sync`, `list`, `new`, `import-github`,
  `set`, `log`, `verify`, `move`, `block`, `unblock`, `remove --reason`.
  `next`, `start`, `remove --feature`, `run-log` and `lock` belong to
  `/tandem-backlog-implement`; never use them here.

### 0.3 Who is asking — the two modes

- **Maintainer mode**: the maintainer invoked `/tandem-backlog` or asked in
  their own words in this conversation for this backlog operation. All
  operations are allowed.
- **The loop's triage**: the prompt is exactly
  `/tandem-backlog auto-triage --commit` and the environment variable
  `TANDEM_BACKLOG_LOOP_TRIAGE` is set (the loop started this session; the
  maintainer chose it with `loop-start.sh --auto-triage`). Maintainer mode
  for that one operation only, never for anything else in the session.
- **Agent mode**: any other case — you record a finding while implementing
  a feature, a reviewer agent reports something, another skill calls this
  one, or you are unsure. Allowed: `add`, `import-github`, `list`, `show`,
  `verify` (the `verified` stamp and a log line only), `log` (a log line on
  any item), `check`, and completing or correcting **the items you
  yourself created in this session**. **Forbidden: `triage`,
  `auto-triage`, `move`, `decide`, `park`, `reject`, `reopen`, `block`, `unblock`, `close`, and
  any change of the fields or the body of an item you did not create in
  this session** (FR-014). A finding that belongs to an existing item
  becomes a new item with `--related <slug>`. If a forbidden operation
  seems needed, say so in your report; do not do it.

### 0.4 Never

- Never write planned work anywhere under `specs/` (FR-001).
- Never edit the metadata header of `desc.md` or a table of `BACKLOG.md`
  by hand. Exception: the maintainer may reorder rows in `BACKLOG.md` by
  hand; afterwards run `BL sync`.
- Never rename an item folder; the slug never changes (titles may).
- Never post `reply.md` or anything else to GitHub.
- Never delete an item except by `close` (§2.15). A duplicate or a mistaken
  item is **rejected** with the reason `duplicate of <slug>` / `recorded by
  mistake`, so the record stays.
- A git conflict in `BACKLOG.md` (two branches each added a row at the same
  place): keep **both** rows, remove the conflict markers, run `BL sync`
  and `BL check`.

### 0.5 Every changing operation

1. **Before**: `BL check`. Not `TOTAL: 0` → maintainer mode: fix the
   findings first (reference.md §6) and say so; agent mode: report the
   findings and stop.
2. The operation.
3. **After**: `BL check` → must print `TOTAL: 0`. If not → maintainer
   mode: fix (reference.md §6) and repeat; agent mode: fix only findings on
   items you created in this session, report every other finding, stop.
4. The report (§3).

`list`, `show` and `check` change nothing and skip steps 1 and 3.

### 0.6 Reasons and dates

Every reason given to `--reason` has one form:
`'<why>; maintainer YYYY-MM-DD'` (maintainer mode, today's date) or
`'<why>; agent YYYY-MM-DD'`. A decision recorded in a log line:
`'maintainer decision YYYY-MM-DD: <decision>'`.

---

## 1. Choosing the operation

Take the first word of the input; Czech synonyms in brackets.

| Operation | Words | Section |
|---|---|---|
| `add` | add, new, record (přidej, zapiš, nový, založ) — also any input that just describes a problem / idea / finding | §2.1 |
| `import-github` | import, issue, `#N`, a github.com/…/issues/N link, "ai backlog", import all / new issues (naimportuj, nové issues) | §2.2 |
| `list` | list, what next (seznam, vypiš, co dál, co je v backlogu) | §2.3 |
| `show` | show (ukaž, detail) + a slug or a title | §2.4 |
| `triage` | triage (roztřiď, projdi inbox, třídění) — with a question per item | §2.5 |
| `auto-triage` | auto-triage, triage automatically, also the older form `triage auto` (roztřiď automaticky, automatické třídění) — without questions; `--dry-run` / "just show" (jen ukaž, nic neměň) = plan only; `--commit` = commit the result on `main` | §2.5a |
| `move` | move, put, reorder, up, down (přesuň, dej na místo, nahoru, dolů) | §2.6 |
| `update` | update, change, set (uprav, změň, nastav, doplň) | §2.7 |
| `verify` | verify, still valid? (ověř, platí ještě) | §2.8 |
| `decide` | decide, decision (rozhodni, rozhodnutí) | §2.9 |
| `park` | park, later (odlož) | §2.10 |
| `reject` | reject, won't do (zamítni, nebudeme dělat) | §2.11 |
| `reopen` | reopen (znovu otevři, obnov) | §2.12 |
| `block` | block, waits for (zablokuj, čeká na) | §2.13 |
| `unblock` | unblock (odblokuj, už to jde) | §2.14 |
| `close` | close, already fixed, obsolete (uzavři, už je opraveno, neplatí) | §2.15 |
| `check` | check, validate (zkontroluj) | §2.16 |

**Naming an item**: by slug, or by (part of) its title — resolve with
`BL list --json` (match the title, case-insensitive). Several match →
maintainer mode: ask which (one question, the candidates as options);
agent mode: stop and report the ambiguity. None → say so; do not guess.

Operation not determinable → maintainer mode: one question with the likely
operations as options; agent mode: do nothing and report.

---

## 2. Operations

### 2.1 `add <free text>` — record new items

One input may describe several things → one item per thing that would be
its own feature (reference.md §2).

**Step 1 — Gather facts.** From the input; when it names code, a feature,
a probe or a fix-log, read them so that *Evidence* is exact: `file:line`
**at a commit** (`git rev-parse --short HEAD`) plus the function name, the
fix-log section, the probe and its row. Do not invent facts; what you could
not check goes to *Notes* as "not verified".

**Step 2 — Look for an existing item.** `BL list --json`, and grep the item
texts for 2–3 distinctive words (file or function names, feature numbers,
the symptom):

```text
grep -ril -e '<word1>' -e '<word2>' backlog/items --include=desc.md
```

| Found | Maintainer mode | Agent mode |
|---|---|---|
| an item covering the same work | show it; ask: extend it (Edit its body, then `BL log <slug> 'extended: <what>'`) / add a new related item / do nothing | you created it in this session → extend its body; otherwise add a new item with `--related <slug>` and say in *Notes* how it relates |
| a `rejected` item on the same topic | show its reason; ask: a new reason (→ `reopen`, §2.12) or a new item | add a new item, `--related <slug>`; *Notes* says why it differs from the rejected one |
| nothing | continue | continue |

**Step 3 — Decide the fields** by reference.md §3: `type`, `severity`
(band + one-clause reason), `area`, `source`, `who`, `effort` (optional,
`?` if unknown), `related` / `depends-on` (existing slugs only).
Maintainer mode: if type, severity or area is genuinely unclear, ask
**one** question with your proposal as the first option. Agent mode: decide
yourself; put any doubt into *Notes*.

**Step 4 — Title and slug.** Title by reference.md §2 (English, the
symptom or capability, ≤ 80 characters, no trailing period, no backslash).
The slug is derived from the title (lowercase ASCII words, ≤ 60 chars); if
it would be unclear, pass `--slug <slug>` (lowercase letters, digits,
single hyphens).

**Step 5 — Create.**

```text
BL new --title '<title>' --type <type> --severity <0-10> --area <area> \
       --source <source> --who <agent|person|both> [--effort S|M|L|?] \
       [--related a,b] [--depends-on a,b] \
       --problem '<short>' --evidence '<short>' --expected '<short>'
```

The first output line is the slug. Exit 1 → §0.2 (two forms).

**Step 6 — Complete the body** of `backlog/items/<slug>/desc.md` with the
Edit tool: replace **every** `(to be written)`; write the full *Problem* /
*Evidence* / *Expected* (backslashes are safe here); add `## Approach` /
`## Notes` after *Expected* when useful; for `decision` write *Question*,
*Options* (A/B/… with consequences), *Recommendation*; for `person-step`
write *Steps* as `- [ ] …` lines, each a concrete check with the expected
result, and name the source (feature, `quickstart.md`, fix-log section) in
*Evidence*. Templates: reference.md §1. Do not touch the header or *Log*.

**Step 7 — Verify.**

```text
grep -n '(to be written)' backlog/items/<slug>/desc.md   → no output
BL check                                                 → TOTAL: 0
```

**Report** (one line per item):
`Added <slug> to Inbox — <title> (<type>, severity <n>, <area>, source <source>).`

### 2.2 `import-github <N>` / `import-github` (every new labelled issue)

With a number: one issue (A). Without a number — or "all", "new",
"všechny", "nové", "ai backlog" — every open issue labelled **`ai backlog`**
that the backlog has not held yet (B). The label is the maintainer's
opt-in on GitHub; the tool never changes labels, comments or issues there.

**A. One issue `<N>`**

1. `BL import-github <N> --area <area>` — `<area>`: the one the maintainer
   named, else `panels-ui` (corrected in step 3). Optional `--type`,
   `--severity` (defaults: type from the issue's labels, severity `5`).
   `refused: issue #<N> is already imported as '<slug>'` → report that
   slug; stop. Other refusals (network, comment count) → report them; stop.
2. Read `backlog/items/<slug>/issue.md` (the verbatim issue and comments).
3. Judge the issue and set its fields: **C** below.
4. `reply.md` stays `state: not-sent` with its placeholder unless the
   maintainer asks for a draft. Never post it.
5. `grep -n '(to be written)' backlog/items/<slug>/desc.md` → no output.

**Report:** `Imported #<N> as <slug> — <title> (<type>, severity <n>, <area>), in Inbox.`

**B. Every new issue labelled `ai backlog`**

1. `BL check` (§0.5 step 1).
2. `BL import-github --label 'ai backlog' --dry-run` — lists
   `would import #N [labels] as <type>, <area>: <title>` and
   `skipped #N: <why>` (a pull request; already an item; labelled `fixed` /
   `duplicate` / `invalid` / `wontfix`; imported before and since removed
   from the backlog — the git history says so). Nothing to import → report
   `No new issues labelled 'ai backlog'.` and the skipped lines; stop.
3. `BL import-github --label 'ai backlog'` — **one** command for all of
   them (never per issue in parallel). Output per issue
   `imported #N <slug>` / `skipped #N: …` / `failed #N: …`, last line
   `imported n, skipped n, failed n`. A `failed` issue whose title gives
   an existing slug or no slug (a title without ASCII letters, e.g.
   Cyrillic) → import it alone (A) with `--slug <English-slug>`; any other
   failure → report it. `check after the change found problems:` →
   §0.2 (never repeat the command).
4. For each `imported #N <slug>`: read its `issue.md`, then **C**, then
   A steps 4–5.
5. `BL check` → `TOTAL: 0`.

**Report:** a table `| Issue | Labels | → Item | Type | Sev | Area | Severity because |`
(one row per imported issue; *Item* is `<title> (<slug>)`), then the
`skipped` / `failed` lines verbatim, then
`<n> imported to Inbox, <n> skipped, <n> failed.`

**C. Judging an imported issue** (A step 3, B step 4)

1. From `issue.md` take the `labels:` line, the body and all comments:
   what the reporter sees, in which version, how often, and the reach
   (other people confirming it, "+1" comments, the issue's age).
2. Search for earlier work on it: `grep -n '#<N>\b' specs/FEATURE-HISTORY.md`
   and the symptom's words. A feature that already handled it does not
   close the item here: say so in *Notes* ("possibly fixed by NNN —
   verify"); `verify` (§2.8) decides.
3. Decide `type`, `severity`, `area` by reference.md §3, using the
   **GitHub labels** table there: the labels give the type and the scale,
   the **described consequence** gives the band (a label alone never moves
   an issue into a band).
4. Rewrite *Problem* / *Evidence* / *Expected* with the Edit tool in the
   backlog's own words, in English also when the issue is not (the
   original stays in `issue.md`); *Evidence* starts with the issue link
   and the reported version; *Expected* must not stay `(to be written)`.
   Add `## Notes` with the line
   `Severity <n>: <the band question that answered yes> - <reach>; GitHub labels: <labels>.`
   plus anything from step 2.
5. Set the fields — the title in English, shortened by reference.md §2
   (the import copies the issue title, often > 80 characters):

   ```text
   BL set <slug> type=<t> severity=<n> area=<a> 'title=<English, ≤ 80 chars>' --log 'fields set from the issue text and labels'
   ```

### 2.3 `list [filters]` (changes nothing)

| Request | Command |
|---|---|
| "what next?" / "co dál?" | `BL list --section next --json` → the first 10, plus the counts of *Decisions*, *Person steps*, *Inbox* (`BL list --section <s> --json`) |
| a section | `--section next\|decisions\|person\|inbox\|parked\|rejected\|progress` |
| an area / type / status / who | `--area A`, `--type T`, `--status S`, `--who W` |
| what waits for an item / refers to it | `--needs <slug>` / `--related-to <slug>` |
| "important" / "severe" | `--min-severity 7` (or the number given) |

**Report:** a Markdown table in backlog order
`| # | Section | Sev | Type | Area | Status | Source | Item |` where *#* is
the position in an ordered section (`-` in *Inbox*, *Parked*, *Rejected*),
*Source* is the item's `source` field as stored (`github#5`, `review:212`,
`leftover:125`, ...) and *Item* is `<title> (<slug>)`; then the line
`<n> items`.

### 2.4 `show <slug or title>` (changes nothing)

**Report:** the title; the line
`section <S>, position <p or ->, status <s>, severity <n>, type <t>, area <a>, who <w>, source <src>, created <d>, verified <v>`;
the body sections verbatim (*Problem* … *Log*); then
`Files: issue.md, reply.md (<state line>), evidence/<names>` for those
present, or `Files: -`.

### 2.5 `triage` (maintainer mode only)

Goal: every *Inbox* item gets a place, or explicitly stays in *Inbox*.

1. `BL list --section inbox --json` (oldest first) and
   `BL list --section next --json`. *Inbox* empty → report `Inbox is
   empty.` and stop.
2. For each *Inbox* item show, in 3–6 lines: title, type, severity and its
   band, area, source, the first two sentences of *Problem*, and the
   current top 5 of *Next* (position, title, severity).
3. Ask with the question tool — **one call, two questions**:
   - "Where does `<slug>` go?" — options, your recommendation first:
     `Next at position <p> (Recommended)` (p: just above the first row with
     a lower severity), the fitting one of `Decisions for the maintainer` /
     `Person steps`, `Parked`, `Rejected`. The automatic "Other" lets the
     maintainer type a position, "leave in Inbox" or "stop". The
     recommendation is the place `auto-triage` would choose (reference.md
     §4.1); an item whose fault lies only in code that is not shipped
     (rule A there) is recommended `Parked` with the rule's reason.
   - "Severity of `<slug>`?" — `<proposed> (Recommended)`, `<proposed+1>`,
     `<proposed-1>`.
4. Apply, in this order:
   1. severity changed → `BL set <slug> severity=<n> --log 'triage: severity <n>'`;
   2. the target needs another type / who (a person is needed →
      `who=person` and `type=person-step`; a question for the maintainer →
      `type=decision`) → `BL set <slug> type=<t> who=<w> --log 'triage'`;
      if it prints `added the sections … with placeholders`, write those
      sections now with the Edit tool (*Steps* from the item and the
      maintainer's answer, one `- [ ]` line per check) and confirm
      `grep -n '(to be written)' …` prints nothing;
   3. move: `Next` / `Decisions` / `Person steps` →
      `BL move <slug> --section next|decisions|person --position <p>`;
      `Parked` / `Rejected` → ask for the reason if not given (one short
      question), then for `Rejected` follow §2.11 (dependents first), for
      `Parked` `BL move <slug> --section parked --reason '<why>; maintainer YYYY-MM-DD'`;
      "leave in Inbox" → nothing; "stop" → end the triage.
5. `BL check` → `TOTAL: 0` after each item.

**Report:** a table `| Item | → Section | Position | Severity |`, then
`<n> items remain in Inbox.`

### 2.5a `auto-triage [--dry-run | --commit]` (maintainer mode only)

Goal: every *Inbox* item gets the place the rules of reference.md §4.1
give it, **without questions**; an item the rules cannot place with
certainty stays in *Inbox* with a log line saying why, for the next
interactive `triage`. An item whose fault lies only in code that is not
built or shipped (an `off` plug-in, an `off` language, a file no project
compiles) never enters a queue — it is **parked** with a reason that says
what brings it back. `auto-triage` never rejects, closes, decides, blocks
or unblocks, and never edits an item's body.

1. §0.2 (lock and loop status) and §0.5 step 1 (`BL check`). From the
   loop (*From the loop* below) the loop's status is expected, not a
   reason to stop.
2. Read the inputs **now**, never from memory:
   - `BL list --section inbox --json` (oldest first — the processing
     order); *Inbox* empty → report `Inbox is empty.` and stop;
   - `BL list --section next --json`, `--section decisions`,
     `--section person`;
   - `plugins.cfg` (the `off` plug-ins) and `translations/languages.cfg`
     (the languages with `enabled = off`).
3. **Plan.** For each *Inbox* item read `backlog/items/<slug>/desc.md`
   (header, *Problem*, *Evidence*, *Notes*) and walk the rules of
   reference.md §4.1 in order; the first rule that applies gives the
   target. Rule A (not shipped) needs the check written there — every code
   site of *Evidence* located, not a guess from the title alone. Then
   check the severity by reference.md §3: keep the recorded value unless
   the item's own text describes a consequence of another band (say which
   band question answers yes); unsure → keep it. The plan row:
   `slug, target, position rule, severity (old → new or =), why`.
4. `--dry-run` → report the plan (the *Report* table below with the
   position the rule would give now) and stop; nothing is written.
5. **Apply**, item by item in the plan's order, **one command at a time**:
   1. severity changed → `BL set <slug> severity=<n> --log 'auto-triage: severity <old> -> <n>: <band reason>'`;
   2. target *Parked* →
      `BL move <slug> --section parked --reason '<rule A reason>; auto-triage, maintainer YYYY-MM-DD'`;
   3. target *Next* / *Decisions* / *Person steps* → read that section
      again (`BL list --section <s> --json`; earlier moves have shifted
      it), compute the position by reference.md §4.1 *Position*, then
      `BL move <slug> --section next|decisions|person --position <p>`;
   4. stays in *Inbox* → `BL log <slug> 'auto-triage: left in Inbox - <why>'`,
      unless the item's last log line already says the same;
   5. `BL check` → `TOTAL: 0`. A `refused:` → the item stays in *Inbox*;
      put the refusal into the report and continue with the next item.
      `check after the change found problems:` → §0.2 (never repeat),
      fix by reference.md §6, then continue.
6. `BL check` → `TOTAL: 0`.
7. `--commit` only: `git status --porcelain` must list only paths under
   `backlog/` (anything else → do not commit; say so in the report);
   nothing changed → no commit. Else `git add backlog` and
   `git commit -m 'backlog: auto-triage - <n> placed, <n> parked, <n> left in Inbox' -m '<the attribution lines the session's instructions give for commits>'`.
   Never push.

**From the loop** (`loop-start.sh --auto-triage`, feature 247). The loop
runs `claude -p '/tandem-backlog auto-triage --commit'` between two runs,
whenever the *Inbox* holds an item its last triage did not see, with
`TANDEM_BACKLOG_LOOP_TRIAGE` set to the loop's pid. Then:

- Step 1: `echo "$TANDEM_BACKLOG_LOOP_TRIAGE"` and
  `python tools/backlog/loop.py status`. Proceed only when it shows
  `loop:    running (pid <that number>,` (with the comma: pid 123 must
  not match 1234) and `state:   triage`, the lock is
  `free`, the branch is `main` and `git status --porcelain` is empty.
  Otherwise change nothing and end with
  `Outcome: refused (<what did not match>)`.
- No questions (there is nobody to answer them): what §2.5a would ask
  about is left in *Inbox* by rule B.
- Step 7 (`--commit`) is required: the loop starts the next run only on a
  clean tree on `main`; a tree left changed stops the loop for a person.
- End with the report; the loop reads the outcome from git, not from the
  text.

**Report:** a table `| Item | → Section | Position | Severity | Why |`
(*Item* is `<title> (<slug>)`; *Severity* `n` or `old → n`; *Why* is the
rule and, for *Parked* and *Inbox*, the reason), grouped: placed, parked,
left in Inbox; then `<n> placed, <n> parked, <n> left in Inbox.` With
`--dry-run` the table is headed `Plan (nothing changed):`.

### 2.6 `move <item> <section> [position]` (maintainer mode only)

1. Read the current section and position: `BL list --json` (the item's
   entry).
2. `BL move <slug> --section <next|decisions|person|inbox|parked|rejected> [--position <p>] [--reason '<why>; maintainer YYYY-MM-DD']`
   - position 1 = top; omitted = end; only in *Next*, *Decisions*,
     *Person steps*; "up / down by n" = current position ∓ n (at least 1);
   - the tool sets the status the section implies (reference.md §5);
     moving never unblocks (use §2.14);
   - `refused: … belongs in '<S>', not '<T>'` → ask the maintainer whether
     to change type / who (`BL set`, then follow §2.5 step 4.2) or to use
     `<S>`;
   - *Parked* / *Rejected* and leaving them need `--reason`; *Rejected*:
     follow §2.11; *In progress* is never a target.
3. Read the new position: `BL list --json`.

**Report:** `<slug>: <old section> #<old> → <new section> #<new>` (`#-` in
unordered sections).

### 2.7 `update <item> <changes>`

- Header fields (not `status`, not `updated`):
  `BL set <slug> key=value [key=value …] --log '<why>'`. Lists:
  `related=a,b` (empty: `related=[]`). A change of `type` or `who` moves
  the row to the section that fits (the tool prints `moved to …`); a new
  type's sections are added with placeholders (the tool prints `added the
  sections …`) — write them with the Edit tool and confirm with
  `grep -n '(to be written)'`.
- Title: `BL set <slug> 'title=<new title>'` (the body's first line
  follows; the slug stays).
- Body: the Edit tool on the sections, then
  `BL log <slug> '<what changed, one line>'`.
- Agent mode: only items you created in this session.

**Report:** `Updated <slug>: <changes>.`

### 2.8 `verify <item>`

Goal: does the item still describe reality at HEAD?

1. Read *Evidence*; locate each cited site at HEAD (search by function or
   text, not by line number); run the cited probe or test if it takes less
   than a few minutes; for a defect, reason whether it is still reachable.
2. Outcome:

| Finding | Command (maintainer mode, or your own item) | Agent mode, another's item |
|---|---|---|
| still true | `BL verify <slug> --note '<how confirmed, where>'` | the same |
| true, the evidence moved | Edit *Evidence* (new `file:line` at the commit), then `BL verify <slug> --note 'evidence updated'` | `BL log <slug> 'evidence moved: <old> -> <new file:line at commit>'`, then `BL verify <slug> --note 'still true'` |
| no longer true | `BL verify <slug> --note 'not reproduced: <what you found>'`; then propose `close` (§2.15: name the commit or feature that fixed it) and ask | the `verify` line only; report it |
| needs a person | `BL log <slug> 'verify: needs a person - <why>'` | the same |

**Report:** `<slug>: <still true | evidence updated | not reproduced | needs a person> at <commit>.`

### 2.9 `decide <item> <decision>` (maintainer mode only, type `decision`)

1. List the dependents first: `BL list --needs <slug>`.
2. `BL log <slug> 'maintainer decision YYYY-MM-DD: <decision in one sentence>'`
3. Then exactly one of:
   - **do the work** → rewrite *Problem* / *Expected* (and *Approach*) for
     the chosen option with the Edit tool; keep *Question* / *Options* /
     *Recommendation* as the record of the decision;
     `BL set <slug> type=<bug|feature|improvement|tech-debt> [who=…] [severity=…] --log 'decision converted to work'`
     (the row moves to *Next* or *Person steps*); ask for the position;
     `BL move <slug> --section next --position <p>`.
   - **answered — nothing to change / will not be done** → the decision is
     done: `BL remove <slug> --reason 'decided YYYY-MM-DD: <decision>; maintainer'`
     (dependents are logged and may start). Then, for each dependent from
     step 1, ask the maintainer: keep it, or reject it (§2.11).
   - **later** → `BL move <slug> --section parked --reason '<why later>; maintainer YYYY-MM-DD'`
     (dependents keep waiting).

**Report:** `<slug>: decided — <decision>; now <section | closed>; dependents: <slugs or none>.`

### 2.10 `park <item> <reason>` (maintainer mode only)

`BL move <slug> --section parked --reason '<why later, what would bring it back>; maintainer YYYY-MM-DD'`

**Report:** `<slug>: <old section> → Parked — <reason>.`

### 2.11 `reject <item> <reason>` (maintainer mode only)

1. Dependents: `BL list --needs <slug>`. Any listed → do not reject yet: for each dependent ask the maintainer —
   reject it too (this procedure, first), or drop the dependency
   (`BL set <dependent> depends-on=<the rest or []> --log 'dependency <slug> rejected'`).
2. `BL move <slug> --section rejected --reason '<why not>; maintainer YYYY-MM-DD'`

A reject reason must let a future reader judge whether a new argument is
really new. `reject` is "decided not to do" — an item already done or no
longer reproducible is **closed** (§2.15); an answered decision is closed
or converted (§2.9).

**Report:** `<slug>: <old section> → Rejected — <reason>; dependents: <handled as … | none>.`

### 2.12 `reopen <item> <new reason>` (maintainer mode only)

`BL move <slug> --section next|decisions|person|inbox [--position <p>] --reason '<the NEW reason>; maintainer YYYY-MM-DD'`

Without a reason that the old rejection did not already answer: refuse and
say why. **Report:** `<slug>: <Parked|Rejected> → <section> #<p> — reopened: <reason>.`

### 2.13 `block <item> <what it waits for>` (maintainer mode only)

`BL block <slug> --reason '<what it waits for>; maintainer YYYY-MM-DD'` —
only an `open` item; the row stays where it is. **Report:**
`<slug>: blocked — <reason>.`

### 2.14 `unblock <item>` (maintainer mode only)

`BL unblock <slug> --note '<what changed>'` — the row stays, status
`open`. To also move it: unblock first, then §2.6. **Report:**
`<slug>: unblocked — <what changed>.`

### 2.15 `close <item>` (maintainer mode only)

For an item **already done** (fixed by another feature or commit) or
**obsolete** (the code it described is gone), confirmed by §2.8:

1. Dependents and relations: `BL list --needs <slug>` and
   `BL list --related-to <slug>`.
2. A `github#N` item: tell the maintainer that issue #N still needs an
   answer and where `reply.md` stands (copy its draft into the report).
3. `BL verify <slug> --note '<the evidence that it is done / obsolete>'`
4. `BL remove <slug> --reason '<fixed by feature NNN | fixed by <commit> | obsolete: <why>>; maintainer YYYY-MM-DD'`

An `in-progress` item is refused (only its run closes it). **Report:**
`<slug>: closed — <reason>; dependents updated: <slugs from step 1 or none>.`

### 2.16 `check` (changes nothing unless fixes are applied)

`BL check`. For each finding, the fix from reference.md §6. Maintainer
mode: apply the fixes that need no decision, then `BL check` again; ask
about the rest. Agent mode: report only.

**Report:** one line per finding
`<rule> <slug or file>: <fix applied | needs the maintainer: <what>>`, then
`BL check: TOTAL: <n>`.

---

## 3. The report

The report is exactly: the operation's *Report:* line(s) as given above;
then the line `BL check: TOTAL: 0` (or the findings that remain and why)
for changing operations; then, in agent mode, the line
`New items wait in Inbox for the maintainer's triage.` when items were
added. Nothing else.
