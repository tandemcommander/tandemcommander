# Research: Backlog web app (344)

**Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

This file records the decisions of the plan. The evidence is in the four analysis reports of
independent agents, cited as A1-A4:
[A1](analysis/01-backlog-operations.md) backlog data and operations,
[A2](analysis/02-run-loop-monitoring.md) loop, traces and live monitoring (measured on scratch
repositories with the real `loop.py` and the fake claude),
[A3](analysis/03-tech-stack-security.md) technology, versions, licences and localhost security
(versions read from the npm registry on 2026-10-30),
[A4](analysis/04-ux-interactions.md) journeys, screens and interaction rules.
Where the reports disagreed, the decision below says which way and why.

---

## R1 - The application drives the existing tools; it owns no backlog data

**Decision**: The backend is a reader and an orchestrator. Every change of backlog data is a
call of `tools/backlog/backlog.py`, every loop action a call of `tools/backlog/loop.py`. The
application keeps no copy of the backlog; it re-reads after every change and on every file
notification. Its own state (settings, saved views, the change tray, caches, its event log)
lives in `<git-common-dir>/tandem-backlog-app/`, never in the tracked tree.

**Rationale**: the tool owns the format and its 18 check rules (A1 §3, §9); a second writer of
the format would drift. Loop state belongs to the loop (A2 §5.2). Keeping app state in the git
common directory keeps the working tree clean, which the loop's precheck requires (A2 §5.2), and
works for every worktree of the repository.

**Alternatives**: parsing and writing the Markdown in TypeScript (rejected: duplicate format
owner); a database (rejected: a second source of truth); state in `%LOCALAPPDATA%` (rejected:
per-repository state would need a key; `.git/` already holds the loop's state).

## R2 - Frontend: React 19 + Vite 8 single-page app + Tailwind 4 + shadcn/ui on Radix

**Decision**: React 19.3.1, Vite 8.3.5 (plain SPA, no SSR), Tailwind CSS 4.3.3,
shadcn/ui components generated into the repository on the Radix base (`radix-ui` 1.8.1).
Libraries: TanStack Table 9 (backlog tables), TanStack Query 5 (server state, SSE-driven
invalidation), TanStack Router 1 (typed routes and search params = filters in the address),
dnd-kit core 6 / sortable 10 (drag and drop with keyboard sensor and announcements), cmdk
(command palette), sonner (toasts), react-resizable-panels (split panes), react-hotkeys-hook,
react-markdown 10 + remark-gfm (no raw HTML), CodeMirror 6 via @uiw/react-codemirror (section
editor), react-virtuoso (trace view), Recharts 3 (run statistics), react-hook-form + zod
resolver, lucide-react icons, date-fns, zustand (small client state). Exact pins: A3 §6.

**Rationale**: every widget the journeys need (A4 §3) has a maintained, documented recipe in
this stack; agents (who will maintain the code) know it best; shadcn copies components into the
repository as editable, documentable source; Tailwind 4's CSS variables give one token set for
both themes. Vite was verified as the right build tool (A3 §1.4): fast production build,
middleware mode lets the backend serve the dev server on the same port with the same security
gate.

**Alternatives** (A3 §7): Svelte 5/SvelteKit (thinner ecosystem, SSR server duplicates the
backend), Vue 3 + PrimeVue 5 (proprietary licence - incompatible), Vue 3 + Naive UI (viable,
weaker DnD/palette story), Solid (smallest ecosystem), React + Mantine (no core data table,
library-owned styling), Next.js and other SSR frameworks (a second server complicates the
gate). shadcn on Base UI (its new default) is equally possible; Radix is chosen because cmdk
already depends on Radix - one primitive family. Changing later is cheap.

## R3 - Light and dark theme without a flash

**Decision**: three modes, *System* (default, follows `prefers-color-scheme` live), *Light*,
*Dark*. A tiny external script `theme-init.js` (CSP forbids inline scripts) reads the choice from
`localStorage` and sets `class="dark"` on `<html>` before the stylesheet paints. All colours are
CSS variables defined twice (light, dark); severity bands, statuses, outcomes and focus rings
each have a token per theme, checked for WCAG AA by axe in the end-to-end tests. The choice is
also stored in the server settings, so it survives a cleared browser storage.

**Rationale**: A3 §1.6, A4 §4.11. Browser storage is per origin and the origin includes the
port, hence the stable default port (R17).

## R4 - Backend: Hono inside an own `node:http` server

**Decision**: an outer `node:http` server runs the security gate (R18) on every request, then
hands `/api/*` to Hono (4.13.14, via `@hono/node-server` `getRequestListener`) and everything
else to an exact-match static manifest of the built SPA (or to Vite middleware in `--dev`).
Request and response bodies are validated with zod 4 schemas from the shared package; the
server also validates the JSON the Python tools print, so a format drift fails loudly.

**Rationale**: Hono has zero runtime dependencies, zod-native validation and in-process tests
(`app.request()`); A3 §2.1. `serveStatic` is not used (Windows `%5C` traversal history, A3 §2.1,
§4.7).

**Alternatives**: Fastify (heavier, second schema language), Express 5 (untyped core, no SSE
helper), plain `node:http` only (hand-written routing).

## R5 - Real-time: Server-Sent Events read with `fetch`

**Decision**: one event stream per tab `GET /api/events` (backlog, gate, loop, run, tray, AI job
and notification topics) and one per open trace view `GET /api/runs/{id}/stream`. The browser
reads them with `fetch` and `eventsource-parser` (MIT) instead of `EventSource`, so the token
travels in the `Authorization` header like every other call; the client reconnects with
`Last-Event-ID`. For a trace stream the event id is the byte offset in `trace.jsonl`, so a
reconnect resumes exactly.

**Rationale**: traffic is one-way; SSE is plain HTTP and passes the same gate; WebSocket would
need a separate upgrade path, its own Origin check and the `ws` dependency (A3 §2.2). A3
offered the token as a query parameter for `EventSource`; the fetch reader removes the only
place the token would appear in a URL, at the cost of about 60 lines of reconnect code.

## R6 - TypeScript runs natively in Node 24; type check with TypeScript 6.0

**Decision**: the server runs as `node packages/server/src/main.ts` (Node >= 24.15.0, or 26.x);
no server build. `tsconfig` enforces erasable syntax only (no enums, namespaces with values,
parameter properties or decorators), `verbatimModuleSyntax`, `.ts` extensions in relative
imports. `tsc -b` with TypeScript 6.0.3 type-checks everything; TypeScript 7 is excluded by the
peer ranges of typescript-eslint and TypeDoc (A3 §2.5, measured).

**Alternatives**: tsx (extra dependency), compiled output (build step for no gain).

## R7 - Child processes: Python directly, argument arrays, text on stdin

**Decision**: one module (`server/src/proc/`) spawns every child: absolute executable, argument
array, `shell: false`, `windowsHide: true`, `cwd` = repository root, stdin closed unless JSON is
written to it, `PYTHONUTF8=1`, `PYTHONIOENCODING=utf-8`, output decoded with `StringDecoder`.
The backlog tool and the loop are run as `python -X utf8 tools/backlog/backlog.py ...` and
`python -u tools/backlog/loop.py ...` (`PYTHON` honoured like in the `bin/` scripts), not
through `bash.exe`. User text never appears on a command line: it is sent as a JSON object on
stdin (R8, `--input-json -`). ESLint forbids `exec`, `execSync` and `shell: true`. The app's
own children (tool calls, AI jobs) are ended with
`%SystemRoot%\System32\taskkill.exe /PID <pid> /T /F` (full path: Git's tools shadow System32,
see memory rule) when cancelled or at shutdown.

**Rationale**: Git Bash rewrites POSIX-looking arguments of native programs (a title like
`/fix the /tmp handling` would change), and `bash.exe` on PATH can be WSL's (A3 §2.4); argv text
has a 32,767-character limit, may start with `-` and is visible in process listings.

## R8 - Additions to the backlog tool (backward compatible, standard library only)

**Decision**: `tools/backlog/backlog.py` gets the commands and options in
[contracts/backlog-cli-additions.md](contracts/backlog-cli-additions.md), each with tests in
`tools/backlog/test_backlog.py` and an amendment of `specs/242-backlog-system/contracts/cli.md`:

| Gap (A1 §9) | Addition |
|---|---|
| G1 one item | `show <slug> --json` |
| G2 board, check | `board --json [--with-body]` (sections incl. note rows, `last_triaged`, unreadable items), `check --json` |
| G3 text on argv | global `--input-json -`: text fields from a JSON object on stdin |
| G4 body edits | `body <slug> --section S` (text from stdin; replace / add / remove one optional section, validated) and `step <slug> <n> --done/--undone [--note]` |
| G5 reorder | `reorder --section S` (the full new order of an ordered section from stdin; one write; no item log line; `Last triaged` set) |
| G6 legend | `legend --json` |
| G8 reply | `reply <slug> --state not-sent|sent` |
| G9 read main during a run | `--ref REF` for `board`, `list`, `show`, `next`, `legend` (reads git objects, opens no working-tree file) |
| G11 results | `--json` result object for every changing command |
| `set` loses the position | `set ... --position N` (keep or choose the place when the section changes) |
| decision (skill `decide`) | `decide <slug> --option X` + sentence on stdin: one log line `maintainer decision YYYY-MM-DD: ...`, then the chosen follow-up (`--then move:<section>[@N] | set-type:<type> | park | close`) in one write |

G7 (stale view) is solved in the app (R12). G10 (a write lock) is the edit lock of R9. G12
(commits) stays outside the tool (R11). No `batch` command: bulk changes (FR-033) are
sequential single commands with a per-item result.

**Rationale**: the tool stays the single owner of the format; each addition is small, testable
and useful to the skills too (G4 lets `/tandem-backlog` stop hand-editing bodies).

## R9 - Write gate and the edit lock

**Decision**: the server computes one **write state** (data-model *WriteGate*) from
`loop.py status --json`, the loop's state files, the run lock, `git rev-parse --abbrev-ref HEAD`,
`MERGE_HEAD` and the check result, and pushes it to every tab. Changing controls read it.
Every queued operation runs under an **edit lock** `<git-common-dir>/tandem-backlog-edit.lock`
(created with exclusive create; content: pid, process creation time, started, purpose),
in this order: take the edit lock -> re-evaluate the gate (lock free, loop not live or
`paused`, no triage, branch `main`, no merge) -> check preconditions (R12) -> run the tool ->
re-read -> release the lock. The loop gets one new precheck condition: a live edit lock means
`waiting: the backlog app is changing the backlog` (contract
[loop-cli-additions.md](contracts/loop-cli-additions.md)); and on leaving `paused` the loop
writes its state before the precheck, so a resume races at most into a refused app operation,
never into a run on a changed backlog. A stale edit lock (its process gone) is ignored by the
loop and replaced by the app.

When the loop runs unpaused but idle or waiting, the app offers *pause, change, resume*
(A4 §4.1): it calls `pause`, waits for `state: paused`, applies the changes, and the resume
from the app commits the tray first (R11).

**Rationale**: A1 §6.3 rule 2 found the time-of-check window (the maintainer resumes the loop
between the gate check and the write); the run lock cannot be reused because it means "a run"
in three contracts. An edit lock the loop respects closes the window with one small loop change.

## R10 - What is read while a run is active

**Decision**: tracked files are read from the working tree only when HEAD is `main` and no run
holds the run lock. Otherwise the board, items, legend and next-up come from `main`'s git
objects (`backlog.py --ref main`), the item history and feature records from git objects, and
only the live run's own files (`specs/<BRANCH>/tasks.md`, `fix-log.md`) are read from the
working tree with open-read-close at most every 5 seconds, tolerating their absence.

**Rationale**: during a run the tree is on the run's branch (A1 §2.3 surprise: *In progress* is
empty on `main` by design), and every read of a file the run replaces risks a failed atomic
replace: measured, an open handle made Python's `os.replace` fail with WinError 5, and
`lock update` / `run-log` have no retry (A2 §5.1). `main`'s objects are what the loop takes the
next item from. This is why the spec's edge case shows the main line during a run (A4 had
proposed the branch's view; changed for safety).

## R11 - Commits: a change tray committed on `main`

**Decision** (maintainer's answer Q2): every operation is recorded in the tray (operation, slug,
files, reason, before/after file hashes, undo snapshot). The tray counter is always visible.
*Commit* stages exactly the tray's paths under `backlog/` (`git add -A -- <paths>`; refused if
anything else is already staged), commits with the maintainer's git identity and a proposed,
editable message `backlog(app): <summary>` with one body line per operation (and the reasons of
closes, which live nowhere else). Backlog files changed outside the app are listed as
"changed outside the app" and included only when the maintainer ticks them. Before *Start* /
*Resume* / *Run item* from the app the tray is committed automatically (asked once, the answer
remembered). Commits never carry AI trailers and are never pushed.

The prefix `backlog(app):` is deliberate: `traces.py` attributes commits after a run's base to
the run by the prefixes `[NNN]`, `backlog: auto-triage` and `backlog: <slug> ` (A1 §7); the app's
commits must not match them.

**Undo** (FR-035): before commit, the last operations can be undone in reverse order; an undo
restores the snapshot of the touched files only when their current hashes still equal the
operation's after-hashes (nothing else changed them), then re-runs `sync` and `check`. A
`remove` (close) is undoable only before commit and restores `evidence/` too. After the commit,
inverse operations are offered.

**Alternative**: one commit per operation (rejected by the maintainer: noisy history, no undo).

## R12 - Optimistic concurrency

**Decision**: every changing request carries the revisions the user's view was based on - the
board revision (hash of `BACKLOG.md`) for moves and reorders, and the item revision (hash of its
`desc.md`) for item changes. Under the edit lock the server recomputes them; a difference
refuses with `409 changed-underneath` and the new state. Drops of a drag are applied relative
to the target's slug, not to a row number (A4 §4.4).

**Residual risk**: a Claude Code session writing the same file within the ~0.3 s between the
check and the tool call is not excluded (it does not respect the edit lock). Accepted: the
tool's own check runs after every change and its findings are shown.

## R13 - Starting, stopping and hard-stopping the loop

**Decision**: the application drives the loop and never hosts it (A2 §2.4):

- **Start** runs `loop.py start --new-window <options>`: the loop re-launches itself in a new
  console window (`CREATE_NEW_CONSOLE`) and returns. The loop then has its own console: claude
  gets no extra windows, Ctrl+C in that window keeps its meaning, closing the app changes
  nothing, and the window shows the loop's lines as when started by hand.
- **Pause / resume / stop** call the loop's own commands, never the flag files.
- **Hard stop** calls the new `loop.py kill`: a flag the loop checks every tick and handles
  exactly like Ctrl+Break (`hard_stop`: claude's tree killed, run phase `killed`, lock kept,
  exit 130). It works for a loop started anywhere. Before it, the app warns when the trace
  shows a running GUI probe (`run_on_hidden_desktop.ps1`) or an auto-triage.
- **Run one item** calls `loop.py start --new-window --item <slug>`: the loop's eligibility
  check through `backlog next --slug`, one run with trace, continuation and verdict, then the
  loop ends.
- The loop also writes `loop.log` (its window lines) and `last.json` (why and how it ended), so
  the app can tell what a loop did and why it stopped, wherever it was started.

**Rationale** (A2 §2.2, §2.3, measured): Node's `child.kill()` is TerminateProcess without the
loop's handler and leaves claude running; a plain child dies with the server and leaves claude
alone; `detached: true` gives every claude a visible console; `taskkill` of the loop leaves the
records saying `running` and needs the next start to infer the kill; killing claude alone is
misread as an error and counted. A kill flag the loop handles itself is the only way that keeps
the loop's records exact. This also lets the spec offer hard stop for terminal-started loops
(FR-017 amended).

**Alternatives**: hosting the loop through a Python relay that sends `CTRL_BREAK_EVENT` (works,
but the relay dies with the server); `taskkill /T /F` of the loop (kept only as a documented
manual fallback when the loop does not react to `kill` within 30 seconds).

## R14 - Phase of the run

**Decision**: a monotonic state machine over the whole `trace.jsonl` (all attempts), driven by
main-thread markers (`parent_tool_use_id == null`): `Bash` commands the implement skill
prescribes (`bin/backlog.sh lock acquire` -> selection, `verify` -> measure, `start` ->
specify done, `run-log` -> close, `git merge --ff-only` / `git merge main` -> merge,
`block` -> stop path, `lock release` -> end), `Skill` invocations (`speckit-specify`, `-clarify`,
`-plan`, `-tasks`, `-analyze`, `-implement`), `Agent` calls after implement (review rounds), and
`PowerShell` calls of `build.cmd` / `saltests` / `run_on_hidden_desktop.ps1` (verify, and the
*GUI probe running* flag). A phase never moves back; after a continued attempt the last phase
stays until a new marker. Files in `specs/<BRANCH>/` and the branch's commits are shown as a
cross-check. Progress = `[X]` / all checkboxes in `specs/<BRANCH>/tasks.md`.

**Rationale**: A2 §1.3 measured the markers on a real trace (one Skill invocation per phase, in
order); files and commits lag. Claude 2.1.x has no todo events, so `tasks.md` is the only
progress measure (A2 §1.4).

## R15 - Following a trace

**Decision**: while a viewer is subscribed, the server reads the current `trace.jsonl` every
500 ms by open-read-close from a byte offset, splits on `\n`, keeps the partial last line,
decodes UTF-8 on whole lines, parses each line in try/catch (an unparsable line becomes a
visible "unparsable line" event). Attempt separators (`backlog_loop.attempt`) split the view.
A run ended when `run.json` disappears or `index.jsonl` gets its line - not on a `result`
event (one per turn). Usage figures are deduplicated by `message.id`; cost per attempt is its
last `result`'s `total_cost_usd` / `modelUsage` (not `meta.attempts[].usage`, which excludes
subagents). The current run is found through `loop.json.trace`, polled at 1 Hz; `fs.watch` is
used only on `.agent-traces/` (ignored by git) and on `<git-common-dir>/tandem-backlog-loop/`
to wake the poller early, never on working-tree directories.

**Rationale**: A2 §3, A3 §2.3 (NTFS updates metadata lazily while another process writes, so
change notifications for appends lag).

## R16 - History, costs and the closed-items archive

**Decision**: run list = `.agent-traces/index.jsonl` + `RUNS.md` rows (RUNS covers runs without
traces) + the live `run.json`. Per-run figures that need a full trace scan (cost, tokens, phase
timeline) are computed once per ended run and cached in
`<git-common-dir>/tandem-backlog-app/cache/runs/<dir>.json` (an ended run never changes).
Closed items come from `git log --diff-filter=D --name-only -- backlog/items/*/desc.md` and
`git show <commit>^:<path>`, cached by commit. Item history = `git log -- backlog/items/<slug>/`
(survives removal). Every git call is read-only and lock-free (`log`, `show`, `rev-parse`,
`ls-tree`, `cat-file`, tree-to-tree `diff`, and `status --porcelain` only with
`--no-optional-locks`).

**Rationale**: A2 §4, A1 §7; `.agent-traces/` is absent on this machine today (A2 §0), so every
view must work from `RUNS.md` alone.

## R17 - Launcher, port and single instance

**Decision**: `bin/start-backlog-app.sh [--dev] [--port N] [--no-open] [--root DIR]` (contract
[launcher.md](contracts/launcher.md)): `--help` without Node; checks Node >= 24.15 (or 26.x);
`npm ci` when `node_modules` is missing or the lock file's SHA-256 changed; `npm run build`
unless `--dev` (skipped when a source hash stamp matches); then
`exec node packages/server/src/main.ts`. The server binds 127.0.0.1 on a **stable default port
47321** (so browser storage - theme, drafts - survives restarts), or the given port; if the
port is taken by a live instance of this application for the same repository (instance file
`<git-common-dir>/tandem-backlog-app/instance.json`: pid, creation time, port), it prints that
instance's address and exits 0; if it is taken by anything else, it refuses with a message
suggesting `--port`. The browser is opened with
`%SystemRoot%\System32\rundll32.exe url.dll,FileProtocolHandler <url>`. Ctrl+C stops the server
and its own children, never the loop.

**Rationale**: A3 §3.3; the stable port replaces A3's port 0 because A3 §4.4 and R3 rely on
per-origin browser storage.

## R18 - Localhost security

**Decision** (A3 §4, contract [security.md](contracts/security.md)): bind `127.0.0.1` only and
verify it; Host allow-list (`127.0.0.1:<port>`, `localhost:<port>`, else 421); for changing
methods and streams, `Origin` must be the app's own and `Sec-Fetch-Site` must not be
`cross-site`/`same-site` (else 403); changing requests must be `application/json` (else 415),
body <= 256 KiB; a 32-byte random token per start, given to the page through a one-time,
120-second bootstrap code in the opened address (`/api/session/claim`), then sent as
`Authorization: Bearer` on every `/api` call (constant-time compare; 401 otherwise); no CORS
headers; strict CSP (`default-src 'self'`, no inline script, nothing remote); static files by
exact manifest lookup; items and traces addressed by validated identifiers, never by paths.
"Copy link" mints a new bootstrap code through an authenticated call.

**Rationale**: closes the malicious-web-page vectors (CSRF, DNS rebinding, cross-origin reads)
and the other-local-user vector; processes of the same user are out of scope (they can run the
tools directly). A cookie is not port-isolated on 127.0.0.1 and would reintroduce CSRF.

## R19 - AI jobs through the local Claude command-line tool

**Decision** (contract [ai-jobs.md](contracts/ai-jobs.md)): kinds `ask`, `draft-item`,
`triage-check`, `verify`, `auto-triage-plan`, `assess-issue`. Each runs
`claude -p --output-format stream-json --verbose --tools Read,Grep,Glob
--no-session-persistence --max-budget-usd <cap> --json-schema <schema of its result>` with the
prompt on stdin, `cwd` = repository root. Jobs never get write or shell tools; their result is a
validated JSON proposal shown as a preview and applied by the app through the backlog tool
after the maintainer confirms (a verification proposal is applied as `verify` with the current
`main` commit, or as a log line). One AI job at a time; cancel = taskkill of its tree; progress
streamed as job events. Jobs whose proposal changes the backlog are refused while the gate is
closed; `ask` is always allowed and states which branch the working tree is on. The cap
defaults to 2 USD per job (setting).

**Rationale**: A4 §6.2-5 (previews, never direct writes); read-only tools mean a prompt-injected
item or GitHub text cannot make the agent write or run anything (A3 §2.4); `--json-schema` and
`--tools` were verified on Claude Code 2.1.314 (`claude --help`, 2026-10-30).

**Alternatives**: running the skills (`/tandem-backlog verify`) headless in maintainer mode
(rejected: the skill writes directly, no preview, and needs shell tools).

## R20 - Filters, query language and search

**Decision**: the filter language of A4 §2.4 (`type:bug,improvement sev>=5 area:encoding
who:agent effort:S,M status:blocked section:next source:github has:evidence verified:none
created>=2026-10-20 related:<slug> needs:<slug> feature:341 "phrase" -word`), parsed by one
pure, tested module in the shared package and used in the box, the address and the palette;
unknown keys are errors, values come from the legend. Full text is an in-memory index on the
server built from `board --json --with-body` (and `issue.md`), rebuilt on every backlog change:
case- and diacritics-insensitive tokens, AND of terms, phrase match, snippet with highlight.
Five hundred items index in well under a second; no search library is needed.

## R21 - Notifications and "since your last visit"

**Decision**: the server derives events from state transitions (run ended with outcome, loop
stopped for a person, usage-limit wait and resume, a precheck wait longer than 10 minutes, new
Inbox items, decisions or person steps added by runs, check findings appeared) and appends them
to `<git-common-dir>/tandem-backlog-app/events.jsonl`, so the Home page can show what happened
while no tab was open. Tabs show them as toasts and in *Needs you*; the browser Notification API
(opt-in) shows them as desktop notifications; quiet hours suppress desktop notifications only.
The tab title carries the count of unseen items needing attention.

## R22 - "Every source file documented", checked

**Decision**: ESLint 10 flat config with `eslint-plugin-jsdoc` (`require-jsdoc` on functions,
methods, classes, arrow functions assigned to variables, interfaces, type aliases, properties,
top-level variables; `require-description`, `require-param`, `require-returns` without types,
`require-file-overview`) and `eslint-plugin-tsdoc` (`tsdoc/syntax`), TypeDoc 0.28 with
`validation.notDocumented` and warnings as errors, and a Vitest repository-rules test (SPDX
header, file overview, UTF-8 without BOM, LF, no `shell: true` / `exec(`). shadcn components are
documented like every other file after generation. Inline comments at important points are a
review item (cannot be checked mechanically). Prettier formats.

**Alternatives**: Biome (no rule requiring doc comments).

## R23 - Testing

**Decision**: Vitest 5 (pure modules: parsers of every format, filter language, phase machine,
gate; API tests through `app.request()`; CLI-adapter tests against a temporary copy of a fixture
repository; component tests with jsdom + Testing Library); Playwright 1.64 on the installed Edge
(`channel: 'msedge'`, no browser download) for the journeys of stories 1-6 against a fixture
repository with the loop's fake claude (`tools/backlog/fixtures/fake_claude.py`), plus security
tests (foreign Host, foreign Origin, no token, reused bootstrap code) and axe accessibility
checks in both themes. The Python additions are tested in `test_backlog.py` / `test_loop.py`.
End-to-end tests never touch the real `backlog/`.

## R24 - Repository hygiene

**Decision**: in the same change that adds `tools/backlog-app/`: `.gitignore` gets
`node_modules/`, `dist/`, test reports and generated docs of the app; `.gitattributes` gets
`tools/backlog-app/** text eol=lf`; `.editorconfig` gets a `[tools/backlog-app/**]` section
(LF, 2 spaces, UTF-8 without BOM); `normalize_config.json` excludes the app's `node_modules`
and `dist` from both its lists (normalize.ps1 walks the whole tree and would rewrite `.ps1`,
`.h`, `.c`, `.config` files inside `node_modules`, A3 §5.2). `.npmrc`: `engine-strict`,
`save-exact`, `ignore-scripts`, `fund=false`. The lock file is committed; nothing from npm is
committed or shipped. Files under `tools/backlog-app/` are UTF-8 without BOM (a BOM breaks JSON
parsers); the C++ rule "UTF-8-BOM, clang-format" does not apply.

## R25 - Release readiness without network

**Decision**: the release page reads only local data: the `unreleased` section of
`CHANGELOG.md`, backlog items whose text marks them as release gates (person steps and
decisions in their sections), `git rev-list --left-right --count origin/main...main` (no fetch;
the remote ref as last fetched), local tags `v*`, and the `Release records` list of
`backlog/RELEASE.md` shown as text. No build, tag, push or publish action exists.
`tools/release/release.py status` is not called because it reads remote tags (network).

## R26 - Open questions

None. The three spec clarifications are answered; A3's open points are settled here (stdin
JSON: R8; Radix: R2; loop output: the loop keeps its own console, R13; hygiene: R24).
