---
title: SDK: state that GetErrorText returns UTF-8 (B-3 contract half)
type: tech-debt
status: open
severity: 2
area: plugin-api
source: review:068
who: agent
created: 2026-08-24
updated: 2026-10-17
verified: -
effort: S
feature: -
related: [plugin-ansi-services-interface-decision]
depends-on: []
reason: -
---

# SDK: state that GetErrorText returns UTF-8 (B-3 contract half)

## Problem

B-3, the contract half: the plug-in service `GetErrorText` returns UTF-8 (WTF-8), but the SDK comment in `spl_gen.h` does not say so - it describes only the buffer. A plug-in author reading the SDK has no way to know that the text must not be composed with a code-page `LoadStr` template. The defective compositions themselves are fixed: feature 130 moved 13 plug-ins to `LoadStrU8` for templates composed with a UTF-8 name or `GetErrorText`, feature 134 did the same for FTP. History: 068 / 069 counted about 27 defective sites in 5 plug-ins (mojibake in a non-English UI) and warned that a naive sweep would regress FTP, whose own `FTPGetErrorText` was then consistently code page.

## Evidence

`src/plugins/shared/spl_gen.h` ~1554-1561 at 7993914c (and at HEAD): the Czech comment above `virtual char* WINAPI GetErrorText(int err, char* buf = NULL, int bufSize = 0)` names no encoding. `specs/FEATURE-HISTORY.md` `130-plugin-mixed-templates` ("a plug-in's `LoadStr` (code page) composed with a UTF-8 name or `GetErrorText`. 13 plug-ins changed") and `134-ftp-mixed-templates`. Origin: specs/NEXT-WORK.md §A item 19 (L400) (at 7993914c); specs/068-encoding-regression-review/REMAINING-WORK.md (~line 356, B-3) and review-report.md (F-P5-12, the core half of F-P2-01/02/03/06); specs/069-finish-encoding-fixes/REMAINING-WORK.md §1 B-3. Narrowed by the review of the migration (`specs/242-backlog-system/ledger/review.md`, S3).

## Expected

The SDK comment of `GetErrorText` (and of `GetGFNErrorText` if it is the same) states that the text is UTF-8 and must be composed with UTF-8 templates (`LoadStrU8`), with a contract note in `specs/NNN-*/contracts/` and a line in the `spl_vers.h` history if the project records documentation-only SDK changes there; no code changes.

## Approach

Check first what `GetGFNErrorText` returns; write the comment in English (new comments are English); `check_encoding.py` stays TOTAL 0.

## Notes

The interface question for the other code-page services (B-5) is `plugin-ansi-services-interface-decision`.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-17 — migration review S3: the plug-in compositions were fixed by 130 and 134; the SDK statement is left
- 2026-10-17 — moved to Next position 39
- 2026-10-17 — migration review S3: Problem narrowed to the SDK statement; Evidence names 130 / 134; Expected / Approach rewritten
