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

## Review

### Review 1 (refute-first agent, 2026-11-07) - 0 MUST, 2 SHOULD, 5 NOTE

It re-ran `npm run check` (348 / 2), the build and `us3-order` 11 / 11 + `a11y` 3 / 3 in its own
worktree; negative controls (all options enabled -> the three 414 tests fail; the `hint` guard
removed -> test 3 fails). Findings and what was done:

- **SHOULD 1 - the default was not auto-triage's place.** The app's rule ("below the last row of
  at least the severity") differs from `auto-triage`'s (`reference.md` §4 *Position*: the first
  row of lower severity, the end when none; after a dependency at or below that place) on an
  unsorted section - the real *Next* (4,4,4,4,5,4,...): a severity-5 item got 6, auto-triage 1.
  Fixed: `positionBySeverity` replaced by `triagePosition(item, rows)` implementing the
  auto-triage rule with `depends-on`; `suggestPlacement` uses it too (Accept and the chooser
  agree; on a sorted section the results are the same - the old `suggestPlacement` checks pass
  unchanged); the chooser passes the item's `dependsOn`. Unit checks: unsorted section, equal
  severity, dependencies above / at / below the place, one outside the section, the suggestion's
  `why` for a dependency. Spec Clarification 2, FR-004, US2, SC-002 corrected.
- **SHOULD 2 - a position past the end was logged as asked** (`moved to Next position 40` for an
  item at 3; `99999999999999999999` failed the request schema with 400). Fixed: the chooser sends
  `Math.min(position, rows.length + 1)`. New e2e *414/triage: a position past the end is placed
  and logged as the last place* (`99999999999999999999` -> last, log `moved to Next position 6`);
  negative control without the clamp -> that test fails; restored.
- NOTE 3 (SC-001 / SC-003 and the file comment claimed "any ordered section") - corrected in
  `spec.md` and `triage-page.tsx`.
- NOTE 4 (*Place* and Accept enabled before the item loaded; Enter did nothing; pre-existing for
  Accept, severity 1) - fixed: both disabled until the item is loaded (`pending || !item.data`).
- NOTE 5 (the spec's "a changed board is refused" overstated: the page sends the revision of the
  board it shows at the click, as every move since 371) - the edge case in `spec.md` corrected; no
  code change.
- NOTE 6 (`d` / `p` now do nothing for a non-admitting item, the buttons disabled with a title) -
  accepted, as the reviewer says.
- NOTE 7 (`readTriagePosition` repeats the hints of `parsePosition` of 371) - kept: the shared
  package cannot import the web one and the two differ (past-end note); the texts are identical
  on purpose (recorded).

After the fixes: `npm run check` 349 passed / 2 skipped; build; `us3-order` + `a11y` 15 / 15;
encoding guard `TOTAL: 0 finding(s)`.

### Review 2 (refute-first agent, 2026-11-07) - 1 MUST, 0 SHOULD, 2 NOTE

It re-ran `npm run check` (349 / 2), the build and `us3-order` 12 / 12; `triagePosition` against a
literal reading of `reference.md` §4 on 200,000 random sections with dependencies - equal, also
`suggestPlacement(...).position`. Findings and what was done:

- **MUST 1 - during a run every position landed one place too high** (pre-existing for Accept /
  `n`, the new-item form and the Move dialog since 371; severity 4 by the reviewer - fixed here).
  Cause: the board hides the running item (`overlayRunning`), `BACKLOG.md` on `main` keeps its
  row, the move route passed the page's position to `--position` unchanged (the order route
  already re-inserts the hidden row). The review-1 clamp made past-the-end land second to last.
  Reproduced by the reviewer with the real loop (`branch-hang`): main Next `disk-map, ftp
  (running), alpha, beta, gamma`; typed 3 -> visible 2; default 5 -> 4.
  Fixed: `packages/server/src/backlog/positions.ts` `filePosition(fileSlugs, hidden, position)`
  (+1 below the hidden row), used through `toolPosition` / `toolPositionAfter` by `POST
  /items/:slug/move`, `POST /items` (the new item's place), `POST /items/:slug/fields` (`set
  --position`, section after the type / who change) and `POST /items/:slug/decide` (`move:@N`,
  `set-type:@N`). Tests: `packages/server/test/positions.test.ts` (every visible place gives the
  same visible place; the shift only below the hidden row) and *counts a moved or new item's
  position as the page does, without the hidden running item (414)* in `write-channels.test.ts`
  (real tool, side worktree of `main`, run on a branch: main Next `[DISK, FTP]`, page `[FTP]`; move
  at 2 -> `[DISK, FTP, X]`; new item at 2 -> page `[FTP, new, X]`). Negative control: `filePosition`
  returning the position unchanged -> 3 tests fail (both unit tests and the route test); restored.
- NOTE 1 (stale design documents and an old unit-test title naming the replaced rule) - corrected
  (`contracts/triage-place-chooser.md`, `data-model.md`, `plan.md`, `research.md` R2 + new R6,
  `quickstart.md`, `tasks.md`, `triage.test.ts`).
- NOTE 2 (the chooser kept its section when type / who changed while it stayed current) - fixed:
  the chooser is keyed by slug and admitting section.

After the fixes: `npm run check` 355 passed / 2 skipped (20 files).
- e2e after the fixes: `us3-order` + `a11y` + `us1-live-edit` 16 / 16 passed (3.3 min); encoding guard `TOTAL: 0 finding(s)`.

### Review 3 (refute-first agent, 2026-11-07) - 1 MUST, 1 SHOULD, 3 NOTE

It re-ran `npm run check` (355 / 2), the build and `us3-order` 12 / 12; checked that nothing in the
web package adjusts positions itself (no double correction), that `sectionAfter` gives the tool's
`expected_section`, and that the triage clamp still lands last during a run.

Counting for stop-rules §3 #3: review 1 had no MUST; review 2's MUST (positions during a run) was
fixed; review 3's MUST is a new one, introduced by that fix - the second rejection, not the third,
and no MUST repeated unchanged. The run fixes and has a fourth review.

- **MUST 1 - the review-2 correction used the gate's frozen slug**, which also names the item of an
  interrupted run (no lock, HEAD on `main`, gate case 11) whose row the board still shows: every
  position below it went one place too low. Reproduced by the reviewer (`run.json` naming DISK, no
  lock: move at 2 gave `[DISK, FTP, X]`, expected `[DISK, X, FTP]`). Fixed: the hidden row is
  `services.running()` - exactly what `overlayRunning` hides. Test *does not shift a position for
  an interrupted run whose item the board still shows (414 review 3)*; negative control (the gate's
  frozen slug again) -> that test fails.
- **SHOULD 1 - a move within the section across the hidden row stayed off by one** (the item page's
  Move dialog; older, since 371): the tool's `place_row` takes the moved item's own row out before
  it counts, `toolPosition` counted it. Fixed: the moved item is left out of the count (and nothing
  shifts when the moved item is the hidden one). Test *moves an item within its section across the
  hidden running item as the page counts (414 review 3)*; negative control (the moved item counted)
  -> that test fails.
- NOTE 1 - **the AI apply path** (`ai/apply.ts`: a triage check's *Apply*, an auto-triage plan's
  rows, a draft's place) passed the AI's position unchanged; during a run the AI reads the run's
  tree, where the running item is in *In progress*, so it counts like the page (severity 3, fixed
  here by rule 11): `forTool` / the draft's place go through the same `toolPosition`. Test *applies
  a proposed position as counted without the hidden running item (414 review 3)* in
  `ai-jobs.test.ts`; negative control (`forTool` returning the verdict unchanged) -> that test
  fails.
- NOTE 2 - the chooser's default ignores a dependency on the hidden running item (it is not among
  the visible rows) - accepted: the running item is being finished; recorded.
- NOTE 3 - the run case is covered by server / API tests, not by an e2e of the triage page during a
  run - accepted: the correction is entirely server-side and each case has a route test with a
  negative control.

The helper moved to `packages/server/src/backlog/positions.ts` `toolPosition(services, section,
position, moved?)`, used by the write routes and the AI apply path.

After the fixes: `npm run check` 358 passed / 2 skipped (20 files).
- e2e after the review-3 fixes: `us3-order` + `a11y` + `us1-live-edit` 16 / 16 passed (3.2 min); encoding guard `TOTAL: 0 finding(s)`.

### Review 4 (refute-first agent, 2026-11-07) - 0 MUST, 2 SHOULD, 3 NOTE, and an incident

**Incident (the reviewer's cleanup, not the feature):** the reviewer linked its worktree's
`node_modules` to this repository's with junctions; `git worktree remove --force` followed them
(this repository's `node_modules/@backlog-app/*` are junctions to `packages/*`) and deleted 160
tracked files under `tools/backlog-app/packages/` plus the ignored `tools/backlog-app/node_modules`,
`packages/web/node_modules` and `packages/web/dist`. The reviewer restored the tracked files at once
(`git checkout HEAD -- tools/backlog-app/packages`; `git status` clean at `f6a1a4d3`). The run
restored the rest: `npm ci --prefer-offline --no-audit --no-fund` from the unchanged
`package-lock.json` (569 packages, 12 s, from the npm cache), the launcher's install stamp
`node_modules/.backlog-app-lock.sha256` rewritten with the lock file's hash, `npm run build` (dist
rebuilt; its source stamp is left absent, so the launcher rebuilds `dist` from `main`'s sources at
its next start). No backlog-app server was running (only the editor's TypeScript servers). The
next reviewer's prompt forbids junctions and forced worktree removal.

Findings and what was done:

- **SHOULD 1 - an AI proposal's basis is the job's start, not the time of applying.** A job
  started with no run read `main`'s tree (the later running item still in *Next*); applying it
  during a run shifted it wrongly - the review-3 test even asserted that case. Fixed: the job
  record keeps `countedWithout` (the running item at the job's start, `AiJobRecordSchema`, default
  null for older records); `apply.ts` translates from that basis (`toolPosition(..., countedWithout)`)
  for triage checks, auto-triage plan rows and a draft's place. On the triage page the AI's *Place
  at* button (which goes through the move route, on the page's basis) is disabled with the reason
  "a run started or ended since the check ..." when `countedWithout` differs from the item the
  board hides now, is disabled for a section the item's type / who do not admit, and sends past the
  end as the last place (also review 4's last NOTE). Tests in `ai-jobs.test.ts`: *applies a proposed
  position on the basis of the job's start, not of the time of applying (414)* (job with no run,
  applied during a run -> `[DISK, X, FTP]`) and *... of a job started during a run as counted
  without the running item (414)* (-> `[DISK, FTP, X]`); negative controls: apply on the current
  basis -> the first fails; no correction -> the second fails.
- **SHOULD 2 - the set --position and decide corrections had no test.** Added *counts set
  --position and decide move:@N as the page does during a run (414 review 4)* in
  `write-channels.test.ts` (a person step made agent work moved to Next at 2 -> page `[FTP,
  PERSON]`, main `[DISK, FTP, PERSON]`; a decision decided "move to Next at 3" -> `[FTP, PERSON,
  DECISION]`); negative control (both corrections removed) -> fails.
- NOTE (the hidden row equals the board's overlay in every gate state; auto-triage plan rows are
  corrected against a snapshot reloaded after each row; no double correction; `toolPosition` runs
  before the queue's edit lock - the remaining window falls into a closed gate or `base.board`) -
  confirmations, nothing to change.
- NOTE (the AI button without the clamp and the admission check) - fixed with SHOULD 1.

After the fixes: `npm run check` 360 passed / 2 skipped (20 files).
- e2e after the review-4 fixes: `us3-order` + `a11y` + `us1-live-edit` 16 / 16 passed (3.2 min); encoding guard `TOTAL: 0 finding(s)`.

### Review 5 (refute-first agent, 2026-11-07) - 0 MUST, 2 SHOULD, 4 NOTE

It worked in its own copy (dependencies installed there, no links; this repository's `git status`
empty and `node_modules` intact afterwards - checked by the run too: 362 entries). It re-ran
`npm run check` (360 / 2), the build and `us3-order` 12 / 12; negative controls of review 4's AI
tests worked; `countedWithout` correct for the cases covered, a record from disk without the field
reads as null.

- **SHOULD 1 - during a run the AI's list is the run's branch, which drifts from `main` by more
  than the running row**: every change the app lands on `main` during the run is missing there
  (reproduced with `filePosition`: main `[A, X(running), P, Q]`, branch `[P, Q]`, an AI "#2"
  (between P and Q) applied as 2 -> above P). The same holds for a run started by hand before its
  `BL start` (NOTE 1) and for a run starting while the AI reads (NOTE 2).
  This was the third attempt at the AI's positions (review 3: correct by the running row; review
  4: by the running row of the job's start); a *different* approach now (stop-rules §3): **refuse
  rather than guess**. An AI position counted during a run (`countedWithout` set) is refused by
  *Apply* (`apply.ts` `assertCountable`, `422 refused` with `AI_RUN_POSITION`: "place the item with
  the triage page's Place at, or apply the proposal without a position") - for a triage check, a
  draft's place and each auto-triage plan row (the plan goes on with its other rows); a position
  counted with no run is `main`'s own count and is applied as counted. The translation of AI
  positions is gone (`toolPosition` serves the page's routes only). On the triage page the AI's
  *Place at* button follows the pure rule `aiPlacementBlock` (shared): refused when the job counted
  during a run or a run hides an item now, or for a section the item's type / who do not admit.
- **SHOULD 2 - the draft and plan paths had no test**: *refuses the position of a draft or an
  auto-triage plan row counted during a run (414)*; the triage-check test now asserts the refusal
  and that the proposal applied without a position lands at the end. Negative control (no refusal)
  -> both tests fail.
- NOTE 3 (the button's guard untested) - the guard is now `aiPlacementBlock` with unit checks in
  `shared/test/triage.test.ts`.
- NOTE 4 (the label showed the unclamped number) - the label shows the number sent.

After the fixes: `npm run check` 364 passed / 2 skipped.
- e2e after the review-5 fixes: `us3-order` + `a11y` + `us1-live-edit` 16 / 16 passed (3.2 min); encoding guard `TOTAL: 0 finding(s)`.

### Review 6 (refute-first agent, 2026-11-07) - 0 MUST, 2 SHOULD, 5 NOTE

Own copy with its own `npm ci`, no links; this repository clean and `node_modules` intact
afterwards (362 entries). It re-ran `npm run check` (364 / 2), the build, `us3-order` 12 / 12; the
negative control of the refusal works; refusals write nothing on the tested paths; verdicts without
a position (decision, park) still apply during a run.

- **SHOULD 1 - a run that starts while claude reads was not detected** (`countedWithout` is taken
  at the job's start; the loop does not wait for the app's AI jobs). Reproduced by the reviewer
  with a gated fake claude: applied as counted on main, one place off. Fixed: `countedDuringRun`
  also counts a job as "during a run" when a run in progress now began before the job ended (the
  lock's `started`, whole seconds: a start in the job's last second counts as during it -
  conservative). Test *refuses a position of a job during which a run started, and keeps the
  stale-view check of a plan (414 review 6)* (run lock dated 36 s back -> `422`, main unchanged);
  the review-4 test that applies a no-run job during a later run now waits for the next second
  before the lock. Negative control (the start check off) -> the new test fails.
- **SHOULD 2 - a refused first plan row switched the stale-view check off** for the rest of the
  plan (`first = false` also after a row refused before the queue; review 5 made such refusals
  common). Reproduced: a stale `base.board`, first row refused, the second row parked the item.
  Fixed: the board revision goes with the first row that reaches the write queue (`reached`). Same
  test: second row refused as changed underneath, no change, tray unchanged, the item still in the
  Inbox. Negative control (the old `first = false`) -> the test fails.
- NOTE 3 (a draft for the Inbox with a position was refused during a run although the position is
  ignored) - fixed: only a draft placed outside the Inbox is checked; test *applies a draft for the
  Inbox during a run (its position means nothing) (414 review 6)*.
- NOTE 4 (the draft test did not show that nothing was written) - the test now asserts no new item
  and an empty tray (`pending` and `committedRecently`).
- NOTE 1 (a run that starts *and ends* between the job and Apply, or any other board change in
  between, is not detected - older than 414, both routes) - accepted and recorded: the AI's
  numbers are advice the maintainer sees before applying; covering it would mean storing the
  section rows at the job's start and comparing (a change of the AI design of 344).
- NOTE 2 (the page button is stricter than Apply; a seconds-long window between render and click)
  - accepted.
- NOTE 5 (job records saved before review 4 default `countedWithout` to null) - accepted: such
  records exist only from this feature's own branch builds; with the start check of SHOULD 1 a
  record from before a run still in progress is refused anyway.

After the fixes: `npm run check` 366 passed / 2 skipped. Review 6 had no MUST; its SHOULD fixes are
narrow and each has a test with a negative control - no further review round (SKILL.md step 7:
a fresh review follows MUST findings).
- e2e after the review-6 fixes: `us3-order` + `a11y` + `us1-live-edit` 16 / 16 passed (3.3 min).
