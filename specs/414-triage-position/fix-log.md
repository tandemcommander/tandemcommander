# Fix log - 414-triage-position

Backlog item `backlog-app-triage-position-on-move-from-inbox` - Backlog app triage: choose the
position when moving an item out of the Inbox. Started 2026-11-07 from `main` at `db8da649`.

## Measurement before (db8da649)

Read `tools/backlog-app/packages/web/src/features/triage/triage-page.tsx`:

- Accept / `n` -> `place(suggestion.section, suggestion.position)` - the suggested place only.
- Decisions / `d`, Person / `p` -> `place(section)` without a position -> the end of the section.
- The AI proposal button -> where Claude proposed.
- No control to choose a position; no way into *Next* other than the suggested place.
- Server `POST /api/items/:slug/move` (`packages/server/src/api/backlog-write.ts`) already passes
  `--position` to one `backlog.sh move`; `backlog.py place_row` appends when the position is past
  the end.
- e2e `us3-order.spec.ts` *Q8/triage* covers only `n`.

`BL verify` recorded the finding.

## Decisions

- One chooser (section select + position field + Place) beside the existing actions; `n`, `d`, `p`
  unchanged (conservative, spec Clarifications).
- Default position = the severity rule of the suggestion, factored into `positionBySeverity`.
- `m` focuses the position field.
