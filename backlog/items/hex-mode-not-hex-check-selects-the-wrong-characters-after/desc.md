---
title: Hex-mode "not hex" check selects the wrong characters after non-ASCII text
type: bug
status: parked
severity: 2
area: encoding
source: measure:397
who: agent
created: 2026-11-02
updated: 2026-11-06
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: minor finding (severity 2) parked in the one-time cleanup of Next; reopen when it bothers a user or the area is worked on; maintainer 2026-11-06
---

# Hex-mode "not hex" check selects the wrong characters after non-ASCII text

## Problem

In hex mode, pressing OK (Find) or Find (the Find Files window) with a character that is not a hex
digit outside quotes shows "String is not valid hexadecimal pattern." and selects the offending character in
the field. The position is a byte offset of the field's UTF-8 text, but the field counts UTF-16
units: when quoted non-ASCII text comes before the bad character (`"中" zz`, `"é" g`), the
selection lands to the right of it (two extra places per CJK letter, one per accented letter) or
past the end. Cosmetic: the message is right, only the highlight is wrong.

## Evidence

At 2e3bfdc8 (branch `397-hex-find-quoted`), read, not driven by a probe:
- `src/viewer.cpp` `HistoryComboBox`, the hex check (about line 77-105): `Text` is read with
  `SalGetWindowTextU8`; the scan advances `s` byte by byte; on a non-hex character
  `SendMessage(hwnd, CB_SETEDITSEL, 0, MAKELPARAM(s - Text, 1 + (s - Text)))` passes the UTF-8
  byte offset as a field position. Callers: `CFindSetDialog::Transfer` (viewer's Find) and the
  Find Files window's Containing field (`src/finddlg1.cpp`).
- Reachable before feature 397 for any non-ASCII text the field held (accented letters of the
  code page typed, or any text set from history / a stored option); after 397 also for quoted
  letters outside the code page typed by the user (they are no longer turned into `?`).

## Expected

The selection marks the offending character: the byte offset is converted to UTF-16 units
(count the units of `Text[0 .. s - Text)`), or the check runs on the wide text.

## Log

- 2026-11-02 — created (source measure:397)
- 2026-11-02 — moved to Next position 136
- 2026-11-06 — moved to Parked: minor finding (severity 2) parked in the one-time cleanup of Next; reopen when it bothers a user or the area is worked on; maintainer 2026-11-06
