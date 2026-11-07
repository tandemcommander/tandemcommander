# Closing report - 414-triage-position
Backlog item: backlog-app-triage-position-on-move-from-inbox - Backlog app triage: choose the position when moving an item out of the Inbox
Outcome: closed

## What changed

- **Triage *Place at* chooser** (`tools/backlog-app/packages/web/src/features/triage/place-chooser.tsx`,
  `triage-page.tsx`): for the current Inbox item, a section select (*Next*, *Decisions for the
  maintainer*, *Person steps*; the section its type / who admit preselected, the others disabled
  with the reason - the tool refuses them) and a position field filled with the place
  `auto-triage` picks there; Enter or *Place* moves the item in one change (one `backlog.sh move
  --position`); key `m` focuses the field, Escape leaves it; text that is not a whole number >= 1
  is refused in the page; past the end is said to go last and sent as the last place. The
  existing keys `n`, `d`, `p`, `k`, `x`, `s`, digits keep their behaviour; *Decisions* / *Person*
  are disabled for an item those sections do not admit (they were refused after the click);
  *Place* and *Accept* wait for the item to load.
- **One position rule** (`packages/shared/src/query/triage.ts` `triagePosition`): the auto-triage
  rule of `.claude/skills/tandem-backlog/reference.md` §4 (the first row of lower severity, the end
  when none, after a row it depends on); `suggestPlacement` uses it too.
- **Positions during a run** (`packages/server/src/backlog/positions.ts`): the page counts the board
  without the running item, the tool counts `main`'s rows with it - the server translates every
  page position (move, new item, `set --position`, `decide @N`); the hidden row is the run lock's
  item the board overlays, the moved item is not counted.
- **AI proposals** (`packages/server/src/ai/apply.ts`, `runner.ts`, the job record's
  `countedWithout`): a position counted during a run - or by a job during which a run started - is
  refused on *Apply* (`AI_RUN_POSITION`) and by the triage page's AI button (`aiPlacementBlock`);
  one counted with no run is applied as counted; an auto-triage plan keeps its stale-view check
  after a refused row.
- App `README.md`: the chooser and `m`.

## Measurements (before / after, commands)

- Before (`db8da649`, read `triage-page.tsx`): `n` = the suggested place only; `d` / `p` and the AI
  button = the end of the section; no position control.
- After: e2e *414/triage: the chooser places at a typed position in one change, its default by
  severity* - default 6 in Next, typed 2 -> Next = disk-map, the item, ftp, alpha, beta, gamma; one
  log line `moved to Next position 2`; *a person step goes into Person steps at a typed position*;
  *a position past the end is placed and logged as the last place*; *m focuses the position; typing
  there runs no shortcut; a refusal sends nothing*. Commands: `npm run build`, `npx playwright test
  e2e/us3-order.spec.ts e2e/a11y.spec.ts e2e/us1-live-edit.spec.ts` (from `tools/backlog-app/`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `npm run check` (typecheck, ESLint 0 warnings, Prettier, Vitest): 366 passed / 2 skipped (before
  the feature 342 / 2).
- Playwright (Edge): `us3-order` 12 / 12 (8 before; 4 new + Q9 extended), `a11y` 3 / 3,
  `us1-live-edit` 1 / 1 - 16 / 16.
- Negative controls: the chooser without its position, without the clamp; the server translation
  off, on the gate's frozen slug, counting the moved item; set / decide uncorrected; the AI refusal
  off, without the run-start check, the old plan `first` flag - each makes its test fail.
- No product code: no `build.cmd`, no `saltests`, no `.slt` refresh, no GUI probe.

## Reviews (findings and what was done)

Six refute-first reviews (details in `fix-log.md`, section *Review*):
1. 0 MUST, 2 SHOULD (default not auto-triage's rule; past the end logged as typed), 5 NOTE - fixed.
2. 1 MUST (positions during a run one place too high - also older routes since 371) - fixed.
3. 1 MUST (frozen slug instead of the running item), 1 SHOULD (moved item counted), 3 NOTE (AI
   apply path) - fixed. Counted as the second rejection (review 1 had none; no MUST repeated).
4. 0 MUST, 2 SHOULD (the AI's basis; set / decide untested) - fixed. Incident: the reviewer's
   `git worktree remove --force` followed `node_modules` junctions and deleted files of this
   repository; tracked files restored by the reviewer, `npm ci --prefer-offline` + build and the
   launcher's install stamp by the run; later prompts forbid links and forced removal.
5. 0 MUST, 2 SHOULD (the run's tree drifts from `main`; draft / plan untested) - a different
   approach: AI positions counted during a run are refused, not translated.
6. 0 MUST, 2 SHOULD (a run starting mid-job; a refused first plan row disabled the stale-view
   check), 5 NOTE - fixed with tests and negative controls; no further round (no MUST).

Accepted and recorded: an AI number is advice - a board change between the check and *Apply* other
than a run is not detected (older than 414); the chooser's default ignores a dependency on the
running item; job records from before review 4 default `countedWithout` to null.

## Owed to a person (the lines added to the release checklist)

- None: every row is driven by Playwright in Edge (keyboard included) or by API tests.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- `d` / `p` sent a move the tool refuses for an item of another type / who (severity 2) - disabled.
- The app's suggestion disagreed with auto-triage on unsorted sections (severity 2) - one rule.
- Every position sent during a run landed one place too high (Accept, new-item form, Move dialog,
  `set --position`, `decide @N`, since 371; severity 4) - translated on the server.
- A same-section move across the hidden running row was off by one (since 371) - fixed.
- AI positions applied during a run landed off (severity 3) - refused.
- *Place* / *Accept* enabled before the item loaded, Enter did nothing (severity 1) - disabled.
- The AI button had no clamp and no admission check (severity 1-2) - fixed.

## New Inbox items (slug - title)

- None.

## CHANGELOG

No entry: the backlog app is a maintainer tool, not part of the product (features 344, 371, 412
have no entries either).
