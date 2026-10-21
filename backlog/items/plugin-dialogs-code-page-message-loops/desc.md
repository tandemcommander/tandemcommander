---
title: Other plug-ins' dialogs: code-page message loops not examined
type: tech-debt
status: blocked
severity: 3
area: encoding
source: leftover:154
who: agent
created: 2026-10-14
updated: 2026-10-21
verified: 2026-10-21 47209800
effort: ?
feature: -
related: []
depends-on: []
reason: not reproduced at 47209800: no reachable code-page loop of a shipped plug-in delivers typed characters to a text field; listing with reasons in evidence/loop_audit_47209800.md
---

# Other plug-ins' dialogs: code-page message loops not examined

## Problem

Features 093 and 154 made the core's message loops wide so that typed text outside the code page survives (the nine dispatching drain loops in 154). The other plug-ins' dialogs and loops were not examined: a code-page loop there converts a typed character (`?` for a letter outside the code page). Examined already: the Renamer's dialogs (Unicode, 104), FTP's password fields (116), the ZIP and SFTP password prompts (094), the 7zip password (093).

## Evidence

Migrated from specs/NEXT-WORK.md §A item 9 (L269) (at 7993914c). specs/154-drain-loops-wide/fix-log.md ("Not examined: other plug-ins' dialogs" in NEXT-WORK; the method and the review's checks there); specs/093-unicode-dialogs/fix-log.md.

## Expected

Every shipped plug-in's dialog loops are listed; each that delivers typed characters to a text field is wide (or recorded as harmless with a reason), measured by typing a letter outside the code page.

## Approach

Enumerate `GetMessageA` / `PeekMessageA` / `IsDialogMessageA` / `DispatchMessageA` in the shipped plug-ins (plugins.cfg on); 154's probe pattern posts `WM_CHAR` of a letter outside the code page.

## Notes

NW §5 *B-1* ("other plug-ins' dialogs ... the rest still not examined", L1961) names the same gap.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-17 — migration review N3: migration remark removed
- 2026-10-21 — verified at 47209800: not reproduced: all shipped plug-in loops audited, none delivers typed text to a reachable field (evidence/loop_audit_47209800.md)
- 2026-10-21 — blocked: not reproduced at 47209800: no reachable code-page loop of a shipped plug-in delivers typed characters to a text field; listing with reasons in evidence/loop_audit_47209800.md
