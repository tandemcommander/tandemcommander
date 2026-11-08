# Quickstart: validate 419-live-run-views

All commands are run from `tools/backlog-app`.

1. Static checks and unit tests:
   - Command: `npm run check`
   - Expected: typecheck, lint, prettier and Vitest all pass, including `packages/web/test/run-views.test.ts`
     (the view from the address, the available views, the chat signature and the chat mark).
2. The layout measurement on a live run:
   - Command: `npm run build`, then `npx playwright test e2e/us8-live-layout.spec.ts`. Set
     `BACKLOG_APP_E2E_MEASURE=<file>.json` to keep the measurements and `BACKLOG_APP_E2E_SHOTS=<folder>` to keep
     the screenshots.
   - Expected: pass. For all 10 views at the 4 sizes, the document and `main` scroll 0 px, no view's tab is
     covered, and each view has at most one vertical scroll area, none of them nested. After a chat answer, the
     page has moved by 0 px.
   - Negative control: the same spec on the web client built from `main` (cbf0cf1f) fails. Measured before the
     change: `specs/419-live-run-views/probe/layout_before.json`.
3. The dashboard end to end:
   - Command: `npx playwright test e2e/us7-live-dashboard.spec.ts e2e/us4-chat.spec.ts`
   - Expected: pass, including axe without serious or critical findings in both themes, the chat reached
     through the Chat tab, and the ended run without a Chat tab.
4. The full suite:
   - Command: `npm run test:e2e`
   - Expected: every spec passes.
5. By eye (optional, `bin/start-backlog-app.sh` on a copy, or the screenshots of step 2):
   - one row of views with a compact line above it;
   - Chat across the full width;
   - no scrollbar outside the view.
