# 344 Backlog web app: technology stack and localhost security

Analysis 03 of feature 344 (`tools/backlog-app/`, launched by `bin/start-backlog-app.sh`).
Date of the facts: **2026-10-30**. Versions, release dates and licences were read from the
npm registry on that day (`npm view <pkg> version license time[<ver>]`); other facts from the
sources listed at the end. Measurements made in this session are marked **[measured]**.

## 0. Decision in one paragraph

**React 19.3 + Vite 8.3 (SPA) + Tailwind CSS 4.3 + shadcn/ui on Radix primitives** for the
frontend. **Hono 4.13** inside one Node 24 `node:http` server for the backend. TypeScript runs
**natively in Node 24** (type stripping, stable since 24.12; no tsx, no server build).
**SSE** is the real-time channel. **TypeScript 6.0.3** for the type check, because
typescript-eslint and TypeDoc do not support TS 7 yet. **zod 4** schemas live in one shared
workspace package. **Vitest 5** for unit and API tests, **Playwright 1.64** on the
installed Edge for e2e. Lint and format: **ESLint 10 + eslint-plugin-jsdoc + eslint-plugin-tsdoc
\+ Prettier**; TypeDoc validation makes "every file documented" checkable. One npm-workspaces
monorepo with one committed lockfile. The server binds **127.0.0.1 only**. It checks the Host
header and the Origin, and it requires a **per-launch bearer token** that is handed to the browser
through a **one-time bootstrap code**. It sends a strict CSP and no CORS headers. The app spawns
child processes only with `shell: false`, and user text reaches the Python CLI only on
**stdin**. That last point needs a small, stdlib-only extension of `tools/backlog/backlog.py`.

---

## 1. Frontend

### 1.1 Requirements that decide the choice

The app has these surfaces: a backlog table (sort, filter, about 257 items today
[measured: `ls backlog/items | wc -l`]), drag-and-drop reordering, an item detail view with
Markdown rendering and editing, a command palette, toasts, dialogs, resizable split panes,
keyboard shortcuts, a live trace viewer (a growing JSONL stream, possibly thousands of events)
and loop controls. It needs a light/dark theme from day one (system preference plus a manual
toggle, no flash on load). It must be accessible, typed and well documented, and **Claude
agents will write and maintain most of the code**.

### 1.2 Candidates compared

| Criterion | **React 19 + shadcn/ui (Radix or Base UI) + Tailwind 4** | React 19 + Mantine 9 | Svelte 5 / SvelteKit 3 (+ shadcn-svelte / bits-ui) | Vue 3.5 + PrimeVue 5 | Vue 3.5 + Naive UI 2.45 | Solid 1.9 (+ Kobalte) |
|---|---|---|---|---|---|---|
| Current version (date) | react 19.3.1 (2026-10-14), shadcn CLI 4.23.0 (2026-10-27), radix-ui 1.8.1 (2026-10-12), @base-ui/react 1.9.0 (2026-10-09), tailwindcss 4.3.3 (2026-07-16) | @mantine/core 9.7.4 (2026-10-25) | svelte 5.57.3 (2026-10-26), @sveltejs/kit 3.1.1 (2026-10-29) | vue 3.5.44 (2026-10-13), primevue 5.0.4 (2026-10-22) | naive-ui 2.45.3 (2026-08-27) | solid-js 1.9.18 (2026-10-29) |
| Licence | MIT | MIT | MIT | **PrimeUI licence (proprietary, licence key; free "Community" tier only below revenue and team-size limits)** | MIT | MIT |
| Data table (sort/filter/virtual) | TanStack Table v9 (the shadcn data-table guide uses v9) + TanStack Virtual / react-virtuoso | No core table; third-party mantine-datatable / mantine-react-table | TanStack Table Svelte adapter (v9 needs Svelte 5) | Strong built-in DataTable | Strong built-in DataTable with virtual scroll | TanStack Table Solid adapter |
| Command palette | cmdk (shadcn `Command`) | Spotlight (built in) | bits-ui Command | Built in (CommandPalette-like via AutoComplete) | None built in | Kobalte + custom |
| Drag and drop | dnd-kit (most examples), Pragmatic DnD | dnd-kit | svelte-dnd-action / dnd-kit-svelte | Built-in OrderList / PickList | Third-party (vuedraggable) | solid-dnd (small) |
| Toasts, dialogs, split panes | sonner, Dialog/Sheet, react-resizable-panels (all shadcn) | Built in | bits-ui / paneforge | Built in | Built in, no split panes | Kobalte, custom panes |
| Dark/light theming | Tailwind `dark` variant + CSS variables; trivial no-flash script | Built in, `ColorSchemeScript` | Same Tailwind approach | Theme presets, styled mode | Excellent built-in theme provider | Custom |
| Accessibility | Radix / Base UI primitives (WAI-ARIA patterns, focus management) | Good | bits-ui good | Good | Medium | Kobalte good |
| TypeScript quality | Excellent | Excellent | Good (runes typed) | Good | Good | Excellent |
| AI-agent familiarity | **Highest**: the most training data; shadcn code is copied into the repo, so agents read and change real source | High | Medium. Agents still mix Svelte 4 syntax into Svelte 5 runes | Medium | Medium-low | Low |
| Bundle and dev speed | Fine for localhost; Vite 8 builds in seconds | Larger CSS | Smallest bundle | Large | Medium | Smallest runtime |

### 1.3 Decision: React 19 + Vite 8 SPA + Tailwind 4 + shadcn/ui on Radix

Decisive reasons:

1. **Agent maintainability.** React plus shadcn/ui is the stack the agents know best. shadcn
   copies each component into `src/components/ui/`, so there is no black-box library API to
   guess. An agent opens the file and changes it. Every requested widget has a canonical
   shadcn recipe: Data Table (TanStack Table v9), Command (cmdk), Sonner, Dialog/Sheet/Popover,
   Resizable (react-resizable-panels), Chart (Recharts) and Form (react-hook-form + zod).
2. **Theming without flash** is a small, fully understood mechanism: CSS variables with a
   `.dark` class on `<html>` (section 1.6).
3. **Licence fit**: every package is MIT, ISC, Apache-2.0 or OFL (section 5). PrimeVue 5 alone
   would disqualify Vue + PrimeVue.
4. **Accessibility** comes from Radix primitives (focus traps, roving focus, ARIA roles),
   dnd-kit's keyboard sensor, and Playwright + axe checks (section 2.8).

**Radix rather than Base UI.** shadcn made Base UI its default for new projects in July 2026,
and Radix remains fully supported (`npx shadcn@latest init -b radix`). Radix is the better fit
here for two reasons:

- **cmdk**, the command-palette engine behind shadcn `Command`, depends on
  `@radix-ui/react-dialog`, `react-primitive`, `react-id` and `react-compose-refs`
  [measured: `npm view cmdk dependencies`]. Choosing Radix keeps **one primitive family**
  instead of two.
- The `asChild` composition pattern has far more examples in agents' training data than Base
  UI's `render` prop.

`radix-ui` is actively released (1.8.1, 2026-10-12). Base UI 1.9 is the documented
alternative. Switching later means regenerating `components/ui`; application code would
barely change. **This is flagged as a maintainer decision with Radix as the default.**

**Mantine 9 is the runner-up.** It is batteries-included: Spotlight, notifications, a
no-flash `ColorSchemeScript` and hotkeys. It loses on three points:

- It has no data table in the core.
- Its styling is library-owned, which makes the "very nice" bespoke look harder than with
  Tailwind.
- Combining it with Tailwind needs CSS-layer care.

### 1.4 Vite, verified by analysis

- **Version:** `vite` **8.3.5** (2026-10-21), MIT. Vite 8 went stable on **2026-03-12** with
  **Rolldown** (Rust) as the single bundler for dev and build. Rolldown 1.0 followed in May
  2026. Engines: Node `^20.19.0 || >=22.12.0`, so Node 24 is fine. The plug-in is
  `@vitejs/plugin-react` **6.1.2** (2026-10-05, peer `vite ^8`). Tailwind uses
  `@tailwindcss/vite` **4.3.3** (peer `vite ^5.2 || ^6 || ^7 || ^8`).
- **SPA, not a meta-framework.** Plain Vite in `appType: 'spa'` mode is the right fit.
  SvelteKit, Next.js, React Router framework mode and TanStack Start all bring SSR and a second
  server. That server would duplicate the Node backend, complicate the security gate (two
  places to check Host, Origin and token) and gives nothing to a single-user localhost tool.
- **Dev mode with HMR (offered): Vite in middleware mode inside our own server.** The server
  dynamically imports `vite` only when started with `--dev` and calls
  `createServer({ server: { middlewareMode: true, hmr: { server: httpServer } }, appType: 'spa' })`.
  Non-API requests go through `vite.middlewares`. This gives:
  - **one process, one port and one origin** in dev and production;
  - the same security gate for both, and no proxy;
  - SSE that is not buffered by a proxy;
  - one Ctrl+C that ends everything.

  The alternative, a standalone Vite dev server with `server.proxy: { '/api': ... }`, also
  works. It needs a second allowed origin in the server's Origin allow-list and two processes
  in the launcher, so it is the fallback only.
- **Production:** `vite build` writes `packages/web/dist/`. The Node server serves that
  directory through an exact-path manifest (section 4.7).
- **Vite's own dev-server security:** since Vite 6.0.9 (CVE-2025-24010) the dev server checks the
  Host header (`server.allowedHosts`, which by default allows only localhost and IP names),
  defaults `server.cors` to false and checks the HMR WebSocket. In middleware mode our own gate
  runs first anyway. Vite 8.3.5 is far past the fixed versions.

### 1.5 Recommended frontend libraries

See the stack table in section 6 for versions and licences. Purpose and notes:

- **Table:** `@tanstack/react-table` v9 (9.0.0 stable since 2026-08-04; the shadcn data-table
  guide is written for v9). At about 257 rows no virtualisation is needed. Measure, and add
  `@tanstack/react-virtual` above roughly 2,000 rows.
- **Trace viewer:** `react-virtuoso`. `followOutput` keeps a variable-height, growing log
  pinned to the bottom unless the user scrolls up, which is exactly the tail -f behaviour.
- **Drag and drop:** `@dnd-kit/core` 6.3.1 + `@dnd-kit/sortable` 10.0.0. They are stable,
  they come with a keyboard sensor and screen-reader announcements, and they have the most
  examples. Their last release was December 2024. The successor `@dnd-kit/react` is still
  0.5.1 (pre-1.0, 2026-10-15). Migrate when it reaches 1.0. Pragmatic DnD (Atlassian, 4.0.0,
  Apache-2.0) is the alternative; it needs more hand-written code.
- **Markdown rendering:** `react-markdown` + `remark-gfm`. Raw HTML is **not** rendered,
  because `rehype-raw` is never added. Links are restricted to http, https and mailto, and
  remote images are blocked by the CSP.
- **Markdown editing:** CodeMirror 6 via `@uiw/react-codemirror` + `@codemirror/lang-markdown`.
  This is a **source editor** with a live preview pane. A WYSIWYG editor such as MDXEditor would
  re-serialise the Markdown and break the backlog item format that `backlog.py check` validates.
- **Server state:** `@tanstack/react-query` 5. SSE events invalidate queries, and mutations
  give optimistic reorder.
- **Client state:** `zustand` 5, used only for UI state: the theme, panel sizes and live-stream
  buffers.
- **Router:** `@tanstack/react-router`, code-based routes. It gives type-safe **search
  params** validated by zod, so filters and the selected item live in the URL and can be
  bookmarked or copied to a new tab.
- **Forms:** `react-hook-form` + `@hookform/resolvers` + zod, the shadcn Form recipe.
- **Command palette:** `cmdk` through the shadcn `Command` component.
- **Toasts:** `sonner`. **Split panes:** `react-resizable-panels`. **Keyboard shortcuts:**
  `react-hotkeys-hook` 5 (`@tanstack/react-hotkeys` is still 0.x).
- **Icons:** `lucide-react` (ISC), bundled through tree-shaking. No icon CDN.
- **Charts:** `recharts` 3, the basis of shadcn Chart. Uses: run durations, outcomes and usage
  over time from the trace index.
- **Fonts:** none bundled. A system stack (`"Segoe UI Variable Text", "Segoe UI", system-ui`,
  and `"Cascadia Mono", Consolas, monospace` for code) gives the native Windows 11 look,
  zero bytes and no remote content.

### 1.6 Light/dark theme without a flash

- Tailwind 4: declare `@custom-variant dark (&:where(.dark, .dark *));` and define the shadcn
  CSS variables for `:root` and `.dark`. Set `color-scheme: light dark` on `:root`, so native
  scrollbars and form controls follow.
- `index.html` loads a tiny **external, render-blocking** `/theme-init.js` in `<head>`, before
  the stylesheet. It runs `localStorage.getItem('theme')` (`'light' | 'dark' | 'system'`) inside
  try/catch, falls back to `matchMedia('(prefers-color-scheme: dark)')` and sets
  `document.documentElement.classList`. It is external rather than inline so the CSP can stay
  `script-src 'self'` without hashes.
- A ~40-line `ThemeProvider` (no `next-themes`, which targets Next.js) holds the choice. It
  listens to `matchMedia` changes while in system mode and passes the resolved theme to
  CodeMirror and Recharts.
- A Playwright test loads the page with `colorScheme: 'dark'` and checks that the
  `<html>` class is `dark` at first paint (no flash).

---

## 2. Backend

### 2.1 HTTP framework: Hono on `node:http`

| | **Hono 4.13.14** (+ @hono/node-server 2.1.5) | Fastify 5.12.7 | Express 5.3.0 | plain `node:http` |
|---|---|---|---|---|
| Dependencies | hono: 0 runtime deps | about 15 runtime deps | about 30 | 0 |
| Types | First-class, Web `Request`/`Response` | Good, but schemas are JSON Schema (zod needs a type-provider plug-in) | `@types/express` (separate) | Manual |
| SSE | Built-in `streamSSE` helper | Manual (`reply.raw`) or a plug-in | Manual | Manual |
| Security helpers | Built in: `secureHeaders`, `csrf` (Origin / Sec-Fetch-Site), `bodyLimit` | Plug-ins (@fastify/helmet, ...) | helmet, csurf (deprecated) | Manual |
| Validation | `@hono/zod-validator` 0.9.1 | ajv / type providers | Manual | Manual |
| Testing | `app.request()` runs in-process, no port | `inject()` | supertest | Manual |

**Decision: Hono.** It has zero dependencies, its validation is zod-native (one schema
language for client and server), and it ships SSE and security middleware built in. Tests run
in-process. The outer server is our own `node:http` server: it runs the security gate
(section 4) first, then dispatches `/api/*` to Hono through `getRequestListener(app.fetch)`
and everything else to the static manifest (or to Vite middleware in `--dev`).

Hono and @hono/node-server had Windows path-traversal and SSE-field advisories in 2026:

- **CVE-2026-54286 / GHSA-frvp-7c67-39w9:** an encoded `%5C` in `serveStatic` on Windows;
  fixed in hono 4.12.25 and node-server 2.0.5.
- **streamSSE:** CR injection in the event, id and retry fields; fixed in hono 4.12.4.

The pinned versions are past both fixes. We still do not use `serveStatic` (section 4.7). The
advisories show that the project patches quickly, and that a generic static handler is the
wrong tool for an access-controlled server.

Rejected:

- **Fastify:** heavier, and it would add a second validation language. Its throughput and
  logging strengths are irrelevant for one user.
- **Express 5:** untyped core, no SSE helper, and security needs extra dependencies.
- **Plain `node:http` for everything:** hand-written routing, validation and headers. It is
  still used as the outer shell.

### 2.2 Real-time channel: SSE

**Decision: Server-Sent Events.**

- **Traffic is one-directional** (server to browser): backlog changed, loop status, trace lines
  and the streamed answer to a question. Commands are ordinary REST `POST`s.
- **Resume is built in:** the SSE `id:` field carries the **byte offset** in the JSONL trace, so
  after a reconnect the browser sends `Last-Event-ID` and the server continues from exactly
  that offset.
- **It is plain HTTP**, so the gate in section 4 covers it unchanged. A WebSocket needs a
  separate upgrade path, its own Origin check (cross-site WebSocket hijacking) and the `ws`
  dependency (Node 24 has a WebSocket *client* only).
- **Browser connection limit:** HTTP/1.1 allows 6 connections per origin. The design uses one
  `/api/events` stream per tab (backlog and loop topics) plus at most one trace or question
  stream per open view.
- **Authentication:** native `EventSource` cannot send headers, so SSE endpoints accept the
  token as a `?k=` query parameter. Subresource URLs do not enter browser history, the server
  never logs query strings, and `Referrer-Policy: no-referrer` is set. If that is unwanted,
  the alternative is a fetch-stream reader with an `Authorization` header and
  `eventsource-parser` 4.1.3 (MIT) plus a hand-written reconnect.

WebSocket would become worth it only for interactive bidirectional sessions with claude
(`--input-format stream-json`), which v1 does not do.

### 2.3 File watching on Windows

There are two jobs.

**Job 1: notice that the backlog changed**, whether the change came from the CLI, an agent,
git checkout or the loop. The watched paths are `backlog/` (overview `BACKLOG.md`,
`items/<slug>/desc.md`, `RUNS.md`) and the loop state files.

- Use **`node:fs.watch(dir, { recursive: true })`**. On Windows it is native
  ReadDirectoryChangesW and needs no dependency.
- **Debounce** for 150 to 300 ms, then **re-read the truth through the CLI** (`backlog.py list
  --json`) and push one `backlog.changed` event that carries a revision hash.
- Because the reaction to *any* event is "re-read everything", atomic replace (temp file and
  rename), editor swap files, duplicate events and lost events do not matter.
- A **periodic safety rescan** every 10 to 30 s covers lost notifications (buffer overflow,
  watcher `error`, a directory deleted and re-created). On `error` the watcher is closed and
  recreated.

**Job 2: tail the active trace** (`claude -p --output-format stream-json` written by
`loop.py` into `.agent-traces/`):

- **Do not rely on change notifications for the growing file.** On NTFS the directory entry's
  size and timestamps are updated lazily while another process holds the file open for
  writing, so notifications for appended data can lag or coalesce.
- Instead, the server opens the trace with its own handle and polls `read(fd, offset)` every
  250 to 500 ms while a viewer is subscribed. Reading through our own handle always sees the
  current data.
- It splits on `\n`, keeps a partial last line in a buffer and decodes with
  `StringDecoder('utf8')`, so a multi-byte character split across reads stays intact. It parses
  each complete line with `JSON.parse` in try/catch, and an invalid line becomes a visible
  "unparsable line" event.
- `fs.watch` on `.agent-traces/` is used only to *discover* new trace files and
  `index.jsonl` changes.

**chokidar** 6.0.0 (2026-10-19, Node ≥ 22.22) is rejected for v1. On Windows it now uses
the same native recursive `fs.watch` by default, its `atomic` and `awaitWriteFinish`
heuristics add nothing to the re-read-everything design, and 6.0.0 is eleven days old with
breaking API changes. If a need appears, the fallback is chokidar 5.0.0 (2025-11-25,
ESM-only).

### 2.4 Child processes on Windows

**Rule 1: never `shell: true`, never `exec` / `execSync` with a string, never spawn `.cmd` or
`.bat`.** Since the CVE-2024-27980 ("BatBadBut") fix, Node refuses to spawn `.cmd` / `.bat`
without a shell, and with a shell `cmd.exe` would interpret metacharacters in item text.
ESLint enforces the rule (`no-restricted-imports` / `no-restricted-syntax` on
`exec`, `execSync` and `shell: true`). All spawns go through **one** documented module
(`server/src/proc/spawn.ts`):

- `spawn(file, args[], { shell: false, windowsHide: true, cwd: repoRoot, env })` with an
  absolute executable path. `PYTHON` is honoured like in the bin scripts, and `claude.exe` is
  resolved once from `PATH` [measured: `C:\Users\pavel\.local\bin\claude.exe`, a native exe,
  not a `.cmd` shim].
- **UTF-8 end to end:** set `PYTHONUTF8=1` and `PYTHONIOENCODING=utf-8` in the child
  environment, and read stdout and stderr as Buffers through `StringDecoder('utf8')`.
- **Call the Python CLI directly**: `python -X utf8 tools/backlog/backlog.py …` and
  `python -u tools/backlog/loop.py …`. `bin/backlog.sh` and `bin/backlog-loop.sh` are thin
  wrappers (`exec python …`, they only set `TANDEM_BACKLOG_PROG`), and the CLI they wrap is
  the same.
- **Why not through `bash.exe`:**
  - **MSYS2 argument conversion:** when Git Bash (an MSYS program) starts a native program,
    arguments that look like POSIX paths are rewritten. A title such as `/fix the /tmp
    handling` reaches Python changed.
  - `bash.exe` on `PATH` can be **WSL's** (`C:\Users\pavel\AppData\Local\Microsoft\WindowsApps\bash.exe`
    [measured: `where bash`]), the trap `tools/test_bin_help.py` already guards against.
  - One extra process layer makes killing harder.

  If the app must ever run a bin script, resolve Git's bash the way `test_bin_help.py` does
  and set `MSYS2_ARG_CONV_EXCL='*'` and `MSYS_NO_PATHCONV=1`.
- **User text never on a command line. It goes on stdin.** Today `backlog.py` takes all text
  as argv (`new --title/--problem/--evidence/--expected`, `log <text>`, `set key=value`,
  `move --reason`, `block --reason` [measured: argparse definitions]). That is not shell
  injection, because `CreateProcessW` plus CRT argv parsing is not a shell. It still has three
  problems:
  - a 32,767-character command-line limit;
  - text starting with `-` is parsed as an option;
  - command lines are visible to every local user through process listings.

  **Companion change (stdlib only, tested in `test_backlog.py`):** a global
  `--input-json -` option. The command reads a JSON object of its text fields from stdin, and
  argv carries only the command, the slug and enum-like values validated by zod first. This is
  the only change the web app needs in the Python tool. Until it exists, the fallback is argv
  in `--field=value` form (no leading-dash ambiguity), with length checks.
- **Serialise writes:** one in-process FIFO queue for all mutating CLI calls. Each mutation
  carries the revision the user saw, and the server refuses with **409** when the file changed
  in between (optimistic concurrency against the loop and agents writing at the same time).
- **Natural-language questions:** spawn `claude -p --output-format stream-json --verbose
  --tools Read,Grep,Glob --no-session-persistence --max-budget-usd <cap>` with the
  **question on stdin** (it is never part of argv), cwd = repository root, at most one at a
  time, and a timeout. The flags were verified with `claude --help`, Claude Code 2.1.314
  [measured]. The read-only tool set means a prompt-injected item text cannot make the agent
  write or run anything.
- **The loop:**
  - **Start** with `python -u tools/backlog/loop.py start [...]`, spawned **detached**
    (`detached: true`, `stdio` to a log file under `temp/` or `.agent-traces/`, `unref()`),
    so closing the app does not kill a running item and no pipe can fill up.
  - **Pause, resume and stop** with `loop.py pause|resume|stop`. These are the loop's own
    graceful control-file commands, so there are no signals.
  - **Status** with `loop.py status --json`, polled every 2 s and also on state-file change.
  - **Hard stop** needs confirmation. It runs `%SystemRoot%\System32\taskkill.exe /PID <pid>
    /T /F`, the same mechanism as `loop.py`'s own `kill_tree`, with the full System32 path
    because Git's tools shadow System32 names. The loop record tells the next start to
    continue the item.
  - Node cannot deliver a console Ctrl+C to a detached child, and `child.kill()` on Windows
    is TerminateProcess without the tree. `tree-kill` (last release 2019) and `execa` are
    not needed.
- **App shutdown** on SIGINT, SIGTERM or SIGBREAK: close the HTTP server, end SSE, kill the
  trees of the app's *own* short-lived children (questions, CLI calls) with taskkill, and
  leave the detached loop running. Print a note saying so.

### 2.5 TypeScript execution

- **Node 24 native type stripping.** It is enabled by default and **Stable since v24.12.0**
  (v24.3.0 removed the warning). [measured: Node v24.22.1 ran `main.ts` importing a `.ts`
  workspace package through its npm-workspaces symlink with no flag and no warning; an `enum`
  failed as documented.]
- The server starts as `node packages/server/src/main.ts`, and `node --watch` restarts it in
  dev. There is **no server build and no `dist/` for the server**, and line numbers in stack
  traces are exact because types are replaced by whitespace.
- **Constraints**, enforced by `tsconfig`:
  - `erasableSyntaxOnly`: no enums, no namespaces with values, no parameter properties, no
    decorators;
  - `verbatimModuleSyntax` (`import type`);
  - `module: nodenext`;
  - `.ts` extensions in relative imports, with `allowImportingTsExtensions` + `noEmit`;
  - no `paths` aliases (use package names or `#` subpath imports);
  - no `.tsx` on the server.
- **The shared package exports `.ts` sources** (`"exports": { ".": "./src/index.ts" }`). This
  works because Node resolves the workspace symlink to its real path outside `node_modules`.
  Node refuses to strip types inside `node_modules`.
- **Type check:** `tsc -b` with **TypeScript 6.0.3** (2026-04-16). TypeScript **7.0.2** (the
  native Go compiler, 2026-07-08) is *not* usable yet as the project's `typescript`:
  `typescript-eslint` 8.72.1 has peer `typescript >=4.8.4 <6.1.0` and **TypeDoc** 0.28.20 has
  peer `6.0.x` [measured: `npm view … peerDependencies`]. TS 7 can be added later as an
  optional fast checker.
- **Rejected:**
  - **tsx** 4.23.15: an extra esbuild-based dependency, needed only for non-erasable syntax,
    which we forbid.
  - **compiled `tsc` output:** a build step, an outDir and source maps for no gain.

### 2.6 Validation

**zod 4.6.7** in `packages/shared` describes every request body, response, SSE event payload
and the shape of `backlog.py list --json` output. The server validates *the CLI's output*
too, so a format drift fails loudly. The same schemas give the client its types and its form
validation.

**valibot 1.5.0** is smaller, but agents are less familiar with it, and the Hono validator,
react-hook-form resolver and shadcn Form recipes all centre on zod. Use `zod/mini` in the web
bundle if size ever matters.

### 2.7 Testing

- **Vitest 5.0.5** (engines Node `^22.12 || ^24 || >=26`):
  - server unit tests (gate, token, manifest, JSONL tailer with split UTF-8 and partial lines,
    spawn adapter);
  - API tests through `app.request()`;
  - CLI-adapter tests against a **temporary copy** of a fixture backlog, the same pattern as
    `tools/backlog/test_backlog.py`;
  - web component tests with `jsdom` + `@testing-library/react`.
- **Playwright 1.64.1** e2e with **`channel: 'msedge'`**, the Edge already installed on
  Windows 11, so there is no browser download. The flows are a few smoke paths: list, filter,
  edit, drag-reorder (keyboard and mouse), trace tail, theme without flash. **Security tests:**
  a foreign Host gives 421 or 403, a foreign Origin on POST gives 403, a missing or bad token
  gives 401, a reused bootstrap code gives 401. **Accessibility:** `@axe-core/playwright`
  (MPL-2.0) on every main view.
- e2e runs against the production build started on a random port with a fixture repository
  (`--root`), never against the real `backlog/`.

### 2.8 Lint, format and "every file documented"

- **ESLint 10.13.0** (flat config) + `typescript-eslint` 8.72.1 (type-aware) +
  `eslint-plugin-react-hooks` 7.1.1 + `eslint-plugin-react-refresh`.
  `eslint-plugin-jsx-a11y` 6.10.2 is **left out** because its peer range ends at ESLint 9.
  Accessibility is covered by the Radix primitives and axe in e2e.
- **Documentation enforcement** (both error-level in `npm run lint`):
  - `eslint-plugin-jsdoc` 65.4.2 `require-jsdoc` with `publicOnly: false`. It requires
    comments on function declarations, methods, classes, arrow and function expressions
    assigned to variables, and through `contexts` also on `TSInterfaceDeclaration`,
    `TSTypeAliasDeclaration`, `TSPropertySignature`, `PropertyDefinition`, top-level
    `VariableDeclaration` and `TSMethodSignature`.
  - Further jsdoc rules: `require-description`, `require-param` / `require-returns` without
    types (`no-types`, since TypeScript carries them), `check-param-names`,
    `require-file-overview` for a file comment in every file, and `check-tag-names` with the
    TSDoc tags allowed.
  - `eslint-plugin-tsdoc` 0.5.4 `tsdoc/syntax`, which keeps the comments valid TSDoc. A
    `tsdoc.json` declares the file-overview tag.
- **TypeDoc 0.28.20** `npm run docs:check` uses `validation.notDocumented: true`,
  `treatValidationWarningsAsErrors: true` and `requiredToBeDocumented` for all reflection
  kinds. It writes no output (or writes it to an ignored folder), so it also catches
  undocumented exported members that lint context selectors miss.
- **A Vitest "repository rules" test** walks the `packages/*/src/**` files and checks:
  - the SPDX header (`SPDX-FileCopyrightText: 2026 Pavel Stupka`,
    `SPDX-License-Identifier: GPL-2.0-or-later`, as in `bin/*.sh`);
  - a file overview comment;
  - UTF-8 **without BOM** and LF;
  - no `shell: true` or `exec(`.

  "Inline comments at important points" cannot be checked mechanically and is a review item.
- **Prettier 3.9.10** formats, with `endOfLine: 'lf'` and `prettier-plugin-tailwindcss` 0.8.1
  for class order. Biome 2.6.4 is **rejected**: it has no rule that requires doc comments, so
  ESLint would be needed anyway, and running two linters is worse than ESLint + Prettier.
- **shadcn components** in `components/ui/` are application source after generation. They
  get the same SPDX header and TSDoc, so the rules apply uniformly. Do not regenerate them
  over documented files; changes are made by editing.

---

## 3. Monorepo layout, Node pinning, launcher

### 3.1 Layout

```
tools/backlog-app/
  package.json            private, "type": "module", "workspaces": ["packages/*"],
                          engines + devEngines, scripts: dev, build, start, typecheck,
                          lint, format, test, test:e2e, docs:check, check (= all gates)
  package-lock.json       the ONE lockfile, committed
  .npmrc                  engine-strict=true, save-exact=true, fund=false,
                          ignore-scripts=true (see 5.2)
  .nvmrc                  24
  tsconfig.base.json      strict, erasableSyntaxOnly, verbatimModuleSyntax, noEmit
  eslint.config.js        flat config (documented like any source file)
  .prettierrc.json, tsdoc.json, typedoc.json, playwright.config.ts, vitest.workspace.ts
  packages/
    shared/               @backlog-app/shared: zod schemas + inferred types for every
                          API request/response, SSE event union, route constants,
                          error codes; exports ./src/index.ts (no build)
    server/               @backlog-app/server: src/main.ts (args, listen, open
                          browser), gate/ (host, origin, token, CSP), api/ (Hono
                          routes), backlog/ (CLI adapter + write queue), loop/,
                          traces/ (tailer), ask/ (claude), watch/, static/ (manifest),
                          proc/ (the only spawn module)
    web/                  @backlog-app/web: Vite React SPA; src/components/ui (shadcn),
                          src/features/{backlog,item,loop,traces,ask}, src/lib (api
                          client, SSE hook, theme); public/theme-init.js; dist/ (ignored)
  e2e/                    Playwright specs + fixture repository
```

### 3.2 Node version

- Target **Node 24** (installed v24.22.1; LTS, maintenance phase since 2026-10-20, EOL
  2028-04-30). Allow **Node 26** (Active LTS since 2026-10-28).
- **The minimum is 24.15.0:** type stripping is stable from 24.12.0, and eslint-plugin-jsdoc
  65 has engines `^22.22.2 || >=24.15.0`. Vitest excludes the odd release 25.
- In `package.json`: `"engines": { "node": "^24.15.0 || ^26.0.0" }`, plus npm's
  `devEngines.runtime` (`onFail: "error"`) and `devEngines.packageManager` (npm ≥ 11).
- `.npmrc` `engine-strict=true` makes `npm ci` fail on a wrong Node. `.nvmrc` holds `24` for
  nvm-windows and fnm.
- The launcher also checks the version itself and prints a plain message.

### 3.3 `bin/start-backlog-app.sh` (Git Bash)

1. **`--help` / `-h` / `help`:** print `Usage: bin/start-backlog-app.sh [--dev] [--port N]
   [--no-open] [--root DIR]` plus what it is for, at least 3 lines, then exit 0 **without
   needing Node** (the `tools/test_bin_help.py` contract: exit 0, "usage" in stdout, at least
   3 lines; the test runs it with Git's bash, cwd = repository root). An unknown option exits
   2 with usage on stderr, like the other bin scripts.
2. Locate `node` and check that `node -p process.versions.node` is ≥ 24.15.0 (or 26.x). Exit
   1 with a clear message otherwise.
3. `cd tools/backlog-app`. If `node_modules/` is missing, or the stored SHA-256 of
   `package-lock.json` (stamp file `node_modules/.backlog-app-lock.sha256`) differs, run
   `npm ci --no-audit --no-fund` and rewrite the stamp.
4. Unless `--dev`, run `npm run build` (`vite build`, a few seconds with Rolldown). A
   source-hash stamp can skip the build when nothing changed. Measure first; always building
   is simpler and correct.
5. `exec node packages/server/src/main.ts --root "$repo" [--dev] [--port N] [--no-open]`.
   With `exec`, Ctrl+C reaches Node directly. The server:
   - binds **127.0.0.1** to the requested port, or to **port 0** (the OS picks a free port,
     so there is no race as with a get-port probe);
   - generates the token and a one-time bootstrap code;
   - prints `Backlog app: http://127.0.0.1:<port>/?boot=<code>` and "Ctrl+C stops the app
     (a running loop keeps running)";
   - opens the browser with `%SystemRoot%\System32\rundll32.exe url.dll,FileProtocolHandler
     <url>` (no `cmd /c start`, whose `&` and `^` parsing and fragment loss are avoided by
     design);
   - on SIGINT, SIGTERM or SIGBREAK, shuts down cleanly (section 2.4) and exits 0.
6. Optional later: a per-repository instance file in `temp/` (pid, port), so a second launch
   asks the running server for a new bootstrap URL instead of starting a second server.

Write the script with the editor tools, not heredocs (CLAUDE.md rule, 123). Use LF line
endings (`.gitattributes` `*.sh text eol=lf`). Give it the SPDX header like the other bin
scripts.

**Dev mode:** `--dev` serves the SPA through Vite middleware with HMR (section 1.4) and runs
the server under `node --watch` (the launcher execs
`node --watch-path=packages/server/src --watch-path=packages/shared/src …`). `npm run dev`
does the same without the launcher.

---

## 4. Localhost security, concretely

**Threat model for v1.** The attacker is (a) **a malicious web page** in the maintainer's
browser (CSRF, DNS rebinding, cross-origin reads, cross-site WebSocket or SSE), or (b)
**another OS user or process on the same machine.** On Windows, loopback is reachable by every
local user and by RDP sessions. Processes of the *same* user are out of scope: they can already
run `bin/backlog.sh` and read the repository.

### 4.1 Bind

- Listen on **`127.0.0.1` only**. Never bind `0.0.0.0` or `::`. A loopback bind also triggers
  **no Windows Firewall prompt**.
- **Do not bind `::1`.** One address is enough, and the app always prints and opens
  `127.0.0.1` (Node ≥ 17 and browsers may resolve `localhost` to `::1` first).
- At startup, verify `server.address().address === '127.0.0.1'` and abort otherwise.

### 4.2 Host-header allow-list (DNS rebinding)

Reject any request whose `Host` is not exactly `127.0.0.1:<port>` or `localhost:<port>`.
Answer **421 Misdirected Request**, with no body detail. A rebinding page at
`evil.example:<port>` therefore gets nothing, even before the token check. The same check
applies to SSE and, in `--dev`, to Vite's HMR upgrade.

### 4.3 Origin and Fetch-Metadata checks

- For every **state-changing** method (POST, PUT, PATCH, DELETE) and every SSE endpoint:
  require `Origin` to equal `http://127.0.0.1:<port>` or `http://localhost:<port>`, and
  reject `Sec-Fetch-Site: cross-site` / `same-site`. Hono's `csrf()` middleware implements
  this pair of checks.
- An absent Origin on a POST is rejected; browsers always send it on POST.
- GET API calls are side-effect free by contract, and the token protects them anyway.

### 4.4 Per-launch token: bearer, not cookie

The server generates **32 random bytes** (`crypto.randomBytes`, base64url) at every start.
Nothing is persisted.

- **Bootstrap:** the opened URL carries a **one-time code** `?boot=<code>`. It is separate
  from the token, valid once and for 120 s. The SPA posts it to `/api/session/claim` and gets
  the token in the JSON response. It stores the token in `localStorage`, which is per origin,
  and the origin includes the port, so each launch is a fresh origin. Then it removes `boot`
  from the address bar with `history.replaceState`.
- A code that leaks through browser history is useless once claimed. A new tab of the same
  origin reads the token from `localStorage`. A "copy link" command mints a new one-time code
  through an authenticated call.
- **Every `/api` request carries `Authorization: Bearer <token>`.** The server compares it in
  constant time (`crypto.timingSafeEqual`). SSE uses `?k=` (section 2.2).
- **Why not a cookie:**
  - cookies are **not port-isolated**: a cookie for `127.0.0.1` is sent to *every* port on
    127.0.0.1;
  - a server run by another local user on another port, opened in the maintainer's browser,
    would receive it;
  - a cookie would also re-introduce classic CSRF.

  A bearer header is never attached automatically by the browser, so CSRF is structurally
  impossible. Sections 4.2 and 4.3 are defence in depth.
- The static SPA files (HTML, JS, CSS) need no token; they contain no data. Every `/api` route
  except `session/claim` requires the token.

### 4.5 CORS off, JSON only, limits

- **No `Access-Control-*` headers at all.** Cross-origin reads fail, and preflights get 403.
- Mutations require `Content-Type: application/json`; anything else gets **415**. That
  rules out "simple" cross-site form posts.
- Body limit: 256 KiB, with Hono's `bodyLimit`.
- Rate and concurrency: at most one claude question at a time, and the write queue
  serialises CLI calls.

### 4.6 Response headers and CSP (no remote content)

The headers:

```
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';
  img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none';
  base-uri 'none'; form-action 'self'; frame-ancestors 'none'
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
Cache-Control: no-store            (API); hashed assets: immutable
```

- `'unsafe-inline'` for styles only: Radix positioning and sonner inject style elements.
  Script stays strictly `'self'`, with the theme script external (section 1.6).
- In `--dev`, Vite needs `connect-src 'self' ws://127.0.0.1:<port>` for HMR, plus Vite's own
  inline preamble. The dev CSP is relaxed accordingly, and dev mode is printed as such.
- **Nothing remote:** fonts are system fonts, icons are bundled, there is no CDN and no
  analytics. Rendered Markdown cannot load remote images, because the CSP `img-src` blocks
  them. Links open with `rel="noopener noreferrer"`.

### 4.7 Path traversal

- **Static files:** at startup, enumerate `packages/web/dist/` once into a
  `Map<urlPath, {absPath, type}>`. A request is served only on an **exact key match**;
  anything else under `/assets/` is 404, and other paths fall back to `index.html` (SPA).
  No request string ever reaches `path.join`. This sidesteps the whole class of the
  `%5C`-on-Windows bug.
- **Item and trace files** are addressed by **identifier, never by path:**
  - a slug is validated against `^[a-z0-9][a-z0-9-]{0,80}$` and must exist in the CLI's list;
  - a trace id must exist in the trace index.

  The server builds the path itself, `realpath`s it and checks with an ordinal,
  case-insensitive prefix test (Windows paths) that it lies under `backlog/items/` or
  `.agent-traces/`.
- **Reads** of `desc.md` may be direct. **Writes go only through the CLI.**

### 4.8 Item text is never code

- `shell: false` everywhere, and the arguments are an array. Text goes on stdin (section 2.4).
- No `eval`, no `new Function`, no `dangerouslySetInnerHTML`.
- Markdown goes through `react-markdown` without raw HTML.
- The claude question runs with read-only tools.

### 4.9 What is enough for v1, and why

**Enough for v1:** sections 4.1 to 4.8 as listed. Their cost is about 200 lines in one
documented `gate/` module plus tests. Together they close every remote vector (a malicious
page: rebinding, CSRF and cross-origin reads) and the local multi-user vector (the token).

**Deliberately not in v1:**

- **TLS on loopback:** there is no network path to protect, and certificates would add
  friction.
- **Named-pipe or Unix-socket transport:** the browser cannot speak it.
- **Per-user OS ACLs on the port:** Windows offers none for TCP loopback, which is exactly
  why the token exists.
- **Protection against the same OS user's own processes:** impossible by design, and
  unnecessary.

---

## 5. Repository policy fit

### 5.1 Dependencies against the project's rules

- The C++ product vendors everything and uses zero NuGet. **The web app is not part of the
  product.** It is never built by `build.cmd`, never shipped by the installer, never signed
  and never in a release archive. It is a maintainer tool, in the same category as
  `tools/translate` and `tools/comments`.
- That category already has a precedent: `tools/pyproject.toml` declares third-party Python
  packages (wordfreq, plotly, tree-sitter, anthropic) with a committed `tools/uv.lock` and an
  uncommitted `tools/.venv`. normalize.ps1 excludes `./tools/.venv/*`.
- The stdlib-only rule (`tools/backlog/loop.py` "stdlib only", contract of 247) applies to the
  **backlog Python tools**. It stays intact: the only Python change is the stdlib
  `--input-json -` option.
- **npm, by the same pattern:**
  - `package-lock.json` is committed, `node_modules/` and `dist/` are ignored, and installs
    are always `npm ci` (exact, reproducible);
  - `save-exact=true` pins exact versions in `package.json` too;
  - no `postinstall` hooks: `.npmrc` `ignore-scripts=true`. The build chain needs none:
    `vite` (rolldown, lightningcss) and `@tailwindcss/oxide` ship prebuilt platform binaries
    as optional dependencies, and the published packages define no install scripts
    [measured: `npm view … scripts`]. Verify on the first `npm ci`; Playwright's browsers are
    not needed (msedge channel);
  - `npm audit signatures` can be run by the maintainer.
- **Licences:** the GPL question arises on *distribution of a combined work*. The app's own
  sources carry `GPL-2.0-or-later` (SPDX). No npm package is committed, and the built bundle
  is not distributed. All packages are permissive (MIT, ISC, BSD-3, Apache-2.0, MPL-2.0 for
  axe only, OFL not used).
  - Apache-2.0 is compatible with GPL-2.0-*or-later* through GPLv3, and it is used only by
    dev tools (TypeScript, Playwright, TypeDoc) and by `class-variance-authority` (bundled,
    not distributed).
  - **PrimeVue 5's PrimeUI licence** (licence key, eligibility tiers, OEM restrictions) is
    the one candidate that would be **incompatible**; it is rejected.
- **PRIVACY.md:** no change. The tool is not in the product. It talks to nothing but loopback
  and the local `claude` CLI, which the maintainer already uses.

### 5.2 Effects on the existing build and checks

| Mechanism | What it scans | Effect of `tools/backlog-app/` | Action |
|---|---|---|---|
| `tools/check_encoding.py` (run by `build.cmd`, `--strict`) | Only `src/**/*.cpp` (`SRC = REPO / "src"`, `SRC.rglob("*.cpp")`) | **None** | none |
| `build.cmd` | MSBuild solution `src/vcxproj/salamand.sln`, `check_encoding.py`, `check_runtime_deps.py` on the output | **None.** No glob over `tools/`, no Node | none |
| `normalize.ps1` (+ `normalize_config.json`) | **Walks the whole repository tree** (`Directory.EnumerateFiles(base, '*', recurse)`). clang-format on `*.cpp *.h *.c`; BOM + CRLF on `*.c *.h *.ps1 *.config *.htm *.props …` | **Real hazard.** `node_modules/` contains `.ps1` shims in `node_modules/.bin/`, possibly `.c` / `.h` / `.config` files, and it would rewrite them (BOM, CRLF, clang-format) and slow the run. The app's own `.ts`, `.tsx`, `.json`, `.css` and `.html` are not in its include list (it lists `*.htm`, not `*.html`) | **Add excludes** `./tools/backlog-app/node_modules/*`, `./tools/backlog-app/packages/*/node_modules/*` and `./tools/backlog-app/packages/web/dist/*` to *both* the `clangformat` and the `textfiles` exclude lists, next to the existing `./tools/.venv/*` |
| `.gitignore` | (root; no `node_modules` rule today) | `node_modules/` would show as untracked | **Add** `/tools/backlog-app/node_modules/`, `/tools/backlog-app/packages/*/node_modules/`, `/tools/backlog-app/packages/web/dist/`, `/tools/backlog-app/test-results/`, `/tools/backlog-app/playwright-report/`, `/tools/backlog-app/docs-api/` |
| `.editorconfig` | `[*] end_of_line = crlf, indent_size = 4` | Conflicts with Prettier (LF, 2 spaces) | **Add** `[tools/backlog-app/**]` with `end_of_line = lf`, `indent_size = 2`, `charset = utf-8` (no BOM), `insert_final_newline = true` |
| `.gitattributes` | `* text=auto`; `*.sh eol=lf`, `*.cmd eol=crlf` | A checkout with autocrlf could give CRLF that Prettier then flags | **Add** `tools/backlog-app/** text eol=lf` (binary types are already declared) |
| Encoding rule (CLAUDE.md "Sources: UTF-8-BOM, clang-format"; architecture/12 "Encoding: UTF-8-BOM, formatted with clang-format") | C++ sources | Not applicable to TypeScript. A BOM in `package.json` breaks JSON parsers | **UTF-8 without BOM, LF** for everything under `tools/backlog-app/`, checked by the repository-rules test (2.8). Record the exception in the feature history |
| `.github/workflows/pr-comments-guard.yml` | C/C++ comment guard over include roots under `src/` | None | none |
| `tools/test_bin_help.py` | Every file in `bin/`: `.sh` runs with Git's bash, `--help` must exit 0, contain "usage", at least 3 lines | `bin/start-backlog-app.sh` is picked up automatically | `--help` handled before any Node check (3.3 step 1) |
| `tools/pyproject.toml` (setuptools `packages = ["comments", "translate"]`) | Explicit package list | None | none |

---

## 6. Recommended stack (pin table)

Versions are the npm `latest` on 2026-10-30, pinned exactly (`save-exact`). Rows marked *
were released less than 14 days ago. The lockfile records them; if the first install shows a
regression, step back to the previous patch.

### Runtime and tooling (devDependencies at the root)

| Package | Version | Released | Licence | Purpose |
|---|---|---|---|---|
| Node.js | 24.x (≥ 24.15.0; 26.x allowed) | 24 LTS, EOL 2028-04-30 | MIT | Runtime; native type stripping |
| npm | 11.x (installed 11.21.1) | — | Artistic-2.0 | Workspaces, `npm ci`, devEngines |
| typescript | **6.0.3** | 2026-04-16 | Apache-2.0 | `tsc -b` type check (TS 7 blocked by typescript-eslint / TypeDoc peers) |
| @types/node | 26.6.6* | 2026-10-28 | MIT | Node typings |
| eslint | 10.13.0 | 2026-10-16 | MIT | Linter |
| @eslint/js | 10.0.1 | 2026-02-06 | MIT | Recommended rules |
| typescript-eslint | 8.72.1* | 2026-10-26 | MIT | Type-aware TS rules |
| eslint-plugin-jsdoc | 65.4.2* | 2026-10-23 | BSD-3-Clause | `require-jsdoc`, file overview, param and returns |
| eslint-plugin-tsdoc | 0.5.4 | 2026-09-29 | MIT | TSDoc syntax |
| eslint-plugin-react-hooks | 7.1.1 | 2026-04-17 | MIT | Hooks rules |
| eslint-plugin-react-refresh | 0.5.7 | 2026-09-14 | MIT | HMR-safe exports |
| globals | 17.13.0 | 2026-10-01 | MIT | ESLint globals |
| prettier | 3.9.10 | 2026-10-10 | MIT | Formatter |
| prettier-plugin-tailwindcss | 0.8.1 | — | MIT | Class order |
| typedoc | 0.28.20 | 2026-07-05 | Apache-2.0 | `notDocumented` validation |
| vitest | 5.0.5 | 2026-10-15 | MIT | Unit, API and component tests |
| @vitest/coverage-v8 | 5.0.5 | 2026-10-15 | MIT | Coverage |
| jsdom | 30.1.3 | 2026-10-15 | MIT | DOM for component tests |
| @testing-library/react | 16.3.3 | 2026-08-27 | MIT | Component tests |
| @playwright/test | 1.64.1 | 2026-10-14 | Apache-2.0 | e2e on installed Edge (`channel: 'msedge'`) |
| @axe-core/playwright | 4.14.0 | 2026-10-15 | MPL-2.0 | Accessibility checks in e2e |

### Server (`packages/server`)

| Package | Version | Released | Licence | Purpose |
|---|---|---|---|---|
| hono | 4.13.14* | 2026-10-25 | MIT | Routing, `streamSSE`, `csrf`, `secureHeaders`, `bodyLimit` |
| @hono/node-server | 2.1.5 | 2026-10-13 | MIT | `getRequestListener` for `node:http` (not `serveStatic`) |
| @hono/zod-validator | 0.9.1 | — | MIT | Request validation |
| zod | 4.6.7 | 2026-10-12 | MIT | (via shared) schemas |
| vite | 8.3.5* | 2026-10-21 | MIT | Dynamic import only in `--dev` (middleware mode HMR) |
| *(node built-ins)* | — | — | — | `node:http`, `node:fs` (watch, read), `node:child_process`, `node:crypto`, `node:string_decoder` |

### Shared (`packages/shared`)

| Package | Version | Released | Licence | Purpose |
|---|---|---|---|---|
| zod | 4.6.7 | 2026-10-12 | MIT | API contracts, SSE events, CLI-output schemas, inferred types |

### Web (`packages/web`)

| Package | Version | Released | Licence | Purpose |
|---|---|---|---|---|
| react, react-dom | 19.3.1 | 2026-10-14 | MIT | UI |
| @types/react, @types/react-dom | 19.3.x | 2026-09-09 | MIT | Typings |
| vite | 8.3.5* | 2026-10-21 | MIT | Dev server (middleware) and build (Rolldown) |
| @vitejs/plugin-react | 6.1.2 | 2026-10-05 | MIT | React transform / Fast Refresh |
| tailwindcss, @tailwindcss/vite | 4.3.3 | 2026-07-16 | MIT | Styling, `dark` variant, CSS variables |
| shadcn (CLI, dev only) | 4.23.0* | 2026-10-27 | MIT | Generates `components/ui` (Radix base) |
| radix-ui | 1.8.1 | 2026-10-12 | MIT | Accessible primitives (Dialog, Popover, Dropdown, Tooltip, Tabs, ...) |
| class-variance-authority | 0.7.1 | 2024-11-26 | Apache-2.0 | Component variants (shadcn) |
| clsx | 2.1.1 | 2024-04-23 | MIT | Class composition |
| tailwind-merge | 3.7.0 | 2026-09-12 | MIT | Class merging (`cn()`) |
| @tanstack/react-table | 9.3.1 | 2026-10-12 | MIT | Backlog table: sort, filter, column visibility |
| react-virtuoso | 4.18.20* | 2026-10-29 | MIT | Virtualised, auto-following trace log |
| @tanstack/react-virtual | 3.14.24* | 2026-10-29 | MIT | Reserve: table virtualisation if > ~2,000 rows |
| @dnd-kit/core | 6.3.1 | 2024-12-05 | MIT | Drag and drop (keyboard sensor, announcements) |
| @dnd-kit/sortable | 10.0.0 | 2024-12-04 | MIT | Sortable list (reorder within and between sections) |
| cmdk | 1.1.1 | 2025-03-14 | MIT | Command palette (shadcn `Command`) |
| sonner | 2.0.8 | 2026-08-09 | MIT | Toasts |
| react-resizable-panels | 4.15.2* | 2026-10-29 | MIT | Split panes (list / detail / trace) |
| react-hotkeys-hook | 5.3.3 | 2026-06-26 | MIT | Keyboard shortcuts |
| react-markdown | 10.1.0 | 2025-03-07 | MIT | Markdown rendering (no raw HTML) |
| remark-gfm | 4.0.1 | 2025-02-10 | MIT | Tables, task lists, strikethrough |
| @uiw/react-codemirror | 4.25.12 | 2026-09-24 | MIT | Markdown source editor (CodeMirror 6) |
| @codemirror/lang-markdown | 6.5.2 | 2026-08-04 | MIT | Markdown language mode |
| @tanstack/react-query | 5.105.0* | 2026-10-26 | MIT | Server state, SSE-driven invalidation, optimistic reorder |
| @tanstack/react-router | 1.170.46 | 2026-10-22 | MIT | Typed routes and search params (filters in the URL) |
| zustand | 5.0.16 | 2026-10-22 | MIT | Small client state (theme, layout, stream buffers) |
| react-hook-form | 7.91.0 | 2026-10-23 | MIT | Item forms |
| @hookform/resolvers | 6.0.2* | 2026-10-28 | MIT | zod resolver |
| lucide-react | 1.65.0* | 2026-10-30 | ISC | Icons (bundled, tree-shaken) |
| recharts | 3.10.1 | 2026-07-25 | MIT | Run statistics charts (shadcn Chart) |
| date-fns | 4.4.0 | 2026-05-29 | MIT | Date formatting (relative times in runs) |

Not used, deliberately: next-themes (Next.js-oriented), fontsource (system fonts),
dompurify / rehype-sanitize (no raw HTML is ever rendered), execa / cross-spawn / tree-kill
(direct `spawn` + `taskkill`), chokidar (`fs.watch`), get-port (port 0), open (rundll32),
concurrently (single-process dev mode), ws (SSE).

## 7. Rejected alternatives (summary)

| Alternative | Reason |
|---|---|
| Svelte 5 / SvelteKit 3 (+ shadcn-svelte, bits-ui) | Lower agent familiarity (Svelte 4 vs runes mix-ups); thinner ecosystem for table, DnD and command; SvelteKit adds an SSR server that duplicates the backend |
| Vue 3 + PrimeVue 5 | **PrimeVue 5 is under the proprietary PrimeUI licence** (licence key, eligibility tiers); not acceptable in a GPL repository |
| Vue 3 + Naive UI | Viable (MIT, good table and theming), but weaker DnD, command-palette and split-pane story and less agent familiarity than React |
| Solid 1.9 (+ Kobalte) | Smallest ecosystem and least agent familiarity |
| React + Mantine 9 | Runner-up. No core data table, library-owned styling, awkward with Tailwind |
| shadcn on Base UI | Acceptable alternative (the shadcn default since 2026-07). Radix chosen because cmdk already depends on Radix (one primitive family) and for agent familiarity. Maintainer decision |
| Next.js / SvelteKit / React Router framework / TanStack Start | SSR and a second server add nothing to a localhost single-user tool and complicate the security gate |
| Fastify 5 | Heavier, JSON Schema as a second validation language; its performance is irrelevant here |
| Express 5 | Untyped core, no SSE helper, security needs extra dependencies |
| Plain `node:http` only | Hand-written routing and validation (kept as the outer shell only) |
| WebSocket (`ws`, `@hono/node-ws`) | No bidirectional need; extra upgrade-path security; SSE resume maps onto byte offsets |
| chokidar 6 | Uses the same native `fs.watch` on Windows; the re-read design needs no heuristics; 11 days old with breaking changes |
| tsx / compiled `tsc` output | Node 24 strips types natively (stable since 24.12); no build step needed |
| TypeScript 7.0 as the project compiler | typescript-eslint (`<6.1.0`) and TypeDoc (`6.0.x`) peers exclude it today |
| valibot | Smaller, but zod is what Hono, react-hook-form and shadcn recipes and agents centre on |
| Biome | No rule that requires doc comments, so ESLint is needed anyway |
| eslint-plugin-jsx-a11y | No ESLint 10 support (peer ends at ^9); axe in e2e instead |
| @dnd-kit/react 0.5 | Pre-1.0 API; revisit at 1.0 |
| Pragmatic DnD | Apache-2.0, more hand-written code, fewer examples |
| MDXEditor / WYSIWYG Markdown | Re-serialises Markdown and would break the item format |
| Cookie session | Cookies are not port-isolated on 127.0.0.1 and re-introduce CSRF; a bearer token is not sent automatically |
| Calling `bin/backlog.sh` through bash.exe | MSYS path conversion can alter user text; WSL `bash.exe` on PATH; extra process layer |

## 8. Open points for the plan

1. The stdlib extension `backlog.py --input-json -`: text fields from stdin, plus tests in
   `test_backlog.py`. This is a precondition for "never user text on a command line".
2. Radix (default) or Base UI: maintainer decision, low cost either way.
3. Whether the detached loop's stdout log goes to `temp/` or `.agent-traces/`. Reconcile with
   the traces contract of 342.
4. The `normalize_config.json`, `.gitignore`, `.editorconfig` and `.gitattributes` edits from
   section 5.2 belong to the same change that adds `tools/backlog-app/`.

## Sources

- npm registry (`npm view`), queried 2026-10-30: versions, release times, licences, peer
  dependencies, engines, scripts
- Vite 8 announcement: https://vite.dev/blog/announcing-vite8
- Rolldown / Vite 8 changes: https://certificates.dev/blog/rolldown-and-vite-8-what-changed
- Node.js TypeScript (type stripping) docs: https://nodejs.org/docs/latest-v24.x/api/typescript.html
- Node.js release schedule: https://github.com/nodejs/Release
- shadcn Base UI default: https://releasebot.io/updates/shadcn ,
  https://hextaui.com/blog/shadcn-base-ui-vs-radix ,
  https://blog.openreplay.com/shadcn-ui-radix-base-ui-switch/
- shadcn data table (TanStack Table v9, Base UI / Radix / React Aria tabs): https://ui.shadcn.com/docs/components/data-table
- TanStack Table v9 migration: https://tanstack.com/table/latest/docs/framework/solid/guide/migrating
- dnd-kit migration (`@dnd-kit/react`): https://github.com/clauderic/dnd-kit ;
  comparison https://www.pkgpulse.com/guides/dnd-kit-vs-react-beautiful-dnd-vs-pragmatic-drag-drop-2026
- chokidar releases (5.0.0, 6.0.0): https://github.com/paulmillr/chokidar/releases
- PrimeVue 5 licence: https://unpkg.com/primevue@5.0.2/LICENSE.md
- Vite CVE-2025-24010 (Host check, CORS, HMR WebSocket): https://www.miggo.io/vulnerability-database/cve/CVE-2025-24010 ,
  https://db.fluidattacks.com/adv/npm/vite/CVE-2025-24010
- @hono/node-server `serveStatic` Windows traversal: https://advisories.gitlab.com/npm/@hono/node-server/GHSA-frvp-7c67-39w9/ ;
  Hono CVE-2026-54286: https://advisories.gitlab.com/npm/hono/CVE-2026-54286/
- Hono secure headers: https://hono.dev/middleware/builtin/secure-headers
- Repository files read: `tools/check_encoding.py`, `tools/test_bin_help.py`, `normalize.ps1`,
  `normalize_config.json`, `.gitignore`, `.editorconfig`, `.gitattributes`, `build.cmd`,
  `bin/backlog.sh`, `bin/backlog-loop.sh`, `tools/backlog/backlog.py` (argparse),
  `tools/backlog/loop.py` (spawn, kill_tree, stream-json), `tools/pyproject.toml`,
  `architecture/12-project-reference.md`, `.github/workflows/pr-comments-guard.yml`
