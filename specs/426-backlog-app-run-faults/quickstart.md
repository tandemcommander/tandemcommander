# Quickstart - validating 426

From the repository root.

1. Backlog app checks (typecheck, lint, format, tests):
   `cd tools/backlog-app && npm run check` → all pass; among them
   - `side-worktree.test.ts`: a file directly under `specs/` and a nested `backlog/` folder -
     ten syncs and changes in a row land on `main`; a dirty worktree (a folder where the file
     belongs, a deleted and a changed file) is repaired;
   - the stream test: a trace larger than one page reaches the client whole (event count equal to
     the file's), multi-event lines included;
   - the phase-bound test: the shown phase is the later of fold and server.
2. Loop tests: `cd tools/backlog && python -m unittest test_loop -k linger -k finished` → the run
   that lingers after its result is ended and recorded closed within seconds; `status` of a
   finished run after a hard stop says finished.
3. Replay of the 425 trace (the measurement of research R4) against the new catch-up: 1694 of
   1694 events, phase `done`.
4. Full suites: `python -m unittest` in `tools/backlog` and `python tools/test_bin_help.py`.
