# Research - 414-triage-position

## R1 - Where the position is applied

- **Decision**: the existing `POST /api/items/:slug/move` with `{ base: { board, item }, section, position }`.
- **Rationale**: it already runs one `backlog.sh move <slug> --section <s> --position <p>` (one change,
  one tray entry), carries the board revision (a position counts rows, so the server refuses a move
  computed on a stale board) and is what Accept already uses for the suggested place.
- **Alternatives**: move then `POST /api/sections/:s/order` (two changes - the very problem of the
  item); `decide ... --then move:<Section>@N` (only for decisions).

## R2 - The default position

- **Decision**: `positionBySeverity(severity, rows)` - below the last row of at least the item's
  severity, 1 when there is none; `suggestPlacement` uses it for its own section, the chooser for
  whichever section is chosen.
- **Rationale**: the item asks for "the place auto-triage would pick by severity"; the app's suggestion
  (FR-027 of 344) already follows this rule, and one rule for both keeps them equal.
- **Alternatives**: the end of the section (what `d` / `p` do today - not "sensible" for *Next*);
  the top (jumps ahead of more severe items).

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
