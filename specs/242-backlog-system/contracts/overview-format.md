# Contract: `backlog/BACKLOG.md`, `backlog/RUNS.md`, `backlog/RELEASE.md`

## Folder

```text
backlog/
├── BACKLOG.md      overview: order, sections, legend
├── RUNS.md         run journal of /tandem-backlog-implement
├── RELEASE.md      release procedure and checks owed at a release
└── items/<slug>/   one folder per item (contracts/item-format.md)
```

Nothing else at the top level of `backlog/` (a check finding otherwise).

## `BACKLOG.md`

```markdown
# Tandem Commander — Backlog

<rules paragraph: order is priority; only the maintainer triages and
reorders; agents add to Inbox only; derived columns are written by
`bin/backlog.sh sync`; details per item in items/<slug>/desc.md>

Last triaged: 2026-10-17

## In progress

| # | Item | Type | Sev | Area | Feature |
|---|------|------|-----|------|---------|
| 1 | [Title](items/slug/desc.md) | bug | 6 | archives | 243 |

## Next

| # | Item | Type | Sev | Area | Who | Effort | Status |
|---|------|------|-----|------|-----|--------|--------|

## Decisions for the maintainer

| # | Item | Sev | Area | Status |
|---|------|-----|------|--------|

## Person steps

| # | Item | Area | Status |
|---|------|------|--------|

## Inbox

| Item | Type | Sev | Area | Source | Created |
|------|------|-----|------|--------|---------|

## Parked

| Item | Area | Reason |
|------|------|--------|

## Rejected

| Item | Area | Reason |
|------|------|--------|

## Legend

### Types
| Value | Meaning |
...
### Statuses
### Severity
| Value | Meaning |
| 9–10 | data loss or crash in a common scenario |
| 7–8 | data loss in a narrow scenario, or a crash in an unusual one |
| 4–6 | a function does not work; a workaround exists |
| 1–3 | cosmetic or wording |
| 0 | trivial |
(features and improvements: importance on the same scale)
### Areas
### Sources
### Who
### Effort
```

Rules:

- Section headings exactly as above, in this order; each section has exactly
  one table (an empty table = header + separator only).
- A row's item cell is `[<title>](items/<slug>/desc.md)`; the slug is the
  row's identity.
- Cells are separated by `" | "` with no alignment padding.
- Ordered sections number rows `1..n` from the top. Unordered sections are
  kept sorted by the tool (*Inbox*: `created`, slug; *Parked*, *Rejected*:
  area, slug).
- Every cell except the row's position and section is derived by `sync`.
- Section admission (precedence top-down: a `decision` item belongs to
  *Decisions* even with `who: person`):

| Section | Admits |
|---------|--------|
| In progress | `in-progress` |
| Next | `open`/`blocked`, who `agent`/`both`, type ≠ decision, ≠ person-step |
| Decisions for the maintainer | type `decision`, `open`/`blocked` |
| Person steps | who `person` or type `person-step`, `open`/`blocked` |
| Inbox | `new` |
| Parked | `parked` |
| Rejected | `rejected` |

- Legend tables: first column = the allowed value (for *Sources*: the form,
  e.g. `review:NNN`); the tool reads *Types*, *Statuses*, *Areas*,
  *Sources*, *Who*, *Effort* from here.

## `RUNS.md`

```markdown
# Backlog — run journal

One line per run of /tandem-backlog-implement, newest last.

| Date | Item | Outcome | Feature | Branch | Inbox | Person steps | Note |
|------|------|---------|---------|--------|-------|--------------|------|
| 2026-10-18 14:02 | some-slug | closed | 243 | 243-some-slug | 2 | - | ... |
```

Outcome ∈ `closed`, `blocked`, `not-reproduced`, `split`, `nothing-to-do`.
Rows are appended only (`backlog.py run-log`), never edited.

## `RELEASE.md`

Free Markdown: the release procedure (version bump set, changelog, privacy
validity line, build, tag, GitHub release with the installer attached under
the fixed name, winget) and the standing checks owed at every release. Only
its existence is checked.
