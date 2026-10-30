<!--
SPDX-FileCopyrightText: 2026 Pavel Stupka
SPDX-License-Identifier: GPL-2.0-or-later
-->

# Backlog app

A localhost web application that steers Tandem Commander development through
the backlog (feature 344): browse and filter `backlog/`, reorder and triage
items, edit them, watch the loop and the item being implemented live, start,
pause, resume and stop the loop, read run history and traces, see feature
records and release readiness, and draft items or ask questions with Claude.

It changes nothing by itself: every change of the backlog goes through
`bin/backlog.sh` (`tools/backlog/backlog.py`), every loop control through
`bin/backlog-loop.sh` (`tools/backlog/loop.py`). The specification, the
design and every measured result are in `specs/344-backlog-web-app/`.

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
  monitor, control), `runs/` (trace tailer, run history), `features/`
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
  revision the page saw and lands in the change tray; nothing is committed
  until the maintainer commits the tray (or the loop start commits it).
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
