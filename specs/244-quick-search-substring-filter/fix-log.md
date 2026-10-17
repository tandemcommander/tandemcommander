# Fix log — 244 quick search substring filter

## 2026-10-17 — specify, plan

- Spec written from the maintainer's request (Czech). Two clarifications answered: commands act only on visible items and keep the search; on by default + an option back to 0.1.10 (documented exception to Constitution II).
- Code read by three read-only agents (listing/filter pipeline, painting/colours, lifecycle/commands); findings in `research.md` R1–R8.
- Key facts that shaped the design:
  - disk panels have no full listing, because hidden items are dropped while reading;
  - everything acts on `Dirs`/`Files` directly;
  - almost every route ends quick search today (central `WM_COMMAND` cancel, focus, menus, scroll, clicks);
  - icons have the normal background baked into icon lists shared by both panels.
- Spec adjusted after research:
  - FR-026: the text goes in the directory line, with the information line as fallback;
  - FR-027: the caret after the match end, no colour highlight;
  - FR-015: the mouse and dialogs do not end the search;
  - new edge case: an operation focusing a non-matching item ends the search.
- Not yet measured on the build: the *Current behaviour* section and every R-finding are from source reading. Quickstart V1 is the first implementation step.
