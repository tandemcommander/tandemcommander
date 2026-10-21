---
title: The information line keeps using a freed text when memory runs out as it grows
type: bug
status: new
severity: 7
area: panels-ui
source: review:276
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# The information line keeps using a freed text when memory runs out as it grows

## Problem

When a panel's information line (or the directory line, the same class) gets a text longer than
any before and memory runs out between its two reallocations, the line keeps a pointer to freed
memory: `CStatusWindow::SetText` reallocates `Text` (success - the old block may be freed and
moved) and then `AlpDX` (failure), and returns FALSE without storing the new `Text` pointer. The
next paint, comparison (`strcmp(Text, txt)` at the top of `SetText`) or destructor (`free(Text)`)
uses the freed block - a crash or heap corruption, only under low memory.

## Evidence

By reading at f9b20e37 (branch 276-infoline-long-name; the code is unchanged on main de31d72a):
`src/stswnd.cpp:141-151` `CStatusWindow::SetText` -
`char* newText = (char*)realloc(Text, l); int* newAlpDX = (int*)realloc(AlpDX, l * sizeof(int)); if (newText == NULL || newAlpDX == NULL) { TRACE_E(LOW_MEMORY); return FALSE; }`
- `Text = newText` is assigned only after both succeed. Found by the independent review of feature
276 (`specs/276-infoline-long-name/fix-log.md`, *Review*, NOTE 6). Feature 276 lets the
information line take up to 65,535 bytes (`AlpDX` then 256 KB), which makes a large second
allocation slightly more likely; still a low-memory case only. Not reproduced.

## Expected

A failed reallocation in `CStatusWindow::SetText` leaves the window with valid buffers: each
successful `realloc` result is stored at once (or both are allocated before either old block is
released), `Allocated` matches the smaller of the two, and the old text stays shown; a low-memory
test seam or a reading proof in the fix-log shows it.

## Notes

Severity 7: a crash in an unusual scenario (low memory). Same pattern may exist in other
two-buffer `realloc` pairs of the core - check `SizeW` / `TextW` in the same file while there.

## Log

- 2026-10-21 — created (source review:276)
