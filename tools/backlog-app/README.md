<!--
SPDX-FileCopyrightText: 2026 Pavel Stupka
SPDX-License-Identifier: GPL-2.0-or-later
-->

# Backlog app

A localhost web application that steers Tandem Commander development through
the backlog (feature 344): browse and filter `backlog/`, reorder and triage
items, edit them, watch the loop and the item being implemented live, start,
pause, resume and stop the loop, read run history and traces, see feature
records and release readiness, draft items or ask questions with Claude, and talk with
Claude about one item in a window of its own (feature 371).

It changes nothing by itself: every change of the backlog goes through
`bin/backlog.sh` (`tools/backlog/backlog.py`), every loop control through
`bin/backlog-loop.sh` (`tools/backlog/loop.py`). The specification, the
design and every measured result are in `specs/344-backlog-web-app/`; the
changes of feature 371 (editing while a run is in progress, the running item
in _In progress_, typed positions, the conversation) in
`specs/371-backlog-app-live-editing/`. The triage's _Place at_ chooser
(feature 414, `specs/414-triage-position/`) moves an Inbox item into _Next_,
_Decisions for the maintainer_ or _Person steps_ at a chosen position in one
change; key `m` focuses its position field.

The _Live run_ page and the page of an ended run are a dashboard a person reads
(feature 415, `specs/415-live-run-dashboard/`): a progress bar with the
elapsed time, the expected remaining time and end (an estimate from the phase,
the tasks and earlier closed runs), what happens now, live figures (tokens, the
price at list prices between claude's reported totals, context, usage limits),
and tabs - the run's story in words with labels and outcomes, what is critical,
the decisions of the spec, a gallery of the screenshots the run looked at (a
full-screen viewer with swipe and arrow keys), diagrams of the flow and of where
the change happens, the files, the feature's documents and the raw transcript.
While the item runs, the item's conversation: every message carries a fresh
snapshot of the run. Since feature 419 (`specs/419-live-run-views/`) every part
is a view of one row - Overview (progress, now, figures), Story, Critical,
Decisions, Gallery, Architecture, Files, Documents, Raw trace and Chat (full
width, a dot on its tab when an answer came while another view was shown) -
with the run in one line above the row. The page fills the window and never
scrolls; each view scrolls by itself, in one area. The chosen view is in the
address (`/live?view=story`). The rules that turn the trace into the story are
pure and unit-tested in `packages/shared/src/runs/` (`run-story.ts`,
`run-metrics.ts`, `pricing.ts`, `run-progress.ts`, `time-index.ts`);
`node packages/shared/test/fold-real-trace.ts <trace.jsonl>` folds a real
trace and prints what a reviewer checks.

## Run

```sh
bin/start-backlog-app.sh            # from the repository root
bin/start-backlog-app.sh --help     # options: --dev, --port N, --no-open, --root DIR
```

The launcher checks Node.js (24.15 or later), installs the dependencies when
`package-lock.json` changed (`npm ci`), builds the web client when its sources
changed, starts the server on `127.0.0.1:47321` and opens the browser with a
one-time sign-in link. A second start reuses the running instance and only
opens a new link. Stop it with Ctrl+C in its window.

## Develop

```sh
cd tools/backlog-app
npm ci
bin/start-backlog-app.sh --dev      # (from the root) server + Vite with live reload
npm run check                       # typecheck, lint (doc comments too), format, unit tests
npm run test:e2e                    # build + Playwright end-to-end tests in Edge
```

The end-to-end tests run against throw-away fixture repositories with a fake
`claude` and a hidden loop window; they never touch this repository. Never
point a development instance with write actions, or a loop start, at the real
repository while trying something out — use `--root` with a copy.

## Architecture on one page

```
browser (React 19, Vite build)          server (Node 24, Hono on node:http, 127.0.0.1 only)
  pages / features/*  ── fetch + token ──▶  gate: Host, Origin, token, JSON, size, CSP
  TanStack Query cache  ◀── SSE events ──  api/*  ─▶ services
                                              │
          ┌───────────────────────────────────┼──────────────────────────────┐
          ▼                                   ▼                              ▼
  backlog read model                   write queue                    loop monitor / control
  backlog.py board/show/check --json   edit lock → gate → revision    loop.py status --json (2 s)
  worktree or --ref main (R10)         → backlog.py → change tray     loop.py start/pause/…
                                                                       run tailer: .agent-traces/
```

- **packages/shared** — zod schemas of every API body and event, the filter
  language, triage rules and the run state machine (pure, unit-tested, used
  by both sides).
- **packages/server** — `gate/` (the security gate), `backlog/` (tool calls,
  read model, write gate, edit lock, write queue, change tray), `loop/` (view,
  monitor, control), `runs/` (trace tailer, run history, run insight: documents, decisions, gallery), `features/`
  (feature history, records, release readiness), `ai/` (Claude jobs and the
  apply step), `events/` (SSE hub, notifications), `api/` (routes).
- **packages/web** — `app/` (router, layout, store, events), `lib/` (API
  client, SSE, theme, queries), `components/` (UI primitives), `features/`
  (one folder per page).

## Rules every change obeys

- Listen on `127.0.0.1` only; every request passes the gate in
  `packages/server/src/gate/` (`contracts/security.md`). A new route is added
  to the gate tests.
- The backlog is changed only by `backlog.py`; texts go through
  `--input-json -` (stdin), never through the command line. The app never
  writes a file of `backlog/` itself and never writes outside it.
- Every change takes the edit lock `.git/tandem-backlog-edit.lock`, checks the
  revision the page saw and is applied through one of three channels the write
  gate decides (feature 371): `tray` - no loop lives: the working tree, pending
  until the maintainer commits the tray (or the loop start commits it);
  `commit` - a loop lives: the working tree, committed at once; `main-ref` - a
  run holds the run lock and works on its branch: the backlog tool runs in the
  app's sparse detached side worktree of `main`
  (`.git/tandem-backlog-app/main-worktree/`), the change is committed there and
  `main` is moved with a compare-and-swap. The primary working tree is never
  touched while a run holds the lock; the item the run works on is frozen
  (also against indirect changes); the run merges `main` at its end by the
  recipe of `/tandem-backlog-implement` step 9.
- The loop holds the app's edit lock while a run starts (until the run is on
  its branch) and while it returns to `main` (`bin/backlog-loop.sh returning`
  at step 9); then the gate is read-only for a moment (`run-starting`,
  `run-on-main`) and opens again by itself.
- The conversation about an item runs one `claude -p` process in bidirectional
  stream-json mode with the file tools only (Read, Grep, Glob - no shell: even
  `git log --output=` writes files);
  transcripts live in the state folder (`chats/`); nothing it does changes a
  file (`specs/371-backlog-app-live-editing/contracts/chat.md`).
- The app never touches the run lock or the loop's state; it starts the loop
  in its own window and controls it only through `loop.py` commands.
- Traces are read open-read-close, append-only files only (measured: reading
  files the loop replaces atomically makes its `os.replace` fail).
- Nothing is published: no push, tag, release or upload from the app.
- Every source file carries the SPDX header and English doc comments on every
  exported class, function, type and constant; ESLint enforces them.

## Dependencies and licences

All dependencies are pinned in `package-lock.json` and installed from npm
(`.npmrc`: exact versions saved, package install scripts disabled).

| Licence      | Packages                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MIT          | hono, @hono/node-server, zod, react, react-dom, radix-ui, @tanstack/react-query, @tanstack/react-router, @tanstack/react-table, @dnd-kit/*, cmdk, sonner, react-markdown, remark-gfm, @uiw/react-codemirror, @codemirror/lang-markdown, react-virtuoso, recharts, react-hook-form, @hookform/resolvers, react-hotkeys-hook, eventsource-parser, date-fns, clsx, tailwind-merge, tailwindcss, @tailwindcss/vite, tw-animate-css, zustand, vite, @vitejs/plugin-react, vitest, eslint, typescript-eslint, prettier and the remaining build and test tools |
| ISC          | lucide-react                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Apache-2.0   | class-variance-authority, typescript, @playwright/test                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| BSD-3-Clause | eslint-plugin-jsdoc (lint only)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| MPL-2.0      | @axe-core/playwright (accessibility tests only, not shipped)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |

All are compatible with the repository's GPL-2.0-or-later; none is shipped
with the Tandem Commander installer.
