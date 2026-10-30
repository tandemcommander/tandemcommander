# Implementation Plan: Backlog web app - steer development through the backlog from a browser

**Branch**: `344-backlog-web-app` | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/344-backlog-web-app/spec.md`

## Summary

A localhost web application in `tools/backlog-app/` - a Node.js backend and a React single-page
frontend, both TypeScript - started by `bin/start-backlog-app.sh`. It shows the backlog in its
real order with filters, a query language and full-text search; shows the autonomous loop and
the running item live (phase, tasks, current tool, messages, commits, usage) and controls the
loop (start, pause, resume, stop, hard stop, run one item); changes the backlog (reorder by drag
and drop or keys, triage, move, block, park, reject, reopen, close, decide, person steps, new
items, body edits, GitHub import, bulk changes) through a change tray committed on `main`; shows
run history, feature records, closed items and release readiness; and offers read-only AI help
through the local Claude CLI whose results are previews. Light and dark themes from day one.

Technical approach (research R1): the application **drives the existing tools and owns no
backlog data**. Every backlog change is a call of `tools/backlog/backlog.py` with user text on
stdin; every loop action a call of `tools/backlog/loop.py`; the loop is started in its own
console window and never hosted. Small, backward-compatible additions to both Python tools
(contracts [backlog-cli-additions.md](contracts/backlog-cli-additions.md),
[loop-cli-additions.md](contracts/loop-cli-additions.md)) close the gaps the analysis measured.
An edit lock the loop respects, revisions on every change and reads from `main`'s git objects
during a run keep the app from racing the loop. Access is limited to the local user by a
loopback bind, Host and Origin checks and a per-start token ([security.md](contracts/security.md)).

## Technical Context

**Language/Version**: TypeScript 6.0.3 on Node.js >= 24.15.0 (24 LTS; 26.x allowed), run with
Node's native type stripping (no server build); Python 3 standard library for the tool
additions; Bash (Git Bash) for the launcher
**Primary Dependencies**: backend Hono 4.13 on `node:http`, zod 4; frontend React 19.3, Vite 8.3,
Tailwind CSS 4.3, shadcn/ui on Radix, TanStack Table / Query / Router, dnd-kit, cmdk, sonner,
react-markdown + remark-gfm, CodeMirror 6, react-virtuoso, Recharts, react-hook-form, lucide-react
(exact pins and licences: [analysis A3 §6](analysis/03-tech-stack-security.md)); existing
`tools/backlog/backlog.py`, `tools/backlog/loop.py`, Git, the local `claude` CLI 2.1.x
**Storage**: none of its own for backlog data (files owned by the tools, git history); app state
as JSON files in `<git-common-dir>/tandem-backlog-app/` (data-model *Application state*)
**Testing**: Vitest 5 (unit, API in-process, CLI adapter on fixture repositories, components with
jsdom); Playwright 1.64 on the installed Edge with axe; Python `unittest`
(`tools/backlog/test_backlog.py`, `test_loop.py` with the fake claude); `tools/test_bin_help.py`
**Target Platform**: Windows 11, the maintainer's machine; Edge / Chrome current; loopback only
**Project Type**: developer tool inside the product repository (web application: npm workspaces
`shared`, `server`, `web`); not part of the product, the build or the installer
**Performance Goals**: live run updates in the page <= 5 s after the trace write (SC-004);
filter / search over >= 500 items < 1 s (SC-005); start < 10 s after the first install (SC-001)
**Constraints**: never keep a file the loop or tools replace open (WinError 5, A2 §5.1); never
make the working tree dirty; no lock-taking git command during a run; user text never on a
command line; no network except the maintainer-started GitHub import; every source file
documented (FR-050)
**Scale/Scope**: one user, one repository; ~260 items, ~110 journal rows, up to thousands of
runs and GB of traces over time; about 15 screens

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Applies? | Result |
|---|---|---|
| I. Build reproducibility | The product build (`build.cmd`, MSBuild) is untouched; `check_encoding.py` scans only `src/**/*.cpp`. The app has its own reproducible install (`npm ci` from a committed lock file, exact pins, engine-strict). `normalize.ps1` must not walk into `node_modules` (R24, excludes added) | PASS |
| II. Backward compatibility | No product, plugin, registry or installer change. Tooling: every addition to `backlog.py` and `loop.py` is new commands/options; existing commands, outputs, files and exit codes unchanged (contracts state it); the loop's new precheck condition only adds a wait reason | PASS |
| III. Incremental modernization | Slices are independently shippable (stories P1 -> P3); tool additions are small with tests | PASS |
| IV. Windows platform commitment | Built for Windows 11 (Git Bash launcher, `taskkill`, `CREATE_NEW_CONSOLE`, Edge for tests). "No cross-platform abstraction layers" concerns the product; this is a maintainer tool outside it. Dependencies: all permissive licences (MIT, ISC, BSD, Apache-2.0; MPL-2.0 axe only in tests), none distributed (A3 §5.1). PrimeVue rejected for its licence | PASS |
| V. Plugin architecture | Untouched | PASS (n/a) |
| VI. UI consistency | Governs the product's WinAPI dialogs; the app is not product UI. It has its own consistent design system (one token set, both themes) | PASS (n/a) |
| Technical constraints (C++, UTF-8-BOM, clang-format) | Apply to product sources. App files are UTF-8 **without** BOM and LF (a BOM breaks `package.json` parsers; Prettier formats), recorded in `.editorconfig` / `.gitattributes` and in the feature history - as the Python tools already are | PASS (documented exception for non-C++ tooling, same as `tools/backlog/*.py`) |
| GPLv2 licensing | App sources `GPL-2.0-or-later` (SPDX header in every file); npm packages are not committed or shipped | PASS |
| Development workflow (one concern, English commits) | One concern: the backlog web app and the tool additions it needs; the unrelated skill path fix made earlier in this session is committed apart from the feature's commits | PASS |
| Release documentation (`CHANGELOG.md`) | Internal tooling with no user-visible effect -> not recorded | PASS |
| CLAUDE.md: `PRIVACY.md` | No product network, storage or installer change; the app talks to loopback, the local tools, and GitHub only through the existing `import-github` the maintainer starts | PASS (no update) |
| CLAUDE.md: `bin/` scripts answer `--help` (247) | `bin/start-backlog-app.sh --help` without Node, tested by `tools/test_bin_help.py` | PASS |
| CLAUDE.md: never push or publish from a session; agents only add to Inbox | The app never pushes, tags, publishes or posts (FR-046); it acts in maintainer mode only on the maintainer's click | PASS |
| CLAUDE.md: scripts written with the editor tools (123) | Launcher and all files written with Write/Edit | PASS |

Re-check after Phase 1 (data model and contracts written): unchanged, no violations;
*Complexity Tracking* is empty.

## Project Structure

### Documentation (this feature)

```text
specs/344-backlog-web-app/
├── spec.md
├── plan.md                 # this file
├── research.md             # R1-R26 decisions
├── data-model.md
├── quickstart.md           # validation scenarios Q1-Q22
├── analysis/               # the four independent analyses (A1-A4)
├── contracts/
│   ├── http-api.md         # REST routes and SSE streams
│   ├── security.md         # access rules and their tests
│   ├── launcher.md         # bin/start-backlog-app.sh and server start
│   ├── ai-jobs.md          # claude CLI jobs, schemas, limits
│   ├── backlog-cli-additions.md   # amends specs/242-backlog-system/contracts/cli.md
│   └── loop-cli-additions.md      # amends specs/247-backlog-run-loop/contracts/loop-cli.md
├── checklists/requirements.md
├── fix-log.md              # running log during implementation
└── tasks.md                # /speckit-tasks
```

### Source Code (repository root)

```text
bin/
└── start-backlog-app.sh            # new launcher (contracts/launcher.md)

tools/backlog/                      # existing Python tools, extended (stdlib only)
├── backlog.py                      # + board/show/check/legend --json, --input-json, --ref,
│                                   #   reorder, body, step, decide, reply, set --position
├── loop.py                         # + start --new-window/--item, kill, edit-lock precheck,
│                                   #   loop.log, last.json
├── test_backlog.py, test_loop.py   # + tests of every addition
└── fixtures/                       # + fixtures the app's tests reuse

tools/backlog-app/
├── package.json                    # private; workspaces; engines; scripts: dev, build, start,
│                                   #   typecheck, lint, format, test, test:e2e, docs:check, check
├── package-lock.json               # the one lock file (committed)
├── .npmrc  .nvmrc  tsconfig.base.json  eslint.config.js  .prettierrc.json
├── tsdoc.json  typedoc.json  vitest.workspace.ts  playwright.config.ts
├── README.md                       # how to run, develop, test; architecture in one page
├── packages/
│   ├── shared/src/                 # zod schemas + types: entities, API, events, error codes;
│   │                               #   filter-language parser; phase rules (pure, tested)
│   ├── server/src/
│   │   ├── main.ts                 # arguments, instance file, listen, banner, shutdown
│   │   ├── gate/                   # host, origin, token/bootstrap, headers, static manifest
│   │   ├── proc/                   # the only module that spawns processes
│   │   ├── repo/                   # git reads (lock-free), git-common-dir, branch, dirty paths
│   │   ├── backlog/                # tool adapter, write queue + edit lock, write gate,
│   │   │                           #   revisions, tray + undo + commit, search index
│   │   ├── loop/                   # loop view, control commands, state-file poller
│   │   ├── runs/                   # trace tailer, phase machine, run list, cost cache, stats
│   │   ├── features/               # specs/NNN records, closed items, release page
│   │   ├── ai/                     # job runner, prompts/<kind>.md, result schemas
│   │   ├── events/                 # SSE hub, notification derivation, events.jsonl
│   │   ├── settings/               # settings, saved views, app-state folder
│   │   └── api/                    # Hono routes per area
│   └── web/
│       ├── index.html  vite.config.ts  public/theme-init.js
│       └── src/
│           ├── app/                # router, layout (sidebar, top bar), providers
│           ├── components/ui/      # shadcn components (documented like all sources)
│           ├── lib/                # API client, SSE reader, query keys, theme, hotkeys
│           └── features/           # home, backlog, item, triage, decisions, person-steps,
│                                   #   new-item, live, runs, features, release, check, ask,
│                                   #   tray, palette, settings
└── e2e/                            # Playwright specs, fixture-repository builder

# changed: .gitignore, .gitattributes, .editorconfig, normalize_config.json (R24);
# specs/242-backlog-system/contracts/cli.md and specs/247-backlog-run-loop/contracts/loop-cli.md
# (amendment notes); .claude/skills/tandem-backlog/ (new tool commands replace hand edits of
# bodies; the app's edit lock); CLAUDE.md (one line), specs/FEATURE-HISTORY.md,
# architecture/12-project-reference.md (the app in the tooling list)
```

**Structure Decision**: one npm-workspaces project in `tools/backlog-app/` with three packages
(`shared` for contracts used by both sides, `server`, `web`), so the API shapes are written once
and the server runs its TypeScript sources directly. The Python tools stay where they are and
are extended, because they remain the owners of the backlog format and the loop.

## Implementation order

Each step ends with its tests green, `npm run check`, and a commit; each story slice is usable
on its own (spec: all six stories in this feature, in priority order).

1. **Foundation in the Python tools** (blocking): `backlog.py` read additions (`board`, `show`,
   `check --json`, `legend`, `--ref`), `--input-json`, `--json` results; `loop.py` `kill`,
   `--new-window`, edit-lock precheck, `loop.log`, `last.json`. Tests first (fixtures, fake
   claude).
2. **App skeleton**: repository hygiene (R24), workspaces, lint/doc rules, the gate and token,
   static manifest, launcher with `--help`, SSE hub, theme, layout. Security tests.
3. **US1 (P1)** - board, filters, query language, search, item detail, history, closed items,
   next-up, check, deep links, saved views.
4. **US2 (P1)** - loop view and control, live run (tailer, phase machine, tasks), notifications,
   run history basics.
5. **US3 (P1)** - write gate + edit lock + queue + revisions, tray, commit, undo; `reorder`,
   `set --position`; drag and drop, triage screen, move/block/park/reject/reopen, Check fixes.
6. **US4 (P2)** - `body`, `step`, `decide`, `reply` in the tool; decision and person-step
   screens, new item, body editor, close, GitHub import, feature pages.
7. **US5 (P3)** - AI job runner, the six kinds, Ask page, previews.
8. **US6 (P3)** - release page, `--item` runs, hard stop UI, stale-lock release, bulk changes,
   run statistics and transcript replay.
9. **Close**: amend the 242 / 247 contracts, the backlog skill, CLAUDE.md, FEATURE-HISTORY,
   architecture reference; independent refute-first review (CLAUDE.md working method);
   quickstart scenarios Q1-Q22 recorded in `fix-log.md`.

## Risks and how the plan meets them

| Risk | Measure |
|---|---|
| The app makes the loop wait or crash (dirty tree, held file, lock) | R9 edit lock, R10 reads from git during runs, open-read-close polling, tray auto-commit before start/resume, `.gitignore` for all app output; Q11, Q18 |
| Lost or mangled user text | stdin JSON only (R7, R8); byte-exact test Q13 |
| A run and the maintainer change the same item | gate closed during runs; revisions; the running item never offered |
| Hard stop leaves inconsistent records | the loop's own `kill` path (R13); Q7 |
| Scope (six stories) | strict slice order; each slice shippable; a stop part-way leaves a working app |
| Fresh dependencies (some released < 14 days ago, A3 §6) | exact pins + lock file; step back one patch on a regression |
| Documentation drift | ESLint jsdoc/tsdoc + TypeDoc `notDocumented` as errors in `npm run check` |

## Complexity Tracking

No constitution violations; nothing to justify.
