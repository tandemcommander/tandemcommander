---
title: A dialog status text and the panel size field crash when memory runs out
type: bug
status: in-progress
severity: 7
area: panels-ui
source: measure:293
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: 2026-10-22 9aa937a1
effort: S
feature: 295
related: []
depends-on: []
reason: -
---

# A dialog status text and the panel size field crash when memory runs out

## Problem

Two text holders of the core crash or corrupt the heap when memory runs out (found while fixing
the same pattern in the panel's directory / information line, feature 293):

- `CStaticText::SetText` (the status text of progress dialogs and other dialogs' static texts)
  grows up to five buffers one after another; when a later `realloc` fails it calls
  `free(newText)` - the block the first, successful `realloc(Text, ...)` returned, which may be the
  same address `Text` still holds or a moved one (then the old one is already released). Either way
  `Text` is left pointing at released memory: the next paint, `strcmp(Text, text)` at the top of
  `SetText`, or the destructor uses it. Moved `TextW` / `AlpDX` / `Text2` blocks of the same call
  are stored or freed inconsistently in the same way.
- `CStatusWindow::SetSize` (the size field of a panel's directory line) writes `Size[0] = 0` right
  after `malloc(30)`, before its `if (Size != NULL)` check - a NULL write when the allocation fails.

Only under low memory.

## Evidence

By reading at ad477c57:
- `src/gui.cpp:556-616` `CStaticText::SetText` - `char* newText = (char*)realloc(Text, ...)`
  succeeds; then `WCHAR* newTextW = (WCHAR*)realloc(TextW, ...)` fails ->
  `free(newText); return FALSE;` (also after `newAlpDX`, `newText2`, `newText2W` fail, freeing the
  earlier new blocks while `TextW = newTextW` was already stored). `Text = newText` only at the end.
- `src/stswnd.cpp:608-615` `CStatusWindow::SetSize` -
  `if (Size == NULL) { Size = (char*)malloc(30); Size[0] = 0; } if (Size != NULL) ...`.
- The pattern and its test seam: feature 293, `src/common/salgrowpair.h` `SalGrowBufferPair`
  (each successful `realloc` result stored at once, capacity raised only when all grew) and
  `saltests` `TestGrowBufferPair293` (a fake heap that fails chosen calls and marks released blocks).
Not reproduced (needs memory exhaustion between the calls).

## Expected

A failed allocation in `CStaticText::SetText` leaves every buffer of the control valid (each
successful `realloc` result stored at once, the capacity never above the smallest buffer, the old
text shown) and `SetSize` checks `malloc` before writing; a `saltests` seam (the rule of
`salgrowpair.h` extended to more buffers, or the same approach) or a reading proof in the fix-log
shows it.

## Notes

Severity 7: a crash in an unusual scenario (low memory). `CStaticText` grows four or five buffers
(`Text`, `TextW`, and with an ellipsis style `AlpDX`, `Text2`, `Text2W`) with different sizes, so
`SalGrowBufferPair` does not fit as it is - a variant for more buffers, or storing each result at
once by hand, is the fix to choose.

## Log

- 2026-10-22 — created (source measure:293)
- 2026-10-22 — moved to Next position 2
- 2026-10-22 — verified at 9aa937a1: confirmed by reading at 9aa937a1: SetText frees the stored realloc result on a later failure; SetSize writes Size[0] before the NULL check
- 2026-10-22 — run started, feature 295
