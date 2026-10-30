# Fix log: 344 backlog web app

Running record of the implementation (CLAUDE.md working method). Newest sections at the end;
agents append their own sections.

## Baseline (2026-10-30)

- Branch `344-backlog-web-app`, commits `1b0a3471` (skill path fix, unrelated, kept apart) and
  `710c1ed6` (specification, analysis, plan, tasks) on top of `f7faf9ae` (main).
- `bin/backlog.sh check` -> `TOTAL: 0`.
- Tools: Node v24.22.1, npm 11.21.1, Python 3.15.1, Claude Code 2.1.314, git 2.55.0.windows.4;
  git common dir `.git`.
- The Python additions are implemented by two agents in parallel (backlog.py / loop.py, disjoint
  files); the app skeleton is built meanwhile.
- Contract adjustment before implementation: the edit lock carries `started_epoch` instead of a
  process creation time (`ident`), because Node cannot read creation times of processes
  (contracts/loop-cli-additions.md, data-model.md).

## loop.py additions (T019-T021, T118)

Test-first with the fake claude in temporary repositories (the real `.git/tandem-backlog-loop/`
and the run lock were never touched).

- Baseline: `python -m unittest tools/backlog/test_loop.py tools/backlog/test_traces.py` ->
  `Ran 103 tests ... OK`; `python tools/test_bin_help.py` -> `Ran 1 test ... OK`.
- New tests (25) first run against the old loop.py: failures and errors as expected (e.g.
  `--item` -> exit 2 unknown option; `status --json` without `kill`).
- Implemented in `tools/backlog/loop.py`: `kill` (flag `kill`, checked every tick of `wait()`,
  `watch()` - item, previous loop's claude, auto-triage - and at the top of a cycle; raises
  `Killed(KeyboardInterrupt)` into the existing `hard_stop`, words "(kill)", run `why` "a hard
  stop (kill) ended the process", flag removed; a stale flag removed by `register`);
  `loop.log` (`say()` and the unprefixed refusals via `tell()`, local time prefix, one unbuffered
  write per line, file closed at once, rotation to `loop.log.1` past `LOG_MAX` 5 MB, a failed
  write never stops the loop); `last.json` (written in `main()`'s `finally` before `loop.json`
  is removed; reasons stop / max-items / until-idle / item-done / max-blocked /
  stopped-for-person / hard-stop / refused / error; never written over another live loop);
  edit-lock precheck (first condition of `tree_state()`, so it holds the auto-triage too; live =
  pid runs and its creation time <= `started_epoch` + 2 s via `process_created()` on top of
  `process_ident()`; a lock without readable fields younger than 5 s counts as being written);
  `starting` / `resumed` written on leaving `paused`; `start --new-window` (options rebuilt from
  the parsed values, `CREATE_NEW_CONSOLE`, title set by the child through a hidden
  `--console-title`, hidden test option `--new-window-hidden` = `STARTF_USESHOWWINDOW` +
  `SW_HIDE`); `start --item SLUG`; `status --json` keys `kill`, `last`, `edit_lock`, `log`;
  `status` line `control: kill requested`.
- `bin/backlog-loop.sh`: `kill` command, `--item`, `--new-window`, the new files in `--help`.
- Measured before using `--new-window-hidden` in tests (this machine: DelegationConsole
  `{00000000-...}` = "let Windows decide"): a `CREATE_NEW_CONSOLE` + `SW_HIDE` child got a
  `ConsoleWindowClass` window, `IsWindowVisible` 0, no new `WindowsTerminal.exe` (no defterm
  handoff); `SetConsoleTitleW` succeeded.
- Final: `python -m unittest tools/backlog/test_loop.py tools/backlog/test_traces.py` ->
  `Ran 128 tests in 163.7s OK`; `python tools/test_bin_help.py` -> `Ran 1 test OK`.
- Owed to a person: one visible run of `bin/backlog-loop.sh start --new-window` (a real window
  titled "Backlog loop", Ctrl+C in it = hard stop, closing it = a killed loop continued by the
  next start).

## backlog.py additions (T013-T018, T080, T100)

2026-10-30. Contract: `contracts/backlog-cli-additions.md`. Files: `tools/backlog/backlog.py`,
`tools/backlog/test_backlog.py` (loop.py / test_loop.py not touched).

- Precondition checked: `tools/backlog/fixtures/valid/specs/243-example/README.md` is in git
  (feature 265, commit 43b38d5f), so the Inbox note about a fixture folder missing from git no
  longer applies; the item is not in `backlog/items/` any more.
- Baseline: `python -m unittest tools/backlog/test_backlog.py tools/backlog/test_traces.py` ->
  `Ran 90 tests ... OK` (71 + 19).
- Tests first: 40 new tests (classes `BoardJsonTests`, `ShowJsonTests`, `CheckLegendJsonTests`,
  `RefTests`, `InputJsonTests`, `JsonResultTests`, `ReorderAndPositionTests`, `BodyStepTests`,
  `DecideTests`); first run `Ran 111 tests ... FAILED (failures=69)` (subtests counted), only the
  new tests failing.
- Implemented:
  - Sources: `TreeSource` (working tree) and `GitSource` (`git rev-parse --verify REF^{commit}`,
    `git ls-tree -r -z REF -- backlog`, `git ls-tree -z REF -- specs/` for the folder names,
    one `git cat-file --batch`); `Backlog(root, src)`, `parse_item` / `parse_overview` /
    `first_line` / `check()` read through the source. `--ref` is accepted by `board`, `list`,
    `show`, `next`, `legend` (also as a global option); `check` and every changing command give
    exit 2. Unknown ref: `refused: unknown ref 'x'` (exit 1).
  - `revision` = SHA-256 of the bytes as read (`Item.revision`, `Overview.revision`); files are
    now decoded from one read of their bytes.
  - `board --json [--with-body]`, `show <slug> --json`, `check --json`, `legend --json` (also text
    forms without `--json`).
  - Global `--input-json -` (keys per command as in the contract; repeated / unknown key, wrong
    value kind -> refused; invalid JSON or not an object -> exit 2 `usage: invalid JSON on stdin
    (...)` on stderr, nothing read or written; multi-line texts get LF and lose blank lines around
    them). `--title` (new), `key=value` (set), `text` (log), `--reason` (block) are no longer
    argparse-required but still required (same usage message, exit 2) when JSON does not give them.
  - Global `--json` (also after the command) for every changing command except `lock`
    (`--json lock` = exit 2): one result object; `written` from `write_text` and the folder walk
    of `remove` (deleted files listed after the deletion).
  - `reorder`, `set --position`, `body`, `step`, `decide`, `reply`; `cmd_move` split into
    `apply_move` (in memory) and `cmd_remove` into `remove_item`, reused by `decide`.
- Interpretations (contract silent): `position` is null in the sorted sections (Inbox, Parked,
  Rejected); a row whose item cannot be read has every header field null (the item is listed in
  `unreadable`, a dangling row too); `files.issue.head` = the `key: value` lines of `issue.md`
  before its first blank line, as an object; `show` findings = check findings under the item's
  folder plus `BACKLOG.md` findings that name the slug; options are recognised in three forms
  (`### A`, `- **A`, `- A -`), the last because real items use it.
- Deviations: `body` refuses a result that adds a body finding (an item that already had one can
  still be edited); `step` refuses ticking a step already done (and unticking an open one) so a
  double click cannot log twice; `decide --type` only with `move:` / `keep` (meaningless with
  `set-type`, `park`, `close`); `new` checks the body rules before writing only when the texts come
  from `--input-json` (the command-line form behaves as before).
- Measured on the real backlog (read-only): `board --json` 0.24 s, `--ref main board --json
  --with-body` 0.32 s; `check --json` -> `{"total": 0, ...}`; worktree and `main` boards equal
  except `revision` - this checkout has `core.autocrlf=true`, so the tree's bytes are CRLF and
  the blobs LF: a revision is comparable only with one read from the same source.
- Final: `python -m unittest tools/backlog/test_backlog.py` -> `Ran 111 tests ... OK`;
  `python -m unittest tools/backlog/test_traces.py` -> `Ran 19 tests ... OK`;
  `python -m unittest tools/backlog/test_loop.py` -> `OK`; `python tools/test_bin_help.py` -> `OK`.

## Verification of the Python additions (main session)

- `python -m unittest tools/backlog/test_backlog.py tools/backlog/test_traces.py tools/backlog/test_loop.py`
  -> `Ran 239 tests ... OK`; `python tools/test_bin_help.py` -> `OK` (run independently of the agents).
- Added `orphan` to `loop.py status --json` (the same process checks the text output makes - the
  claude of a dead loop or its auto-triage still working), so the app needs no process test of its
  own; covered in `test_status_json_has_the_new_keys` and the orphan test.

## Setup and the app shell (T001-T012, parts of T023-T037)

- Repository hygiene (T002-T004): `.gitignore`, `.gitattributes`, `.editorconfig`,
  `normalize_config.json` (both lists). `normalize.ps1 -DryRun` cannot run here (it requires
  PowerShell 7; only 5.1 is installed); instead the exclude patterns were checked with the same
  `WildcardPattern` matching normalize.ps1 uses: `node_modules/.bin/vite.ps1`,
  `packages/web/node_modules/x/y.h`, `packages/web/dist/assets/a.config` excluded; the app's own
  `packages/web/src/x.ps1` and `src/main.cpp` not excluded.
- Packages pinned exactly (`.npmrc` `save-exact`, `ignore-scripts`); deviations from analysis A3 §6:
  TanStack Table 8.21.3 instead of 9.3.1 (stable, well-known API), `@types/node` 24.19.2 (the
  runtime is Node 24), `@types/react` 19.3.0 (19.3.1 does not exist); `react-resizable-panels` not
  installed (CSS grid suffices).
- Documentation gate (FR-050): ESLint `jsdoc/require-jsdoc` (functions, methods, classes,
  interfaces and their members, type aliases, class properties, top-level and exported variables),
  `require-description`, `require-param`, `require-returns`, `require-file-overview`,
  `tsdoc/syntax`. Negative control: a file with an undocumented const, function, interface and
  arrow function and a `shell: true` -> 9 errors (all caught).
- TypeDoc removed (deviation from R22): with `validation.notDocumented` it reported nothing for an
  obviously undocumented exported function (negative control did not fail - a finding), and it
  warned about the inner properties of zod-inferred types, which cannot be documented. ESLint is
  the enforced gate.
- Repository-rules test (T011): SPDX header, `@file` overview, UTF-8 without BOM, LF, no
  `shell: true` / `exec(` in every source file.
- Security gate (T032-T033): 17 tests of contracts/security.md pass. Mutation check: switching off
  the Host check, the Origin-required rule and the token check each made tests fail (1, 1, 2).
  A changing request without `Content-Length` is refused with 411 (browsers always send it for a
  text body; with a declared length Node never reads more), so the 256 KiB limit cannot be
  bypassed with a chunked body.
- Backlog tool adapter (T031): 9 tests against a fixture repository, incl. a 20,000-character text
  with backticks, `$(rm -rf x)`, quotes, backslashes, newlines and Czech letters stored byte-exact
  through `--input-json -`, `--ref main` reading git objects, a refusal writing nothing.
  Findings while wiring it: the tool prints `effort: -` as null; `files.issue.head` is an object of
  the `key: value` lines of `issue.md`; a revision read from the working tree (CRLF with
  `core.autocrlf=true`) differs from the same file read from `main` - revisions are compared only
  between reads of the same source.

## Server, web client and end-to-end verification

- Server modules: services with the read-source rule, read/write/tray/loop/runs/settings routes,
  write queue under the edit lock, change tray with snapshot undo and commit, runs service with
  trace tailing, notifications. An agent added feature records, the release page and the AI job
  runner (237 tests at its hand-over; it measured on the real `claude` 2.1.314 with `--model haiku`
  that `--json-schema` output arrives as `structured_output` of the final `result` event).
- Measured while building: tight-loop open-read-close reads DO collide with Python's `os.replace`
  of the same file (WinError 5, a test claimed otherwise and failed - corrected): the app reads only
  append-only traces of a live run; the loop's replaced files are read by `loop.py status`.
- Lint of the web client (React Compiler rules) found real defects, fixed without suppression:
  state copied from properties in effects (now adjusted during render), a component created
  during render, `Date.now()` during render, and the notification settings applied only on the
  Settings page (now at app start).
- End-to-end (Playwright on Edge, fixture repositories, real tool, real loop with the fake claude in
  a hidden console window, AI fake): 23 tests pass - US1 Q1-Q3 + keyboard; US3 Q8 (mouse drag and
  Alt+arrow give exactly the tool's `reorder`, no item log lines), triage, block/unblock, Q11/Q12
  tray undo and commit (only `backlog/`, `backlog(app):`), Q9 read-only while a run holds the lock,
  bulk; US2 Q4/Q5 start/pause/resume/stop, Q7 hard stop continued by the next start, Q6 app restart
  during a run; US4 Q13 20,000-character text with shell characters byte-exact and not run (canary
  file absent), Q14 decision and person step, section edit, close undone; US5 Q15 AI draft from a
  Czech sentence (nothing written before Create), cancel; US6 Q16 one chosen item, release page
  without publish; axe WCAG 2.2 AA in both themes on 15 screens; no horizontal scroll at 900 px.
- Defects the e2e tests found and fixed: rows `aria-disabled` while reordering was not allowed;
  an item change sent a stale board revision right after the user's own change (spurious
  "changed underneath" - now only positioned moves carry the board revision, and reorders use the
  revision the server returned); Ctrl+Z relied on a not-yet-loaded tray; the close button shared its
  accessible name with the dialog's close button; light `--ok` contrast below AA; `Alert` split
  mixed text into flex columns.
- Q18 / SC-006 soak: 20 loop runs with the app open on the live and home pages (polling and
  streaming): 20 closed rows, no `PermissionError`/`WinError`/"cannot be written" in `loop.log`, no
  wait caused by the app, lock free, no orphan, tray empty, tree clean (22 s with the fake claude).
- SC-001 with `bin/start-backlog-app.sh`: first start with `npm ci` and the build 17.8 s; later
  start 1.0 s; a second launch while one runs reuses it (1.0 s, new start code).
- SC-005 on a 508-item repository built through the tool: API filter / full-text 3-23 ms; browser
  from Enter to the filtered rows 176-362 ms.
- Note: TanStack Router stores a search value with quotes JSON-escaped in the address (deep links
  work; only the raw address text differs).

## Polish: documentation and the inline-comment review (T012, T126-T128, T132)

- T012 had been marked done without `tools/backlog-app/README.md` existing - found while writing
  the polish documentation, now written (purpose, run, develop, test, architecture on one page,
  rules, dependencies with licences read from the installed packages: 49 MIT, 3 Apache-2.0, 1 ISC,
  1 BSD-3-Clause (lint only), 1 MPL-2.0 (axe, accessibility tests only)).
- T126-T128: the 242 and 247 CLI contracts carry amendment notes pointing to this feature's
  additions; the `tandem-backlog` skill uses the new commands (body, step, decide, reply, texts on
  stdin) and explains the app's edit lock and `backlog(app):` commits; `CLAUDE.md` and
  `architecture/12-project-reference.md` name the app. The `--help` of both launchers already
  listed the new commands.
- T132 `npm run check`: typecheck, lint with the documentation rules, format, 248 unit tests - pass.
- T132 inline comments, measured per file (code lines per inline comment): `backlog/tool.ts` 66,
  `runs/service.ts` 75, `loop/view.ts` 47, `services.ts` 50, `backlog/tray.ts` 33,
  `backlog/read-model.ts` 31 were thin; comments added at the decisions (exit 1 written-with-
  findings vs refused, all-or-nothing undo check, ticked outside paths revalidated, unstage on a
  failed commit, branch priority of the loop view, stale lock, read source rule, coalesced
  reloads, degraded mode, journal pairing, truncated trace refold).
- Defects found by reading for the comments, fixed:
  - `runs/service.ts` `detail()` read `meta.json` of any run that was not the followed live run -
    also a run that started a moment ago (before the 1 s follower picked it up), whose `meta.json`
    the loop replaces atomically (A2 §5.1 hazard), and cached that unfinished fold as final. Now
    `meta.json` is read and the cache written only for a run with an index line (the loop appends
    it after the final `meta.json`, `loop.py` `finish_trace`). Test added; negative control: the
    test fails on the old code.
  - The tray's `outside` counter in `tray.changed` and the state view was a constant 0; it is now
    counted from `git status` and refreshed on every repository change.
  - Two timers outlived `stopAndDrain` (the run-end announcement, 4 s, and the tray counter's
    `git status`) - the class of leftover process that made fixture cleanup fail with EPERM
    earlier; both are now cleared or awaited.
  - `live.base` from the run record went to `git log base..branch` unchecked; only a hex hash
    passes now.

## Quickstart scenarios Q1-Q22 (T133)

| # | How driven | Result |
|---|---|---|
| Q1 | Fixture e2e (`us1-browse`), and on a clone of the real repository (`main` at f7faf9ae): the app's `/api/board` against `backlog.py list --json` | PASS - 257 items in 7 sections, same order, the 11 header fields and relations equal. The only difference: `position` is null in the unordered sections (Inbox, Parked, Rejected) where `list` numbers the rows - by design, now written into `contracts/backlog-cli-additions.md` |
| Q2 | e2e `us1-browse` (filter in the address, new tab); SC-005 on 508 items | PASS - exact rows, deep link; API 3-23 ms, browser 176-362 ms |
| Q3 | e2e `us1-browse` | PASS |
| Q4 | e2e `us2-loop` (real loop, fake claude, hidden console window) | PASS - live view within the 15 s test bound; SC-004 below |
| Q5 | e2e `us2-loop`: pause/resume/stop from the app on a loop the app started, and (added in T133) on a loop started outside the app with `loop.py start` | PASS |
| Q6 | e2e `us2-loop` (app stopped during a run, new app) | PASS |
| Q7 | e2e `us2-loop` (typed hard stop, `killed`, next start continues) | PASS |
| Q8 | e2e `us3-order` (drag, Alt+Down, triage, block/unblock) + API test against the tool on a second copy | PASS - byte-equal files, `check` 0, no item log lines from reorders |
| Q9 | e2e `us3-order` (lock held) + API tests (lock, not on `main`) | PASS |
| Q10 | API test `write-path` (stale board revision -> 409 `changed-underneath`, nothing written) | PASS |
| Q11 | e2e `us3-order` (tray commit, prefix, only `backlog/`) + `commitTrayForLoop` before start (us2) | PASS |
| Q12 | e2e (Ctrl+Z) + API test (undo refused after an outside edit) | PASS |
| Q13 | e2e `us4-record` + API test (20,000 characters, shell characters, canary file absent) | PASS - texts go only through stdin by construction (`--input-json -`), so no command line can carry them |
| Q14 | e2e `us4-record` | PASS |
| Q15 | e2e `us5-us6`: draft from a Czech sentence, cancel, and (added in T133) a question answered with item links | PASS (fake claude: the real model's answer quality is not tested) |
| Q16 | e2e `us5-us6`: one chosen item, order unchanged, (added in T133) the run's transcript opened; bulk with 2 items in `us3-order` (the same per-item path as 5) | PASS |
| Q17 | 17 security tests + 3 mutants; by hand against the app on the clone: no token 401, foreign Origin 403, used start code 401, foreign Host 421 | PASS |
| Q18 | e2e `soak` (20 runs) | PASS |
| Q19 | e2e `a11y` (axe WCAG 2.2 AA, both themes, 15 screens, 900 px) + keyboard journeys of US1 and US3 | PASS |
| Q20 | `npm run lint` with the jsdoc/tsdoc rules (TypeDoc's `docs:check` was dropped: its negative control did not fail, see above) | PASS |
| Q21 | `bin/start-backlog-app.sh` | PASS - 17.8 s first, 1.0 s later |
| Q22 | Not driven: needs the real repository and a real loop night | PERSON STEP for the maintainer |

## Independent review (T134) and its fixes

A refute-first review agent (security gate, write path, loop control, file handles, docs) found
3 MUST, 4 SHOULD and 6 NOTE; its own checks that held: Host first (421), Origin and
Sec-Fetch-Site, JSON + Content-Length, constant-time token, no cookies or CORS, static manifest,
identifier patterns, no shell anywhere, `claude` with Read/Grep/Glob only, `--ref main` opens no
working-tree file (audit hook on the real repository).

| # | Finding | Fix | Test (negative control) |
|---|---|---|---|
| M1 | The gate after taking the edit lock could use a loop view polled before the lock (`refresh()` returned the last view while a poll ran) - a run could start on a backlog the app was changing | `LoopMonitor.fresh()` / `RepoMonitor.fresh()`: wait for the poll in flight, poll again; used by the write queue, the AI job start, the stale-lock release and the loop start | `LoopMonitor.fresh` test; mutation `loop-fresh` caught |
| M2 | The state folder inherited `Authenticated Users:(M)` / `Users:(RX)` from `.git` on D: - any local user could read the launcher secret and get a session; undo files named any path | The app restricts the folder to its user and SYSTEM at every start (`icacls /inheritance:r`, by SID; verified with `icacls`); if that fails the launcher secret is off and not written. Undo writes only paths of the change inside `backlog/` | undo with a planted path refused; mutations `undo-path-outside`, `backlog-path` caught |
| M3 | Tasks T081-T083 named test files that did not exist; 7 mutations survived | `write-gate.test.ts` (every rule), `write-safety.test.ts` (edit lock held and released, item revision, newest-only undo, undo through the gate, item files from the listing, commit path rule, serialisation) | all 22 mutations of `mutate2` caught (below) |
| S1 | git without time limits inside the edit lock could hold the loop forever | `GIT_TIMEOUT_MS` 60 s on every git call (commit 120 s for hooks, history batch 120 s) | - |
| S2 | A missing or damaged undo file "undid" nothing and dropped the change | refused, the change stays pending | test; mutation `undo-file-missing` caught |
| S3 | A tool call that failed after writing (crash, time limit) left unrecorded files | `toolChangeForTray`: the files that differ from the snapshot go into the tray as "failed partway" (undoable) | test with a failing tool; mutation `partial-write` caught |
| S4 | Bulk `set` put the title on the command line | title on stdin like `/fields` | - |
| N | Commit without pathspec could include later outside edits of tray files | the commit refuses a tray file whose content is not what the app left, and commits with `-- <paths>`; paths neither on disk nor known to git are dropped (a created-then-deleted path made `git add` fail) | test; mutations `commit-outside-edit`, `commit-filter` caught |
| N | A live loop that stopped answering ("dead") opened the gate | closed as `loop-between-runs` while the process lives | test; mutation `gate-dead-live` caught |
| N | `taskkill /T` at shutdown or a start timeout killed the loop being started (a child of `start --new-window`) | `keepDescendants`: only that process is ended | - (not driven: needs a shutdown inside the 15 s start window) |
| N | Run lock reads by the app's 2 s status poll raise the chance that `backlog.py lock update/release` meets an open handle | not in this feature: Inbox item `run-lock-update-release-no-retry` | - |
| N | `readProgress` accepted a branch `..` | only `NNN-name` branches are joined into a path | - |
| Doc | Thin inline comments in `trace-event.ts`, `run-state.ts`, `ai/apply.ts` | comments at the decisions | - |

Found by me while answering it: AI result legend words (`type`, `area`, `who`, `effort`) became
tool arguments unchecked - now a word pattern (argparse would have refused an option-like value,
the tool an unknown word; the pattern is the boundary).

**Mutation run** (scratchpad `mutate2.py`, server unit tests, file restored after each): 22 of 22
caught - the reviewer's 7 survivors (`edit-lock-acquire`, `gate-between-runs`, `revision-item`,
`undo-newest`, `undo-in-queue`, `item-files`, `commit-filter`), its 6 caught ones again, and 9 for
the fixes above (`undo-file-missing`, `undo-path-outside`, `commit-outside-edit`,
`gate-dead-live`, `loop-fresh`, `read-fresh`, `partial-write`, `runs-meta-guard`,
`backlog-path`). `commit-filter` first survived because the new hash check stopped the planted
entry earlier; the test now gives it its true hash so only the path rule stands in the way.

**e2e race found while re-running** (not by the review): Q11/Q12 failed 4 of 4, also on the
committed code - after the app's own change (undo) the answer came before the read model reloaded
(250 ms debounce + reload), so the page reloaded the old board and its next reorder sent a stale
revision (409 `changed-underneath`). The write queue now awaits `ReadModel.fresh()` after
releasing the edit lock; mutation `read-fresh` caught by a test that reads the board right after a
move. Full e2e afterwards: 26 of 26 (the new Q5 test first failed on its own arguments: a terminal
start needs `--new-window`, else `spawnSync` waited for the whole loop).

Python suites after the changes: `test_backlog` + `test_loop` 220 OK, `test_traces` OK,
`tools/test_bin_help.py` OK. Unit tests 278.

## SC-004 live progress (T130 completed)

T130 had been marked done without the SC-004 measurement; done now with two scripts (scratchpad,
not in the repository), each on a fixture repository with the real loop and the app:
- **Trace lines**: a wrapper around the fake claude (`hang` step) writes an assistant text line with
  the wall-clock time into `trace.jsonl` every 2 s; a client follows `/api/runs/{id}/stream` and
  takes the arrival time of each line. 20 minutes (stopped early at the maintainer's request -
  SC-004 asks for 2 hours): 600 of 600 lines, median 745 ms, max 1490 ms, none over 5 s; the
  server's working set 100 MB at 12 and at 20 minutes (private 61 -> 62 MB), no reconnect.
- **Task progress**: a wrapper sets a feature branch in the run lock and ticks one task of
  `specs/<branch>/tasks.md` every 4 s; a client follows `/api/events` (`run.changed`). The server
  read `tasks.md` only when more than 5 s had passed (plus the 1 s follow tick): with that, 8 of 40
  counts were never shown (the page jumped over them) - a tick could wait up to about 6 s. Now every
  3 s (`PROGRESS_MS`): 40 of 40 counts shown, median 1652 ms, max 2992 ms. (A first version of the
  script lost events by racing `reader.read()` against a timer - 1 of 40 seen; fixed before these
  numbers. The comparison with the corrected "until this or a later count is shown" metric was not
  repeated for the old interval: stopped with the rest.)
