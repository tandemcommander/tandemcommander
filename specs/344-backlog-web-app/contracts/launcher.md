# Contract: `bin/start-backlog-app.sh` (feature 344)

```text
bin/start-backlog-app.sh [--dev] [--port N] [--no-open] [--root DIR]
bin/start-backlog-app.sh --help | -h | help
```

Git Bash script, LF line ends, SPDX header like the other `bin/` scripts, written with the
editor tools (CLAUDE.md rule 123).

| Option | Meaning |
|---|---|
| `--help`, `-h`, `help` | Prints what the command is for, the usage line and every option (at least 3 lines, containing `usage`), exits 0 **without needing Node** (`tools/test_bin_help.py`). |
| `--dev` | Development mode: the SPA through Vite middleware with live reload, the server under `node --watch`; no build. |
| `--port N` | Listen on port N (1024-65535) instead of the default 47321. |
| `--no-open` | Do not open the browser; only print the address. |
| `--root DIR` | Another repository (tests); default: the repository containing the script. |

An unknown option exits 2 with the usage on stderr.

## Steps

1. Find `node`; require `>= 24.15.0` or `26.x` (`node -p process.versions.node`). Otherwise
   exit 1: `the backlog app needs Node.js 24.15 or newer (found: <v or none>) - install it from
   https://nodejs.org or with winget install OpenJS.NodeJS.LTS`.
2. In `tools/backlog-app/`: when `node_modules/` is missing or
   `node_modules/.backlog-app-lock.sha256` differs from the SHA-256 of `package-lock.json`, run
   `npm ci --no-audit --no-fund` and write the stamp. A failing `npm ci` exits 1 with its
   output.
3. Unless `--dev`: when `packages/web/dist/.source.sha256` differs from the hash of the web
   sources (`packages/web/src`, `packages/shared/src`, `index.html`, the Vite and Tailwind
   configs), run `npm run build` and write the stamp.
4. `exec node packages/server/src/main.ts --root <repo> [--dev] [--port N] [--no-open]`
   (`exec`: Ctrl+C reaches Node directly).

## Server start (`main.ts`)

1. Instance file `<git-common-dir>/tandem-backlog-app/instance.json`: if it names a live
   process (pid + creation time) of this application for the same repository, ask it for a new
   bootstrap address, print it (and open it unless `--no-open`), exit 0.
2. Listen on `127.0.0.1:<port>`; a port in use by something else: exit 1, `port <N> is in use
   - start with --port <another>`.
3. Print:

   ```text
   Backlog app: http://127.0.0.1:<port>/?boot=<code>
   Repository: <root> (branch <b>)
   Ctrl+C stops the app; a running backlog loop keeps running.
   ```

4. Open the address with `%SystemRoot%\System32\rundll32.exe url.dll,FileProtocolHandler <url>`
   unless `--no-open`.
5. On SIGINT, SIGTERM or SIGBREAK: stop accepting requests, end the streams, end the app's own
   children (tool calls, AI jobs) with `taskkill /T /F`, release a held edit lock, remove the
   instance file, exit 0. The loop is never touched.

## Exit codes

`0` ended as asked (Ctrl+C, or a running instance was found); `1` a precondition failed (Node,
`npm ci`, build, port, not a git repository, Python missing); `2` usage.
