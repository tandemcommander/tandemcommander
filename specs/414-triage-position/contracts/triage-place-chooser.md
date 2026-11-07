# Contract - the triage *Place at* chooser (414)

UI contract of the triage page (`/triage`) of the backlog app; no API change.

## Controls (in the side column, below the suggestion card)

| Control | Accessible name | Behaviour |
|---|---|---|
| section select | `Target section` | options *Next*, *Decisions for the maintainer*, *Person steps*; initial = the section the item's type / who admit (`admittingSection`); the other two disabled, labelled `<section> - its type / who belong in <admitting>` (the tool refuses them) |
| position field | `Position in the target section` | text, numeric input mode; initial = default of the selected section; `m` focuses and selects it; Enter = Place; Escape = leave the field (blur), nothing placed |
| hint | (described-by of the field) | "type a whole number: 1 is the top" / "positions count from 1 (the top)" (refused); "past the end: the item goes last" (accepted) |
| button | `Place` (with `Enter` hint) | sends the move; disabled while the write gate is closed (its reason shown, as for the other actions), while a change is pending, or while the hint refuses |

## Request

`POST /api/items/<slug>/move` with
`{ "base": { "board": <board revision>, "item": <item revision> }, "section": <target>, "position": <n> }`
- one change, as Accept sends; `n` is at most the section's visible item count + 1 (past the end is
sent as the last place). While a run works on an item of the section, the server adds 1 to a
position below that hidden row before calling the tool (`filePosition`, review 2) - for every
route that passes a position (move, new item, set, decide).

## Unchanged

`n` / Accept (the suggested place - now computed by `triagePosition`), `d` / Decisions and `p` /
Person (end of the section; disabled for an item the section does not admit), `k`, `x`, `s`, `l`,
`0`-`9`, `+`, `-`, Check with AI and its proposal button. Place and Accept are disabled until the
item is loaded.

## Pure rules (`@backlog-app/shared`, `query/triage.ts`)

- `TRIAGE_TARGETS: readonly SectionName[]`
- `triagePosition(item: { severity: number; dependsOn?: string[] }, rows: { severity: number; slug?: string }[]): number` - the auto-triage rule (`reference.md` §4 *Position*)
- `readTriagePosition(text: string, count: number): { position: number; last: boolean } | { hint: string }`
- `suggestPlacement(item, rows)` takes the item's `dependsOn` too and uses `triagePosition`; on a
  section sorted by severity its results are the old ones, on an unsorted one they follow
  auto-triage.
