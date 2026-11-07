# Contract - the triage *Place at* chooser (414)

UI contract of the triage page (`/triage`) of the backlog app; no API change.

## Controls (in the side column, below the suggestion card)

| Control | Accessible name | Behaviour |
|---|---|---|
| section select | `Target section` | options *Next*, *Decisions for the maintainer*, *Person steps*; initial = the suggestion's section |
| position field | `Position in the target section` | text, numeric input mode; initial = default of the selected section; `m` focuses and selects it; Enter = Place; Escape = leave the field (blur), nothing placed |
| hint | (described-by of the field) | "type a whole number: 1 is the top" / "positions count from 1 (the top)" (refused); "past the end: the item goes last" (accepted) |
| button | `Place` (with `Enter` hint) | sends the move; disabled while the write gate is closed (its reason shown, as for the other actions), while a change is pending, or while the hint refuses |

## Request

`POST /api/items/<slug>/move` with
`{ "base": { "board": <board revision>, "item": <item revision> }, "section": <target>, "position": <n> }`
- one change, as Accept sends. The server and the tool are unchanged.

## Unchanged

`n` / Accept (suggested place), `d` / Decisions and `p` / Person (end of the section), `k`, `x`,
`s`, `l`, `0`-`9`, `+`, `-`, Check with AI and its proposal button.

## Pure rules (`@backlog-app/shared`, `query/triage.ts`)

- `TRIAGE_TARGETS: readonly SectionName[]`
- `positionBySeverity(severity: number, rows: { severity: number }[]): number`
- `readTriagePosition(text: string, count: number): { position: number; last: boolean } | { hint: string }`
- `suggestPlacement` keeps its signature and results.
