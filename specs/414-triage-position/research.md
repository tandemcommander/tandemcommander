# Research - 414-triage-position

## R1 - Where the position is applied

- **Decision**: the existing `POST /api/items/:slug/move` with `{ base: { board, item }, section, position }`.
- **Rationale**: it already runs one `backlog.sh move <slug> --section <s> --position <p>` (one change,
  one tray entry), carries the board revision (a position counts rows, so the server refuses a move
  computed on a stale board) and is what Accept already uses for the suggested place.
- **Alternatives**: move then `POST /api/sections/:s/order` (two changes - the very problem of the
  item); `decide ... --then move:<Section>@N` (only for decisions).

## R2 - The default position

- **Decision**: `triagePosition(item, rows)` - the rule `auto-triage` uses
  (`.claude/skills/tandem-backlog/reference.md` §4 *Position*): the place of the first row of lower
  severity (the end when none; equal severity after the existing rows), then after a row the item
  depends on at or below that place. `suggestPlacement` uses it for its own section, the chooser for
  the chosen one.
- **Rationale**: the item asks for "the place auto-triage would pick by severity". The first design
  reused the app's suggestion rule ("below the last row of at least the severity"), assuming it was
  the same; review 1 showed it differs on an unsorted section (the real *Next*), so both now use the
  auto-triage rule.
- **Alternatives**: the end of the section (what `d` / `p` do - not "sensible" for *Next*); the
  app's old rule (disagrees with auto-triage on unsorted sections).

## R3 - Reading the typed position

- **Decision**: `readTriagePosition(text, count)`: trimmed whole number >= 1, else a hint (the same
  wording as the position field of feature 371: "type a whole number: 1 is the top", "positions count
  from 1 (the top)"); a number larger than `count + 1` is accepted with `last: true` and the hint
  "past the end: the item goes last" (the tool appends; `count` is the section's item rows, the
  Inbox item is not among them).
- **Rationale**: FR-006; refusing in the page means nothing is sent for a typo.
- **Alternatives**: clamp silently (the maintainer would not know); refuse past-end (the tool accepts it
  and the existing position field treats it as last).

## R4 - Keyboard

- **Decision**: `m` focuses the position field (selects its text); Enter confirms, Escape blurs it
  without placing. Typing in the field or the select runs no triage shortcut - `useShortcuts`
  already ignores single keys in text fields and selects (`lib/hotkeys.ts` `isTextField`).
- **Rationale**: FR-008; `m` is not used on the triage page or globally (`c`, `?`, `/`, Ctrl+K, `g x`).

## R5 - Resetting with the item

- **Decision**: the chooser is keyed by the current item's slug (React `key`), so a new item starts
  with its own suggested section and default; the default also follows the board (a changed section
  recomputes it) until the maintainer edits the field.
- **Rationale**: edge case "the item changes while the chooser is open".

## R6 - Positions while a run works on an item (review 2)

- **Decision**: the server translates a page-counted position to the tool's count
  (`packages/server/src/backlog/positions.ts` `filePosition`): +1 below the hidden running row, for
  every route that passes `--position` (move, new item, set, decide).
- **Rationale**: during a run the board hides the running item (371 overlay) while `BACKLOG.md` on
  `main` keeps its row; the order endpoint already re-inserts it, the position routes did not
  (measured by review 2 with the real loop: typed 3 landed at 2).
- **Alternatives**: correct on the page (every caller would need the raw board); refuse positions
  during a run (loses the feature of 371).
