# Quickstart - validate 414

From `tools/backlog-app/` (Node 24):

1. `npm run check` - typecheck, lint (doc comments), format, unit tests; the new `shared` checks of
   `positionBySeverity` and `readTriagePosition` pass, `suggestPlacement`'s old checks unchanged.
2. `npm run build` then `npx playwright test e2e/us3-order.spec.ts` - the old *Q8/triage: n places the
   Inbox item at the suggested position* and the new *Q8/triage: the chooser places at a typed
   position* pass: the fixture's Inbox item placed into *Person steps* / *Next* at a typed position
   ends there by one move (the tool's `list` shows the order; the Inbox is empty; the item's log
   has one move line).
3. Negative control: with the chooser sending no position, the new e2e test fails (the item lands
   last, not at the typed position).
4. `python tools/check_encoding.py --strict` from the repository root -> `TOTAL: 0 finding(s)`.
