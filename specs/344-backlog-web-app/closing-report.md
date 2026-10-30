# Closing report — 344 the backlog web app (`tools/backlog-app`)

**Date**: 2026-10-30 · **Branch**: `344-backlog-web-app` (committed on the branch; not merged,
not pushed - the maintainer decides) · **Session**: interactive Spec Kit flow with the maintainer
(specify with three clarifications - all six stories, a change tray with an explicit commit,
an English UI - then plan, tasks, implement).

## What changed

- **A localhost web application** `tools/backlog-app/` (Node 24 + TypeScript, three npm
  workspaces): `packages/server` (Hono on `node:http`, bound to `127.0.0.1`), `packages/web`
  (React 19, Vite 8, Tailwind 4, Radix, TanStack Query / Router / Table, light and dark theme from
  the first paint) and `packages/shared` (zod schemas of every API body and event, the filter
  language, the triage rules, the run state machine). Started by **`bin/start-backlog-app.sh`**
  (`--dev`, `--port`, `--no-open`, `--root`; installs and builds only when the lock file or the
  sources changed; a second start reuses the running instance). `tools/backlog-app/README.md`
  explains running, developing, testing, the architecture, the rules and the licences.
- **The six user stories**: browse, filter (a query language kept in the address), search and
  open items, their history and the closed archive (US1); watch the loop and the item being
  implemented live, start / pause / resume / stop / hard-stop the loop, interrupted runs, usage
  limits (US2); reorder by drag or keyboard, triage the Inbox with suggested positions, block /
  park / reject / reopen / close with reasons, edit fields and body sections, bulk changes (US3);
  new items, decisions, person steps, replies (US4); Claude jobs - draft an item from a sentence,
  ask a question, check a placement, verify an item - with nothing written before the maintainer
  accepts (US5); run one chosen item, run history with transcripts and statistics, feature
  records, release readiness without any publish action (US6).
- **The app changes nothing by itself.** Every backlog change is a `bin/backlog.sh` command with
  the user's texts on stdin (`--input-json -`), every loop control a `bin/backlog-loop.sh`
  command; the loop runs in its own console window and is never hosted by the app. Changes land
  in a **change tray** (undo of the newest change, commit `backlog(app): ...` of `backlog/`
  paths only, committed automatically before a loop start or resume). An **edit lock**
  `.git/tandem-backlog-edit.lock` keeps the loop from starting a run while the app writes; the
  **write gate** keeps the app read-only while a run holds the run lock, the loop runs unpaused
  or stopped answering, HEAD is not `main`, or a merge is open. During a run the board is read
  from `main`'s git objects (`--ref main`), never from files the run writes.
- **Security** (localhost only): Host allow-list (421), Origin / Sec-Fetch-Site checks, JSON and
  size limits, a per-start bearer token handed out through a single-use 120 s start code, CSP,
  static files by exact manifest lookup, identifiers checked against patterns and the tool's
  listings; the app's state folder `.git/tandem-backlog-app/` is restricted to the user.
- **Additions to the tools** (contracts of 242 / 247 amended, `contracts/backlog-cli-additions.md`,
  `contracts/loop-cli-additions.md`): `backlog.py` `board` / `show` / `check` / `legend --json`,
  `--ref`, `--input-json -`, `--json` results with the written files, `reorder`, `body`, `step`,
  `decide`, `reply`, `set --position`; `loop.py` `kill`, `start --new-window` and `--item`, the
  edit-lock precheck, `loop.log`, `last.json`, and the `status --json` keys `kill`, `last`,
  `edit_lock`, `log`, `orphan`.
- **Documentation**: the `tandem-backlog` skill uses the new commands (texts on stdin) and explains
  the app's lock and commits; `CLAUDE.md` names the launcher; `architecture/12-project-reference.md`.

## Evidence

| Check | Result |
|---|---|
| Success criteria | table below |
| `npm run check` (typecheck, ESLint with the jsdoc / tsdoc rules, Prettier, Vitest) | 278 unit and API tests pass |
| `npm run test:e2e` (Playwright on Edge, fixture repositories, the real tools, the real loop with the fake claude in a hidden console window) | 26 of 26 |
| Python: `test_backlog` + `test_loop`, `test_traces`, `tools/test_bin_help.py` | 220 OK, OK, OK |
| `bin/backlog.sh check` | TOTAL 0 |
| Security suite | 17 gate tests + 3 mutants; by hand against the app on a clone of the real repository: no token 401, foreign Origin 403, used start code 401, foreign Host 421 |
| Negative controls | 22 of 22 mutations of the write path, gate and run reading caught by the unit tests (`fix-log.md`, *Independent review*) |
| Independent review (refute-first) | 3 MUST, 4 SHOULD, 6 NOTE - all fixed with tests except one note moved to the Inbox (below) |
| Quickstart Q1-Q22 | Q1-Q21 pass (`fix-log.md` table); Q22 is a person step |

| SC | Result |
|---|---|
| SC-001 start | first start (install + build) 17.8 s, later 1.0 s |
| SC-002 morning routine | **owed to a person** (Inbox item `backlog-app-morning-on-real-repo`) |
| SC-003 same as the tool | 257 items of the real repository: order and fields equal (`position` null in unordered sections by contract); app changes byte-equal to the tool's on a twin repository; check TOTAL 0 |
| SC-004 live progress | **partly**: trace lines over 20 minutes of a run (stopped early at the maintainer's request, not 2 hours): 600 of 600 within 1.49 s (median 0.75 s), none over 5 s, the server's memory flat (100 MB working set at 12 and 20 minutes); task progress: 40 of 40 ticks within 3.0 s (median 1.65 s) |
| SC-005 search | 508 items: API 3-23 ms, browser Enter to rows 176-362 ms |
| SC-006 soak | 20 runs with the app open: no wait, no failed replace, lock and loop state untouched |
| SC-007 access | all refused (above) |
| SC-008 texts | 20,000 characters with shell characters, newlines and Czech letters byte-exact, the canary never ran |
| SC-009 accessibility | axe WCAG 2.2 AA in both themes on 15 screens; keyboard journeys of US1 and US3 |
| SC-010 documentation | ESLint documentation rules: zero findings (TypeDoc's check was dropped - its negative control did not fail) |
| SC-011 app closed during a run | the run and the loop continue; a new app shows the run within the 15 s test bound |

## Defects found by measurement and review (all in `fix-log.md`)

- Reading files the loop replaces atomically, in a tight loop, makes the loop's `os.replace` fail
  (WinError 5): the app reads only append-only traces of a live run, and `meta.json` only of an
  indexed (ended) run - the latter was wrong in the first version (a run started a moment ago).
- The answer of a change came before the read model reloaded: an undo followed at once by a
  reorder was refused as `changed-underneath`. A change now answers only once the board shows it.
- The gate after taking the edit lock could use a loop state polled before the lock (review M1).
- The state folder inside `.git` was readable by every local user (launcher secret) and undo files
  could name any path (review M2).
- A stale board revision after the app's own change, rows `aria-disabled` while reordering was
  not allowed, contrast of the light `--ok` colour, a shared accessible name (e2e).
- T012 (the README) and T130 (the SC-004 measurement) had been marked done without the work; both
  were done during the polish phase.

## Spec corrections made by measurement

- TypeDoc's `validation.notDocumented` reported nothing for an undocumented export (negative
  control) - the documentation gate is ESLint (`jsdoc` + `tsdoc`), not `docs:check`.
- TanStack Table 8.21.3 instead of 9 (stable API); `board --json` gives `position: null` in the
  unordered sections, written into the contract.
- The live run's task progress is read every 3 s, not 5 s: with the 1 s follow tick a 5 s
  interval gives up to about 6 s (SC-004 asks for 5 s) - measured before and after.

## Left for later (Inbox)

- `run-lock-update-release-no-retry` (review:344): `backlog.py lock update / release` do not retry a
  `PermissionError` while a reader holds the run lock; the app's 2 s status poll raises the chance.
- `backlog-app-morning-on-real-repo` (leftover:344, person step): SC-002 / Q22 on the real
  repository, and one visible `--new-window` loop start.

Not done: the 2-hour length of SC-004 (the maintainer chose to finish after 20 minutes); the
measurement scripts are described in `fix-log.md` and can be run again.

Not taken on: the web bundle is one 2.1 MB chunk (Vite warns; the app is local, first load
measured within SC-001).
