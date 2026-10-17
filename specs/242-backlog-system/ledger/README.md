# Migration of the old backlog (feature 242, tasks T026–T034)

Sources (snapshot at `7993914c`):
- `NEXT-WORK.7993914c.md` in this folder (copy of `specs/NEXT-WORK.md`);
- `specs/068-encoding-regression-review/REMAINING-WORK.md`,
  `specs/069-finish-encoding-fixes/REMAINING-WORK.md`,
  `specs/070-source-viewer-plugin/REMAINING-WORK.md`,
  `specs/072-winget-distribution/REMAINING-WORK.md`,
  `specs/080-restart-manager-upgrade/REMAINING-WORK.md`.

Each migration part produces two files here:

- `<part>.md` — the ledger part: one table row per entry of the source,
  **open or closed**, so that completeness can be reviewed:

  ```markdown
  | Source | Destination |
  |---|---|
  | NW §A.11 "Renamer regex engine judges \b by bytes" (L235) | item:renamer-regex-single-byte-classes |
  | NW §A.5c "viewer Copy to File overwrites by deleting first" | done (feature 173) |
  ```

  *Source*: `NW` (NEXT-WORK) or `RW068`…`RW080`, the section / label, a
  quote of the first words, the line number. *Destination*, one of:
  `item:<slug>` (an item of this part), `merged:<slug>` (folded into another
  item of this part), `see <label>` (the same entry is covered by another
  part — name the label, e.g. `see NW §D code work "parent of a share's
  root"`), `release-checklist`, `done (feature NNN)`,
  `not migrated: <reason>`.

- `<part>.items.json` — the items of this part, a JSON array:

  ```json
  {
    "slug": "renamer-regex-single-byte-classes",
    "title": "Renamer: regular expressions judge \\b, \\w, classes and '.' by single bytes",
    "type": "bug",
    "severity": 4,
    "area": "other-plugins",
    "source": "review:210",
    "who": "agent",
    "effort": "M",
    "created": "2026-10-16",
    "verified": "-",
    "section": "next",
    "status": "open",
    "reason": "-",
    "order": 12,
    "related": [],
    "depends-on": [],
    "problem": "…",
    "evidence": "…",
    "expected": "…",
    "approach": "",
    "notes": "",
    "question": "", "options": "", "recommendation": "",
    "steps": [],
    "log": [["2026-10-16", "maintainer: stays in the backlog (severity about 3/10)"]]
  }
  ```

## Rules

- Read your whole source range; do not skim. Entries are often inside long
  paragraphs: a struck-through (`~~…~~`) or "done, feature NNN" passage is
  closed, but the same paragraph may carry "Left: …" / "left by its review:"
  parts that are still open — those are the items.
- **One item = one feature's worth of work.** Group small related open
  leftovers of the same area into one item (list them in *Problem*); do not
  make an item per sentence. Do not merge unrelated things to save items.
- Values must come from the legend of `backlog/BACKLOG.md`:
  - `type`: bug, feature, improvement, tech-debt, decision, person-step
  - `area`: build-release, translations, encoding, long-paths, file-ops,
    data-safety, panels-ui, viewer, archives, plugin-api, webview,
    privacy-security, ftp, sftp, pictview, other-plugins, help-docs, tooling
  - `who`: agent, person, both · `effort`: S, M, L, ?, -
  - `source`: `review:NNN`, `leftover:NNN`, `measure:NNN`, `probe:NNN`,
    `github#N` when the text names the origin; otherwise `next-work`
  - `severity` 0–10 by the anchors: 9–10 data loss / crash in a common
    scenario; 7–8 data loss narrow / crash unusual; 4–6 function broken with
    a workaround; 1–3 cosmetic; 0 trivial. Features / improvements:
    importance. When the source states a severity ("about 3/10"), use it.
- `section` / `status`: work an agent can do → `next` / `open`;
  a question for the maintainer → `type: decision`, `decisions` / `open`;
  needs a person (real keyboard, clipboard, mouse, printer, server, other
  machine, admin, release step) → `type: person-step`, `who: person`,
  `person` / `open`, with `steps`; decided not to do → `rejected` with
  `reason` (the decision, its date and who); recorded "deliberately not on
  the list" / "parked" / "not reproduced" → `parked` with `reason`; waiting
  for something outside (e.g. the winget PR) → status `blocked` with
  `reason`, in its section.
- `order`: for `next`, `decisions`, `person`: the entry's order in the
  source (1, 2, …); otherwise 0.
- `slug`: lowercase ASCII words joined by `-`, ≤ 60 characters, derived
  from the title; unique within your part.
- `created`: the date the entry was first recorded if the text states or
  implies it (e.g. "found by 182's sweep" → the date of feature 182 if
  stated nearby, "added 2026-10-13"), else `2026-10-17`. `verified`: `-`
  unless the text records a check of the site at a commit
  ("verified still present at `f4cefa1`" → `2026-09-02 f4cefa1` with the date
  if known).
- `related` / `depends-on`: slugs **of your own part only**; mention
  relations to other parts in `notes`.
- *Evidence* must let a later agent re-check the item in minutes: file and
  approximate line as the source gives them, the feature folders and
  fix-log sections it cites, and "Migrated from specs/NEXT-WORK.md §X (at
  7993914c)".
- *Log*: dated maintainer decisions and other dated facts from the source
  (`["2026-10-16", "maintainer: stays in the backlog …"]`). The importer
  adds "migrated from …" itself.
- Write English. Keep the source's precision (file names, numbers,
  measurements); do not invent facts; if unsure whether an entry is still
  open, make the item and say so in `notes` (a later `verify` settles it).
- Do not edit anything outside this folder; do not run the backlog tool.
