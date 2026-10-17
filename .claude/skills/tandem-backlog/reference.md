# tandem-backlog — reference

Sections: §1 item templates · §2 writing rules · §3 decision tables for the
fields · §4 triage guidance · §5 sections and statuses · §6 check findings
and refusals → fix.

---

## §1 Item templates

The tool writes the header and the skeleton; you write the body. The header
(never edit it by hand) looks like this:

```markdown
---
title: Packing a folder with a too long name fails silently
type: bug
status: new
severity: 6
area: archives
source: review:241
who: agent
created: 2026-10-17
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---
```

### Work item (`bug`, `feature`, `improvement`, `tech-debt`)

```markdown
# Packing a folder with a too long name fails silently

## Problem

F5 of a folder whose name has 255+ bytes into a ZIP "succeeds" and packs
nothing; the user is not told.

## Evidence

`src/fileswn7.cpp` ~1960 at 7993914c: `ReadDirectoryTree` returns
`SALENUM_ERROR` without a message. Found by the review of feature 241
(`specs/241-pack-long-nested-folder/fix-log.md`, *Review*).

## Expected

The operation stops with "too long name" naming the folder; nothing is
packed half.

## Approach

Return `SALENUM_CANCEL` after the message, as 241 did for the nested case;
measure first with `pack241_probe.ps1`.

## Notes

Not verified on a network share.

## Log

- 2026-10-17 — created (source review:241)
```

### `decision`

```markdown
## Question

Should the Network plug-in (`nethood`) ship enabled?

## Options

- **A — keep it off.** The core's share list (feature 125) answers
  `\\server\`; nothing changes for users who never had it.
- **B — enable it.** Restores the `net:` panel; costs: leak reports at exit,
  `..` from every share root leads to `net:`, code-page residue, texts still
  say "Salamander", `PRIVACY.md` changes.

## Recommendation

A, until the plug-in's shutdown and encoding defects are fixed (they would
be items of their own).
```

Sections order: *Problem*, *Evidence*, *Expected*, [*Approach*],
[*Notes*], *Question*, *Options*, *Recommendation*, *Log*.

### `person-step`

```markdown
## Steps

- [ ] Slovak UI: Ctrl+C / Ctrl+V of `a.txt` in its own folder → the copy is
      named `a - Kópia.txt`.
- [ ] Czech UI: the title of a queued Copy reads `(čekající) Kopírovat …`.
```

Each step: what to do, where, and the expected result. *Evidence* names the
origin: feature, `specs/NNN-*/quickstart.md` section or fix-log section.
Sections order: …, [*Notes*], *Steps*, *Log*.

---

## §2 Writing rules

- **English.** Precise, short sentences. Keep numbers, file names,
  function names, probe names, feature numbers exactly.
- **Title**: ≤ 80 characters, the symptom or the capability in the user's
  terms ("Packing a folder with a too long name fails silently"), not the
  function name ("Fix ReadDirectoryTree"). No trailing period. Plug-in
  names as the user sees them (PictView, Registry Editor, Disk Map).
- **Problem**: who is affected, what they do, what goes wrong (or what is
  missing). One paragraph. A list only when several small findings of one
  origin are grouped.
- **Evidence**: everything a later agent needs to re-check it in minutes —
  `file:line` *at a commit* (line numbers move; add the function name), the
  fix-log section, the probe and its row, the measurement, the issue link.
  If it was not reproduced, say "by reading" or "suspected".
- **Expected**: the finished state, testable ("refused with …", "the probe
  row X passes").
- **Approach** (optional): the fix idea, its risks, what to measure first.
- **Notes** (optional): doubts, relations to other items, "not verified".
- **One item = one feature's worth of work.** Several small findings of the
  same origin and area → one item with a list in *Problem*. Unrelated
  things never share an item. A finding that needs both code and a person's
  check → a work item (`who: both`) whose *Notes* name the person's part.

---

## §3 Decision tables for the fields

### type

| The item is … | type |
|---|---|
| the program does something wrong (also: wrong text, crash, data loss, leak) | `bug` |
| a new capability the user can use | `feature` |
| an existing capability made better (speed, clearer message, more cases) | `improvement` |
| internal work without a direct user-visible change (refactoring, tooling, probes, records, CI) | `tech-debt` |
| a question only the maintainer can answer (policy, public claim, product direction, a trade-off) | `decision` |
| a check or action needing a person: real keyboard / mouse / clipboard / IME, a printer, a real server, another machine or OS, admin rights, a release or catalogue step | `person-step` (always `who: person`) |

### area (first matching row wins)

| The item is mainly about … | area |
|---|---|
| a data-loss guard: same-file identity, safe replace, links/junctions, delete-before-move | `data-safety` |
| PictView | `pictview` |
| FTP plug-in | `ftp` |
| SFTP plug-in | `sftp` |
| the ZIP or 7-Zip plug-in, archives in the core, the disk cache, external archivers, TAR/UnISO… listings of archives | `archives` |
| the plug-in interface, loading, version, closing for an update (Restart Manager) | `plugin-api` |
| any other plug-in (Registry Editor, Renamer, Undelete, Disk Map, Checksum, File Comparator, PE Viewer, Code Viewer, Portables, UnISO…) | `other-plugins` |
| the shared WebView2 host | `webview` |
| network communication, credentials, `PRIVACY.md`, the new-version check | `privacy-security` |
| long paths or names, buffer sizes, "refuse instead of cut" | `long-paths` |
| UTF-8 / WTF-8, code-page residue, mojibake, text in controls and titles | `encoding` |
| copy / move / delete / rename / attributes in the core | `file-ops` |
| panels, menus, dialogs, keyboard, command line, User Menu, shortcuts, UNC navigation | `panels-ui` |
| the built-in viewer | `viewer` |
| translation pipeline, language files, clipped labels in translations | `translations` |
| build, signing, installer, winget, CI, releases | `build-release` |
| the manual, README, architecture and project documents, `CLAUDE.md` | `help-docs` |
| probes, checkers, scripts, the backlog itself | `tooling` |

### severity (0–10)

Answer in order; the first "yes" gives the band, then pick within it by
reach (how many users, how often).

| Question | Band |
|---|---|
| Can a user lose data or does the program crash **in a common scenario** (default settings, ordinary names and paths)? | 9–10 |
| Can a user lose data in a **narrow** scenario (special names, re-pointed drives, network shares, rare settings), or does it crash in an unusual one? | 7–8 |
| Does a function not work (wrong result, refused wrongly, unusable text) but a workaround exists? | 4–6 |
| Is it cosmetic: wording, layout, a clipped label, an untranslated text that is still readable? | 1–3 |
| Is it trivial (internal tidiness, nobody notices)? | 0 |

For `feature` / `improvement`: importance on the same scale (9–10 = users
cannot do a common task without it; 1–3 = nice to have). For
`person-step`: how much an unverified state risks (a check guarding a data
-loss fix = 6+). For `decision`: the severity of what waits on it. Unsure →
the lower value, and the reason in *Notes*. When the source states a
severity ("about 3/10"), use it.

### GitHub labels (imported issues, SKILL.md §2.2 C)

The labels say what kind of report it is; the band always comes from the
consequence the issue describes (the questions above). Reach within the
band: one reporter, rare setup → the lower end; several people confirming,
default settings → the upper end.

| Labels | type | severity |
|---|---|---|
| `bug` | `bug` | the band of the described consequence: crash or data loss 7–10, a function that does not work 4–6, cosmetic 1–3 |
| `enhancement` | `feature` (a new capability) or `improvement` (an existing one made better) | importance: 9–10 only when users cannot do a common task without it; a usual request 2–5; nice to have 1–2 |
| `bug` + `enhancement` | by the text: the program does something wrong → `bug` (and the bug band); it works as designed but the user wants more → `feature` / `improvement` | as for that type |
| `documentation` | `improvement` (user-facing manual / help) or `tech-debt` (project documents); area `help-docs` | 1–3, higher only when missing text makes a function unusable |
| `question` | `decision` when only the maintainer can answer it (policy, direction); a question showing a defect → `bug` | as for that type |
| `help wanted`, `good first issue` | no effect | no effect |
| `in progress` | no effect; *Notes*: "in progress on GitHub" and the feature or branch, if one is found | no effect |
| `fixed`, `duplicate`, `invalid`, `wontfix` | not imported by `--label` (skipped); imported by number only on request | — |
| `ai backlog` | the opt-in for the import; no effect | no effect |

### who

| The work … | who |
|---|---|
| can be done and verified by an agent alone (code, hidden-desktop probes, documents) | `agent` |
| is code an agent can do, but one check needs a person | `both` |
| needs a person for its main part | `person` |

### effort (optional)

`S` hours · `M` about a day · `L` several days or a feature series · `?`
unknown · `-` not estimated.

### source

| Origin | source |
|---|---|
| the maintainer (or you at their request) | `manual` |
| GitHub issue N (`import-github`) | `github#N` |
| an independent review of feature NNN | `review:NNN` |
| feature NNN deliberately left it open | `leftover:NNN` |
| measuring during feature NNN found it | `measure:NNN` |
| a probe of feature NNN shows it | `probe:NNN` |
| migrated from `specs/NEXT-WORK.md` without a known origin | `next-work` (migration only) |

`NNN` is always three digits (`review:082`). Two items must not share one
`github#N` — a second item from the same issue uses `leftover:NNN` of the
feature that handled it, or `manual`, and cites the issue in *Evidence*.

### related / depends-on

- `related`: items a reader of this one should also read. Symmetric links
  are welcome but not required.
- `depends-on`: items that must be **finished (removed)** before this one
  can start; an autonomous run skips an item whose dependency is still in
  the backlog. Never depend on a `rejected` item (the check refuses it).

---

## §4 Triage guidance

- **Next** — work an agent can do (`who` agent or both, not a decision, not
  a person step). Order by *cost to users × cost to us*: data loss first,
  then crashes, then functions that do not work, then cosmetics; a cheap
  item (`effort: S`) may go above a costly one of the same band. An item
  whose `depends-on` is still open goes below its dependency.
- **Decisions for the maintainer** — `type: decision`; items that depend on
  a decision wait for it.
- **Person steps** — `who: person` or `type: person-step`. Order: checks
  that guard data-loss fixes and release blockers first.
- **blocked** (stays in its section, column *Status*) — cannot proceed
  *now* for a stated reason (waits for an external PR, a decision, a
  server; "not reproduced at <commit>"). Revisit at every triage.
- **Parked** — wanted some day, deliberately not now; the reason says what
  would bring it back.
- **Rejected** — decided not to do; the reason states the decision, who and
  when, so that re-opening needs a *new* reason.

---

## §5 Sections and statuses

| Section | Status set by `move` | Admits (the tool refuses others) |
|---|---|---|
| In progress | `in-progress` (only `start`) | — |
| Next | `open` (a `blocked` item stays `blocked` — `unblock` it explicitly) | who `agent`/`both`, type not `decision`/`person-step` |
| Decisions for the maintainer | `open` (or stays `blocked`) | type `decision` |
| Person steps | `open` (or stays `blocked`) | who `person` or type `person-step` (not `decision`) |
| Inbox | `new` (reason cleared) | anything |
| Parked | `parked` + reason | anything |
| Rejected | `rejected` + reason | anything |

`block <slug> --reason '…'` / `unblock <slug>` change `open` ↔ `blocked`
without moving the row. Moving an item **out of** *Parked* or *Rejected*
(to any section, *Inbox* too) needs `--reason` — the new reason. *Last
triaged* is set by every `move` except a move to *Inbox*. An item done or
obsolete leaves the backlog by `BL remove <slug> --reason '…'` (SKILL.md
§2.15), never by `reject`.

---

## §6 Check findings and refusals → fix

Exit 1 output starting with `refused:` → nothing was written, fix and
repeat. Output with `check after the change found problems:` → the change
**was written**; do not repeat the command; fix the findings listed below.
Agent mode fixes only findings on items it created in this session.

| Finding (`rule`) or refusal | Meaning | Fix |
|---|---|---|
| `derived` | a derived cell or a row number differs from the items | `BL sync` |
| `overview` "row without an item link" | a hand-written note row in a table (kept by the tool; `sync` refuses while it exists) | maintainer mode: turn the note into an item (SKILL.md §2.1), then delete the note row by hand and `BL sync`; agent mode: report it |
| `overview` (other) | a section heading, table, row or the legend is malformed | restore the structure from `contracts/overview-format.md` (`git diff backlog/BACKLOG.md` shows what changed), then `BL sync` |
| `orphan` | an item has no row | `BL move <slug> --section <the section its status implies, §5>` adds the row: a `new` item → `--section inbox`; `parked` / `rejected` → add `--reason '<the reason from its header>'`; `in-progress` → see the next row. If a hand edit lost several rows, `git diff backlog/BACKLOG.md` first and restore the file |
| an `in-progress` item on `main` (a stopped run's branch merged by hand) | the run that started it did not close it | the maintainer: when the merged work finished the item, `BL remove <slug> --feature <NNN>` (NNN = its `feature`); otherwise `BL block` is impossible (not `open`) — ask the maintainer and report |
| `dangling` | a row names a missing item | if the item was removed by mistake: `git checkout backlog/items/<slug>`; otherwise delete that row by hand and `BL sync` |
| `duplicate` | an item is listed twice | delete the extra row by hand, `BL sync` |
| `section` | the item's status / type / who does not fit its section | `BL move` it to the right section, or `BL set` the type / who |
| `header` | the header is malformed (not UTF-8, a BOM, a broken line, keys missing or out of order) — the tool refuses to touch the item | `git diff backlog/items/<slug>/desc.md`; `git restore backlog/items/<slug>/desc.md` (or `git checkout -- …`) to the last good version, then redo the intended change with `BL set` |
| `value`, `required` | a value is not allowed, or `reason` / `feature` does not fit the status | `BL set <slug> key=value` with a value from §3 / the legend; a status problem: `BL move` / `block` / `unblock` |
| `body` | a required section is missing, out of order, or a log line is malformed | edit the body (templates §1); log lines are `- YYYY-MM-DD — text` with an em dash |
| `ref`, `cycle` | `related` / `depends-on` names a missing / rejected item or forms a cycle | `BL set <slug> depends-on=…` / `related=…` |
| `github` | `github#N` without `issue.md`, or two items with the same issue | re-import the text (`issue.md` first line `number: N`) or change the second item's source |
| `feature-missing` | an in-progress item's `specs/NNN-*` folder is missing | only `/tandem-backlog-implement` handles in-progress items; report it |
| `layout`, `slug`, `desc-missing` | unexpected files or folders | move stray files out of `backlog/`; a wrongly named folder is a hand-made item — recreate it with `BL new` and delete the folder |
| `runs` | `RUNS.md` malformed | `git checkout backlog/RUNS.md` unless a run is in progress; report |
| `refused: item '<slug>' already exists (…)` | the title derives an existing slug | a duplicate? (§2.1 step 2); otherwise `--slug <other-slug>` |
| `refused: the title gives no slug` | the title has no ASCII letters or digits | pass `--slug` |
| `refused: invalid values: …` | a value is not in the legend | §3 tables; the legend in `BACKLOG.md` is authoritative |
| `refused: '<slug>' … belongs in '<S>', not '<T>'` | `move` to a section that does not fit | change type / who with `BL set` (maintainer's decision) or choose `<S>` |
| `refused: moving to 'Parked' needs --reason` / `reopening … needs --reason` | | give the reason |
| `refused: only 'start' moves an item to 'In progress'` | | not this skill's job |
