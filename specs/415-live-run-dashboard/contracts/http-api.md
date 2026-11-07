# HTTP API additions - feature 415

Every route passes the security gate of 344 (Host, Origin, bearer token, …); all are `GET`, change
nothing, and are added to the gate tests. `:id` is a run id of the form the existing run routes
accept (`RUN_ID_PATTERN`: a trace folder name).

## `GET /api/runs/:id/insight`

Answer (`RunInsightSchema`):

```json
{
  "branch": "415-live-run-dashboard",
  "featureFolder": "specs/415-live-run-dashboard",
  "documents": [{ "name": "spec", "file": "spec.md", "size": 12034, "modified": "2026-11-07T14:20:00.000Z" }],
  "decisions": [{ "question": "…", "answer": "…", "how": "recommended" }],
  "assumptions": ["…"],
  "diagrams": [{ "title": "Data flow", "text": "trace.jsonl ──▶ …" }],
  "images": [{ "n": 0, "name": "shot.png", "where": "specs/415-…/probe", "source": "trace", "size": 48213, "modified": "…" }],
  "estimate": { "medianSeconds": 9600, "count": 12, "basis": "median of 12 closed runs" }
}
```

- `branch`: the live run's lock branch, or the ended run's `meta.json` branch; only a name of the
  form `NNN-name` is used for a path; otherwise `branch`/`featureFolder` are null and the lists
  hold only trace images.
- Unknown run: `404 not-found`.

## `GET /api/runs/:id/images/:n`

- `:n` is a decimal index into the run's `images` list of the insight (computed again on the
  server for every request, never taken from the page).
- Served when the listed file's real path lies inside the repository root or the system temporary
  folder (both real paths, compared case-insensitively on Windows with a separator boundary), it is
  a regular file, its extension is `.png .jpg .jpeg .gif .bmp .webp`, its size at most 25 MB.
- Answer: the bytes with `Content-Type` of the extension, the app's security headers,
  `Cache-Control: no-store`.
- Otherwise `404 not-found` (an index outside the list, a vanished file, a refused path).

## `GET /api/runs/:id/documents/:name`

- `:name` ∈ `spec`, `plan`, `tasks`, `fix-log`, `research`, `data-model`, `quickstart`,
  `closing-report` → `specs/<branch>/<name>.md`.
- Answer `{ "name": "plan", "text": "…", "modified": "…" }`, text at most 1 MB (longer: cut at a
  line end with a note - a view, not a record).
- Missing file or no feature folder: `404 not-found`.

## Changed: event stream and event pages

`GET /api/runs/:id/stream` and `GET /api/runs/:id/events` give events without a time the time of
the run's time index (research R4). The event shape gains the optional `info` object
(data-model).

## Changed: CSP

`img-src 'self' data: blob:` - the page shows images it fetched with the token as object URLs.
