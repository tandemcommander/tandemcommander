---
title: On-screen pass of the Code Viewer: 070 quickstart scenarios and 074 gutter steps
type: person-step
status: open
severity: 3
area: viewer
source: leftover:070
who: person
created: 2026-09-02
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [onscreen-pass-075-small-hardening]
depends-on: []
reason: -
---

# On-screen pass of the Code Viewer: 070 quickstart scenarios and 074 gutter steps

## Problem

The Code Viewer (codeview plug-in) was delivered by 070 and its gutter fixed by 074 with stylesheet-level evidence only; the runtime halves in the real viewer are owed: 070's quickstart scenarios plus the runtime halves of its corpus checks, the ten rows its stabilization review left for a human at the keyboard, and 074's human steps (the plug-in's own scrolling, clipboard and theme plumbing).

## Evidence

Migrated from specs/NEXT-WORK.md §B 'On-screen sweeps' ('070 §3 (codeview)', '074') and §3 '070 §3' / '074' (~lines 1121-1124) (at 7993914c). Sources: specs/070-source-viewer-plugin/REMAINING-WORK.md §3 and specs/070-source-viewer-plugin/quickstart.md; specs/074-fix-codeview-gutter/fix-log.md, the human-steps list near the end (~line 136: quickstart scenarios 1, 2, 3, 5, 9 with fixtures in %TEMP%\cvalign\; 4 horizontal scroll (R6); 10 copy fidelity across the 9->10 boundary, Select All, wrapped lines; 11 F9 / Shift+F9 through all schemes, light and dark; 12 rendered.firstPaintMs and scroll smoothness against a pre-change build). specs/070-source-viewer-plugin/stabilization-review.md §8 *What still needs a human at the keyboard* (rows 1-10; RW070 L30-46: "Read `stabilization-review.md` first - it is the current state"), added by the migration review (`specs/242-backlog-system/ledger/review.md`, M3).

## Expected

Every scenario passes in the real viewer; results recorded in 070's and 074's records.

## Notes

070's corpora are already written (hostile content, request log, key sweep, copy fidelity, encoding matrix, performance budgets). RW070 §3 is the same entry. The ten rows of 070's `stabilization-review.md` §8 are the review's "honest remainder" after 37 defects were fixed by reading, harnesses and builds; three of them (Copy / Select All, Word Wrap, Show Whitespace) verify features that did not work at all before the review (its findings F01, F05, F10), Esc during the first F3 the cold-start use-after-free (F02), the titles the language-name fix R14.

## Steps

- [ ] 070: the codeview quickstart scenarios (specs/070-source-viewer-plugin/quickstart.md)
- [ ] 070: the runtime halves of the corpus checks - hostile content, request log, key sweep, copy fidelity, encoding matrix, performance budgets
- [ ] 074: scenarios 1, 2, 3, 5, 9 with the fixtures in %TEMP%\cvalign\
- [ ] 074: scenario 4 - horizontal scroll (the R6 fix) in the real viewer
- [ ] 074: scenario 10 - copy fidelity across the 9->10 boundary, Select All, wrapped lines
- [ ] 074: scenario 11 - F9 / Shift+F9 through all schemes, light and dark
- [ ] 074: scenario 12 - rendered.firstPaintMs and scroll smoothness against a pre-change build
- [ ] 070 review §8.1 Copy / Select All: select with the mouse, Edit > Copy; Edit > Select All then Copy on a file longer than the render window - the whole file arrives, with CRLF and without line numbers; the same with Ctrl+A then Ctrl+C, and once more via the right-click menu; Select All alone does NOT change the clipboard
- [ ] 070 review §8.2 Word Wrap (F2) on a file with long lines: scroll to the very end, use find and Ctrl+G, toggle wrap back off - the end is reachable, no blank bands, the scrollbar matches
- [ ] 070 review §8.3 Show Whitespace: dots on spaces, an arrow at each tab run
- [ ] 070 review §8.4 two windows at once: F2 / a scheme change in one reaches the other, including its menu check marks; the zoom in each window's title matches its own text
- [ ] 070 review §8.5 Ctrl+Plus / Ctrl+Minus / Ctrl+0, and the right-click menu position on a scaled display at 100 % and 200 % zoom
- [ ] 070 review §8.6 Esc during the first F3 of a session (the cold-start use-after-free) - the window closes, the program keeps running
- [ ] 070 review §8.7 a declined file mid-panel: Ctrl+PgDn steps over it, and the notice offers the built-in viewer and actually opens it
- [ ] 070 review §8.8 Czech UI: status bar, window title, the "open in the built-in viewer?" question read correctly
- [ ] 070 review §8.9 `.py`, `.php`, `.cs`, `.java`: the title reads `[Python]`, `[PHP]`, `[C#]`, `[Java]`, and a PHP template colours as PHP
- [ ] 070 review §8.10 the font: the text renders in Consolas (the config migration runs on the first start after the change); side by side with the Markdown Viewer the two look like the same typeface; if sharp but small, Configuration > Size raises it

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — migration review M3: the ten rows of stabilization-review.md §8 added as steps
