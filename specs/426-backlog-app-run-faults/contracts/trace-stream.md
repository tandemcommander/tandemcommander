# Contract - the trace stream (amends 344 `contracts/http-api.md`, *Streams*)

`GET /api/runs/{id}/stream` (SSE):

1. **Catch-up**: every event of `trace.jsonl` from the resume offset (`Last-Event-ID` or `from`)
   to the end of the file, in order, page after page, until a page makes no progress. A page
   without events does not end the catch-up. Every event of a line is sent; only the last event
   of a line carries the SSE `id` (the line's end offset), so a resume never skips the rest of a
   line whose first events arrived (it may send such a line again).
2. **Live**: then every new event of the live run as the server folds it; an `ended` event when
   the run is no longer live.
3. **`phase`**: while live, an event `phase` with `{ "phase": <the server's fold> }` whenever it
   changes. The client's shown phase is never earlier than the last `phase` received.

Unchanged: event ids are byte offsets after the line; a resume continues after the last line
whose events were all sent.
