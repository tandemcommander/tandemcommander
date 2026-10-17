# Contract: Item format (`backlog/items/<slug>/desc.md`)

Binding for the tool (`tools/backlog/backlog.py`), both skills and people.

## File

UTF-8 without BOM. Starts with the metadata header, then the body.

## Metadata header

Exactly these keys, exactly this order, one per line, between `---` lines.
No comments, no quotes, no blank lines inside. Value = text after the first
`": "`. Lists in flow form.

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
verified: 2026-10-17 7993914c
effort: M
feature: -
related: []
depends-on: [ftp-per-server-encoding]
reason: -
---
```

| Key | Allowed | Notes |
|-----|---------|-------|
| title | one line, non-empty; no control characters (also for `reason`) | shown as the link text in `BACKLOG.md` |
| type | legend *Types* | |
| status | legend *Statuses* | `done` does not exist — a done item is removed |
| severity | integer 0–10 | legend *Severity* gives the anchors |
| area | legend *Areas* | |
| source | legend *Sources* | `github#N`, `review:NNN`, `leftover:NNN`, `measure:NNN`, `probe:NNN` take a number; `manual`, `next-work` do not |
| who | `agent`, `person`, `both` | |
| created, updated | `YYYY-MM-DD` | `updated` ≥ `created`; the tool sets `updated` on every change it makes |
| verified | `-` or `YYYY-MM-DD <commit>` | commit: 7–40 lowercase hex |
| effort | `S`, `M`, `L`, `?`, `-` | |
| feature | `-` or three digits | required iff `in-progress` |
| related, depends-on | `[]` or `[slug, slug]` | existing slugs, not the item itself |
| reason | `-` or one line | required iff `blocked`, `parked`, `rejected` |

## Body

```markdown
# <title — same text as the header>

## Problem
What is wrong or missing, from the user's point of view.

## Evidence
How it was reproduced or found: `file:line` at a commit, fix-log section,
probe name, issue link. For a person-step: the originating feature / guide.

## Expected
What correct behaviour or the finished state looks like.

## Approach            (optional)
## Notes               (optional)

## Question            (decision only)
## Options             (decision only)
## Recommendation      (decision only)
## Steps               (person-step only; checklist lines "- [ ] …")

## Log
- 2026-10-17 — created (source review:241)
```

Required headings: *Problem*, *Evidence*, *Expected*, *Log* (plus the
type-specific ones). Only the ten level-2 headings above are allowed, each
at most once, **in the order shown**; other structure goes into level-3
headings (`### …`) or lists inside a section. Lines inside fenced code
blocks (```` ``` ```` or `~~~`) are not headings. The first non-empty line
of the body is `# ` + title. *Log* has at least one entry; entries are
`- YYYY-MM-DD — <text>` (em dash), dates non-decreasing. *Steps* has at
least one `- [ ] …` / `- [x] …` line.

## Optional files

- `issue.md` — required iff `source: github#N`: header lines
  `number: N`, `url: …`, `author: …`, `created: YYYY-MM-DD`,
  `labels: a, b` (the GitHub labels at import, `-` for none; imports before
  2026-10-17 lack this line), then the title, body and comments verbatim.
- `reply.md` — first line `state: not-sent` or `state: sent YYYY-MM-DD`,
  then the draft reply.
- `evidence/` — any files.

Any other file in the item folder is a check finding.
