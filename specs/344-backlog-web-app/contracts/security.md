# Contract: access rules of the backlog app (feature 344)

Threat model: (a) a malicious web page in the maintainer's browser (CSRF, DNS rebinding,
cross-origin reads); (b) another user or session on the same machine. Out of scope: processes
of the same user (they can run the tools directly). Rationale: research R18, analysis A3 §4.

All rules live in one module (`packages/server/src/gate/`) and run **before** routing, in this
order, for every request (API, streams, static files, Vite in `--dev`):

| # | Rule | On failure |
|---|---|---|
| 1 | The server listens on `127.0.0.1` only (never `0.0.0.0`, `::`, `::1`); at start it verifies `server.address().address === "127.0.0.1"` and aborts otherwise. | start aborted |
| 2 | `Host` is exactly `127.0.0.1:<port>` or `localhost:<port>`. | 421, empty body |
| 3 | For `POST`, `PUT`, `PATCH`, `DELETE` and every stream: `Origin` is `http://127.0.0.1:<port>` or `http://localhost:<port>` (absent = refused), and `Sec-Fetch-Site` is absent or `same-origin` / `none`. | 403 |
| 4 | Changing requests have `Content-Type: application/json`; bodies <= 256 KiB. | 415 / 413 |
| 5 | Every `/api/*` route except `POST /api/session/claim` needs `Authorization: Bearer <token>`, compared in constant time. | 401 |
| 6 | Static files are served only by exact lookup in a manifest built at start from `packages/web/dist/`; unknown `/assets/*` = 404; any other path = `index.html`. No request text reaches a path function. | 404 |
| 7 | Items, runs, features and files are addressed by identifiers validated against a pattern **and** against the tool's listing (slug `^[a-z0-9]+(-[a-z0-9]+)*$` and present; run id present in the index or `run.json`; feature `^\d{3}$` and a folder exists; file names from the item's or feature's listing). The server builds the path itself, resolves it and checks an ordinal case-insensitive prefix (`backlog/items/`, `.agent-traces/`, `specs/`). | 404 |

## Token and bootstrap

- At every start: token = 32 random bytes (`crypto.randomBytes`, base64url); nothing stored on
  disk. Bootstrap code = 16 random bytes, single use, valid 120 s; a new one is minted for the
  opened address, for `POST /api/session/link`, and when the launcher finds a running instance
  (it asks the instance through the instance file's port with a launcher secret written to the
  instance file - readable only by the user who started it).
- The page posts the code to `/api/session/claim`, keeps the token in `sessionStorage` and in
  `localStorage` (other tabs of the same origin), and removes `?boot=` from the address with
  `history.replaceState`.
- A token of an earlier start is refused (401); the page then shows "the app was restarted -
  open the address printed in the terminal" and offers nothing else.
- No cookies are set or read.

## Response headers

```text
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline';
  img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none';
  form-action 'self'; frame-ancestors 'none'
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Resource-Policy: same-origin
Cache-Control: no-store                      (API and index.html; hashed assets: immutable)
```

No `Access-Control-*` header is ever sent. In `--dev` the CSP adds what Vite's HMR needs
(`connect-src ws://127.0.0.1:<port>`, Vite's preamble) and the start banner says
`development mode`.

## Content rules

- Never `shell: true`, `exec`, `execSync`, `eval`, `new Function`, `dangerouslySetInnerHTML`
  (ESLint rules and the repository-rules test enforce it).
- User text reaches the tools only as JSON on stdin (`--input-json -`).
- Markdown is rendered without raw HTML; links open with `rel="noopener noreferrer"` and
  `target="_blank"`; remote images are blocked by the CSP and shown as links.
- The server never logs request bodies, tokens or query strings.

## Tests (must exist)

Foreign Host -> 421; foreign or missing Origin on POST -> 403; `Sec-Fetch-Site: cross-site` ->
403; form-encoded POST -> 415; no / wrong / old token -> 401; reused or expired bootstrap code ->
401; `/assets/..%5C..%5Cpackage.json` and similar -> 404; slug `../x`, `CON`, a run id outside
the index -> 404; the listen address check.
