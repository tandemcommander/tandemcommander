# Data Model: Backlog System (242)

All entities are files in the repository except the run lock. Formats are
fixed in `contracts/`.

## Item

Folder `backlog/items/<slug>/`.

| Field | Type | Rule |
|-------|------|------|
| slug | folder name | `^[a-z0-9]+(-[a-z0-9]+)*$`, ≤ 60 chars, unique, never renamed |
| title | text | non-empty, one line, any Unicode |
| type | enum (legend) | bug, feature, improvement, tech-debt, decision, person-step |
| status | enum (legend) | new, open, blocked, in-progress, parked, rejected |
| severity | int | 0–10 |
| area | enum (legend) | see legend |
| source | form (legend) | `manual`, `github#N`, `review:NNN`, `leftover:NNN`, `measure:NNN`, `probe:NNN`, `next-work` |
| who | enum | agent, person, both |
| created | date | `YYYY-MM-DD` |
| updated | date | `YYYY-MM-DD`, ≥ created |
| verified | `-` or `YYYY-MM-DD <commit>` | commit 7–40 hex chars |
| effort | enum or `-` | S, M, L, ? |
| feature | `-` or `NNN` | required iff status `in-progress`; `specs/NNN-*` must exist |
| related | list of slugs | each must exist; no self-reference |
| depends-on | list of slugs | each must exist; no cycles; not `rejected` |
| reason | text or `-` | required iff status blocked / parked / rejected |

Body sections (in this order): *Problem*, *Evidence*, *Expected*,
[*Approach*], [*Notes*], type-specific sections, *Log*.
Type-specific: `decision` → *Question*, *Options*, *Recommendation*;
`person-step` → *Steps* (checklist, at least one `- [ ]` or `- [x]` line)
and the originating feature or guide named in *Evidence*.

Optional files: `issue.md` (verbatim GitHub issue, required iff source is
`github#N`), `reply.md` (header line `state: not-sent | sent YYYY-MM-DD`),
`evidence/` (any files).

### State transitions

```
            add / import-github
                    │
                    ▼
                 [new] ── triage ──► [open] ◄──── reopen (new reason) ────┐
                    │                  │  ▲                               │
                    │                  │  └── unblock ── [blocked]        │
                    │                  │                    ▲             │
                    │                  ├── block (reason) ──┘             │
                    │                  ├── run start ──► [in-progress] ───┤
                    │                  │                  │    │          │
                    │                  │       run stop ──┘    │          │
                    │                  │   (→ blocked on main) │          │
                    │                  │                       ▼          │
                    │                  │              feature closed:     │
                    │                  │              item REMOVED        │
                    ├──────────────────┴── park (reason) ──► [parked] ────┤
                    └──────────────────────── reject (reason) ► [rejected]┘
```

`decide` on a `decision` item: records the decision in *Log*, then either
changes `type` to the work type and keeps it `open` (moved to *Next* or
*Person steps*), or rejects it with the decision as reason.

## Overview (`backlog/BACKLOG.md`)

- Header text (rules, `Last triaged: YYYY-MM-DD`).
- Sections in fixed order, each a heading and one table:

| Section | Ordered | Admits |
|---------|---------|--------|
| In progress | yes | status `in-progress` |
| Next | yes | status `open`/`blocked`, who `agent`/`both`, type ≠ `decision`, ≠ `person-step` |
| Decisions for the maintainer | yes | type `decision`, status `open`/`blocked` |
| Person steps | yes | who `person` or type `person-step`, status `open`/`blocked` |
| Inbox | no (created, slug) | status `new` |
| Parked | no (area, slug) | status `parked` |
| Rejected | no (area, slug) | status `rejected` |

- *Legend*: vocabularies and the severity scale (R3).
- Each item appears in exactly one row; each row names an existing item.

## Log entry

A line `- YYYY-MM-DD — <text>` under *Log*; newest last. Written for:
creation (with source), triage, every status change (with reason), decision,
verification (with commit), run start / stop / not reproduced (with feature
number), reopening.

## Run journal (`backlog/RUNS.md`)

Header text and one table, newest last:

| Column | Values |
|--------|--------|
| Date | `YYYY-MM-DD HH:MM` local time |
| Item | slug or `-` |
| Outcome | `closed`, `blocked`, `not-reproduced`, `split`, `nothing-to-do` |
| Feature | `NNN` or `-` |
| Branch | name or `-` |
| Inbox | number of items added |
| Person steps | short text or `-` |
| Note | one short sentence |

## Run lock

`<git-common-dir>/tandem-backlog-run.lock`, unversioned, key–value lines:
`started: YYYY-MM-DDTHH:MM:SS`, `slug: <slug or ->`, `branch: <name or ->`,
`host: <computer name>`. Stale when older than 24 hours.

## Release checklist (`backlog/RELEASE.md`)

Free Markdown: the release procedure and the checks owed at each release
(migrated from `NEXT-WORK.md`); not parsed beyond existence.

## Migration ledger (`specs/242-backlog-system/migration-ledger.md`)

One table row per open entry of the old sources: Source (file, section,
label, first words) · Destination (`item:<slug>`, `merged:<slug>`,
`release-checklist`, `done (feature NNN)`, `not migrated: <reason>`).
