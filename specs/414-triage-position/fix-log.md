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

## Analyze

- C1 (MEDIUM): FR-009 had no test -> T014 (the Q9 read-only e2e test checks the chooser).
- E1 (LOW): "board changed underneath" has no own task - the unchanged server refuses a move on a
  stale board revision (`base.board` is sent); accepted.
- No CRITICAL / HIGH.

## Implementation

- `packages/shared/src/query/triage.ts`: `TRIAGE_TARGETS`, `positionBySeverity` (the severity rule,
  now also used by `suggestPlacement` - same results, checked for severities 0-10),
  `readTriagePosition` (whole number >= 1, else the hint of the 371 position field; past
  `count + 1` accepted with `last: true`).
- `packages/web/src/features/triage/place-chooser.tsx` (new): *Place at* card - section select,
  position field (default = `positionBySeverity` of the chosen section, follows the board until
  typed into), hint, *Place* button; Enter places, Escape blurs; disabled with the gate's reason.
- `triage-page.tsx`: the chooser keyed by the current slug; key `m` focuses its position field;
  `onPlace` = the existing `place(section, position)` - one `POST /api/items/:slug/move` with the
  position = one `backlog.sh move --position`.
- App `README.md`: one paragraph on the chooser and `m`.

## Findings fixed on the way

- **`d` / `p` (and any non-admitting target) are refused by the tool** (severity 2): measured on a
  copy of the tool's valid fixture - `backlog.py move typed-path-with-a-pipe-brackets --section
  person --position 1` -> `refused: ... (type bug, who agent) belongs in 'Next', not 'Person
  steps'; change type / who with 'set' first`, exit 1; `--section next --position 1` -> exit 0.
  Before: the *Decisions* / *Person* buttons and keys sent that move and the page showed the
  refusal. Now: the triage computes `admittingSection(item)`; the chooser shows the other sections
  disabled ("<section> - its type / who belong in <admitting>"), the *Decisions* / *Person*
  buttons are disabled with that title and `d` / `p` do nothing for such an item. Test: e2e
  *414/triage: the chooser places ...* asserts the disabled options and the disabled *Person*
  button; *414/triage: a person step goes into Person steps ...* asserts *Next* disabled.

## Checks

- `npm run check` (from `tools/backlog-app/`): typecheck clean, ESLint 0 warnings, Prettier
  clean, Vitest 348 passed / 2 skipped (before: 342 / 2; +6 checks in `shared/test/triage.test.ts`).
- `npm run build` + `npx playwright test e2e/us3-order.spec.ts e2e/a11y.spec.ts` (Edge): 14 / 14
  passed - new: *414/triage: the chooser places at a typed position in one change, its default by
  severity* (default 6 in Next, typed 2 -> Next = disk-map, the item, ftp, alpha, beta, gamma; one
  log line `moved to Next position 2`; tray `1 uncommitted change`; `check` TOTAL 0), *414/triage:
  a person step goes into Person steps at a typed position* (default 2, typed 1 -> first),
  *414/triage: m focuses the position; typing there runs no shortcut; a refusal sends nothing*
  (`m` focuses, `0` typed into the field leaves severity 2 and shows the refusal hint, Place
  disabled, `40` says "past the end", nothing written, tray `0 uncommitted changes`); Q9 extended
  (chooser disabled while read-only); the old *Q8/triage: n places ...* still passes; axe light /
  dark (which visit `/triage`) pass.
  First run: 2 failures of the tests themselves (`getByLabel` substring matched both controls;
  the triage page shows its own read-only notice besides the banner) - locators fixed.
- Negative control: `onPlace={(section) => place(section)}` (no position sent), rebuilt -> the
  first 414 test fails (`Expected - 1 / Received + 1`: the item landed last); restored and rebuilt.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- No product code, no UI strings of the product: no `build.cmd`, no `saltests`, no `.slt` refresh,
  no GUI probe (the app's Playwright tests run on the fixture repositories).

## Measurement after

The triage page offers *Place at* with the admitting section and the severity default; a typed
position is applied by one move (e2e above). The item's defect - "cannot be given its position in
the same step" - is gone.
